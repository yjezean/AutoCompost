#!/usr/bin/env python3
"""
FastAPI Application
Provides HTTP API endpoints for the Flutter mobile app
"""
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime, timezone, timedelta
# GMT+8 timezone
GMT8 = timezone(timedelta(hours=8))
import psycopg2
from psycopg2.extras import RealDictCursor
import pandas as pd
import numpy as np
import config
import logging
from compost_calculations import calculate_cn_ratio

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/compost/api.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Compost Monitoring API",
    description="API for IoT Compost Monitoring System",
    version="1.0.0"
)

# Configure CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to your Flutter app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection helper
def get_db_connection():
    """Create and return a database connection"""
    return psycopg2.connect(
        host=config.DB_HOST,
        port=config.DB_PORT,
        database=config.DB_NAME,
        user=config.DB_USER,
        password=config.DB_PASSWORD
    )

# Pydantic models for API requests/responses
class SensorDataPoint(BaseModel):
    timestamp: datetime
    temperature: float
    humidity: float

class SensorDataResponse(BaseModel):
    data: List[SensorDataPoint]

class CompostBatch(BaseModel):
    id: int
    start_date: datetime
    projected_end_date: datetime
    status: str
    created_at: datetime
    green_waste_kg: Optional[float] = None
    brown_waste_kg: Optional[float] = None
    total_volume_liters: Optional[float] = None
    cn_ratio: Optional[float] = None
    initial_volume_liters: Optional[float] = None

class CompostBatchCreate(BaseModel):
    start_date: datetime
    projected_end_date: Optional[datetime] = None  # Optional - will be calculated from volume
    status: str = "planning"
    green_waste_kg: Optional[float] = None
    brown_waste_kg: Optional[float] = None
    initial_volume_liters: Optional[float] = None

class CompostBatchUpdate(BaseModel):
    green_waste_kg: Optional[float] = None
    brown_waste_kg: Optional[float] = None
    initial_volume_liters: Optional[float] = None
    status: Optional[str] = None

class CompostMaterial(BaseModel):
    id: int
    name: str
    material_type: str  # 'green' or 'brown'
    carbon_nitrogen_ratio: float
    density_kg_per_liter: Optional[float] = None
    description: Optional[str] = None

class CNRatioResponse(BaseModel):
    current_ratio: float
    optimal_ratio: float = 27.5  # Target: 25-30:1
    green_waste_kg: float
    brown_waste_kg: float
    suggested_brown_kg: Optional[float] = None
    status: str  # "optimal", "too_much_green", "too_much_brown", "insufficient_data"

class CompletionStatus(BaseModel):
    status: str  # "active", "completing", "complete"
    completion_percentage: float
    estimated_days_remaining: Optional[int] = None

# API Endpoints
@app.get("/")
async def root():
    """Root endpoint - API information"""
    return {
        "name": "Compost Monitoring API",
        "version": "1.0.0",
        "status": "running"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        conn.close()
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=503, detail=f"Database connection failed: {str(e)}")

@app.get("/api/v1/sensor-data", response_model=SensorDataResponse)
async def get_sensor_data(
    days: int = Query(7, ge=1, le=365, description="Number of days of data to retrieve")
):
    """
    Get historical sensor data
    Returns temperature and humidity data for the specified number of days
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Query sensor data
        # Note: Database timestamps are stored as UTC but actually contain GMT+8 values
        # So we need to treat them as GMT+8 when querying
        
        # Calculate date range in GMT+8
        # Add 1 minute buffer to end_date to ensure we capture the very latest data
        end_date_gmt8 = datetime.now(GMT8) + timedelta(minutes=1)
        start_date_gmt8 = end_date_gmt8 - timedelta(days=days)
        
        # Convert to UTC for database query (database thinks it's UTC but it's actually GMT+8)
        # Since data is stored as GMT+8 values in UTC fields, we subtract 8 hours to match
        end_date_utc = end_date_gmt8.astimezone(timezone.utc) - timedelta(hours=8)
        start_date_utc = start_date_gmt8.astimezone(timezone.utc) - timedelta(hours=8)
        
        # Try date-filtered query
        # Exclude obviously invalid timestamps (future dates more than 1 day ahead)
        cursor.execute(
            """
            SELECT timestamp, temperature, humidity
            FROM sensor_data
            WHERE timestamp >= %s 
              AND timestamp <= %s
              AND timestamp <= NOW() + INTERVAL '1 day'
            ORDER BY timestamp ASC
            """,
            (start_date_utc, end_date_utc)
        )
        
        rows = cursor.fetchall()
        
        # Always ensure we have the absolute latest record, even if it's slightly outside the range
        # This handles race conditions where data arrives during query execution
        # Exclude obviously invalid timestamps (future dates more than 1 day ahead)
        cursor.execute(
            """
            SELECT timestamp, temperature, humidity
            FROM sensor_data
            WHERE timestamp <= NOW() + INTERVAL '1 day'
            ORDER BY timestamp DESC
            LIMIT 1
            """
        )
        latest_row = cursor.fetchone()
        
        # If we got data from date filter, check if latest record is already included
        if len(rows) > 0 and latest_row:
            # Check if latest record is already in our results
            latest_timestamp = latest_row['timestamp']
            if not any(row['timestamp'] == latest_timestamp for row in rows):
                # Latest record not in results, add it
                rows.append(latest_row)
                logger.info(f"Added latest record ({latest_timestamp}) to results")
        
        # If no data found with date filter, get latest records regardless of date
        if len(rows) == 0:
            logger.warning(f"No data found for last {days} days. Using fallback: latest records.")
            # Get latest records (limit based on days: roughly 1 record per 5 seconds = ~17k per day)
            limit = min(days * 17280, 10000)  # Max 10k records
            cursor.execute(
                """
                SELECT timestamp, temperature, humidity
                FROM sensor_data
                WHERE timestamp <= NOW() + INTERVAL '1 day'
                ORDER BY timestamp DESC
                LIMIT %s
                """,
                (limit,)
            )
            rows = cursor.fetchall()
            # Reverse to get chronological order
            rows = list(reversed(rows))
            logger.info(f"Fallback query returned {len(rows)} latest records")
        
        # Sort by timestamp to ensure chronological order
        rows = sorted(rows, key=lambda x: x['timestamp'])
        
        cursor.close()
        conn.close()
        
        # Convert to list of SensorDataPoint
        # Database timestamps are stored as UTC but actually contain GMT+8 time values
        # Fix: Convert to real UTC (subtract 8h), return as UTC
        # Frontend will automatically convert UTC to local timezone (GMT+8) = correct display
        data = []
        for row in rows:
            timestamp = row['timestamp']
            
            # The timestamp is stored as UTC but the time value is actually GMT+8
            # Example: Database has 19:11:36+00, but 19:11 is actually GMT+8 time
            # Real UTC time should be: 19:11 - 8 = 11:11 UTC
            # Return as UTC: 11:11:36+00:00
            # Frontend (GMT+8) will convert: 11:11 UTC + 8 = 19:11 GMT+8 (correct!)
            if timestamp.tzinfo is None:
                # If no timezone, assume UTC
                timestamp = timestamp.replace(tzinfo=timezone.utc)
            
            # Convert from "fake UTC" (which is actually GMT+8) to real UTC
            if timestamp.tzinfo == timezone.utc:
                # Subtract 8 hours to get actual UTC time
                # This converts the GMT+8 time value to real UTC
                timestamp = timestamp - timedelta(hours=8)
                # Keep as UTC - frontend will convert to local timezone automatically
            else:
                # Already in different timezone, convert to UTC
                timestamp = timestamp.astimezone(timezone.utc)
            
            data.append(SensorDataPoint(
                timestamp=timestamp,
                temperature=float(row['temperature']),
                humidity=float(row['humidity'])
            ))
        
        logger.info(f"Retrieved {len(data)} sensor data points for last {days} days")
        return SensorDataResponse(data=data)
        
    except Exception as e:
        logger.error(f"Error retrieving sensor data: {e}")
        import traceback
        logger.error(traceback.format_exc())
        # Ensure connection is closed on error
        try:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()
        except:
            pass
        raise HTTPException(status_code=500, detail=f"Error retrieving sensor data: {str(e)}")

@app.get("/api/v1/compost-batch/current", response_model=CompostBatch)
async def get_current_batch():
    """
    Get the current active compost batch
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute(
            """
            SELECT id, start_date, projected_end_date, status, created_at,
                   green_waste_kg, brown_waste_kg, total_volume_liters, 
                   cn_ratio, initial_volume_liters
            FROM compost_batch
            WHERE status = 'active'
            ORDER BY created_at DESC
            LIMIT 1
            """
        )
        
        row = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not row:
            raise HTTPException(status_code=404, detail="No active compost batch found")
        
        return CompostBatch(
            id=row['id'],
            start_date=row['start_date'],
            projected_end_date=row['projected_end_date'],
            status=row['status'],
            created_at=row['created_at'],
            green_waste_kg=float(row['green_waste_kg']) if row['green_waste_kg'] else None,
            brown_waste_kg=float(row['brown_waste_kg']) if row['brown_waste_kg'] else None,
            total_volume_liters=float(row['total_volume_liters']) if row['total_volume_liters'] else None,
            cn_ratio=float(row['cn_ratio']) if row['cn_ratio'] else None,
            initial_volume_liters=float(row['initial_volume_liters']) if row['initial_volume_liters'] else None
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving current batch: {e}")
        # Ensure connection is closed on error
        try:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()
        except:
            pass
        raise HTTPException(status_code=500, detail=f"Error retrieving batch: {str(e)}")

@app.post("/api/v1/compost-batch", response_model=CompostBatch)
async def create_compost_batch(batch: CompostBatchCreate):
    """
    Create a new compost batch
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # First, mark any existing active batches as completed
        cursor.execute(
            """
            UPDATE compost_batch
            SET status = 'completed'
            WHERE status = 'active'
            """
        )
        
        # Insert new batch
        cursor.execute(
            """
            INSERT INTO compost_batch (start_date, projected_end_date, status, 
                                      green_waste_kg, brown_waste_kg, initial_volume_liters)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id, start_date, projected_end_date, status, created_at,
                      green_waste_kg, brown_waste_kg, total_volume_liters, 
                      cn_ratio, initial_volume_liters
            """,
            (batch.start_date, batch.projected_end_date, batch.status,
             batch.green_waste_kg, batch.brown_waste_kg, batch.initial_volume_liters)
        )
        
        row = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info(f"Created new compost batch: ID={row[0]}")
        
        return CompostBatch(
            id=row[0],
            start_date=row[1],
            projected_end_date=row[2],
            status=row[3],
            created_at=row[4],
            green_waste_kg=float(row[5]) if row[5] else None,
            brown_waste_kg=float(row[6]) if row[6] else None,
            total_volume_liters=float(row[7]) if row[7] else None,
            cn_ratio=float(row[8]) if row[8] else None,
            initial_volume_liters=float(row[9]) if row[9] else None
        )
        
    except Exception as e:
        logger.error(f"Error creating batch: {e}")
        if conn:
            conn.rollback()
            conn.close()
        raise HTTPException(status_code=500, detail=f"Error creating batch: {str(e)}")

@app.get("/api/v1/analytics/completion-status", response_model=CompletionStatus)
async def get_completion_status(
    days: int = Query(30, ge=1, le=365, description="Number of days to analyze")
):
    """
    Calculate composting completion status based on temperature curve analysis
    Uses slope calculation to determine if composting is complete
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get current batch
        cursor.execute(
            """
            SELECT id, start_date, projected_end_date, status
            FROM compost_batch
            WHERE status = 'active'
            ORDER BY created_at DESC
            LIMIT 1
            """
        )
        batch = cursor.fetchone()
        
        if not batch:
            raise HTTPException(status_code=404, detail="No active compost batch found")
        
        # Get temperature data for analysis (convert GMT+8 to UTC for query)
        end_date_utc = datetime.now(GMT8).astimezone(timezone.utc)
        start_date_utc = end_date_utc - timedelta(days=min(days, 30))  # Analyze last 30 days max
        
        cursor.execute(
            """
            SELECT timestamp, temperature
            FROM sensor_data
            WHERE timestamp >= %s AND timestamp <= %s
            ORDER BY timestamp ASC
            """,
            (start_date_utc, end_date_utc)
        )
        
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        
        if len(rows) < 10:
            # Not enough data for analysis
            return CompletionStatus(
                status="active",
                completion_percentage=0.0,
                estimated_days_remaining=None
            )
        
        # Convert to pandas DataFrame for analysis
        df = pd.DataFrame(rows)
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        df = df.set_index('timestamp')
        
        # Calculate moving average (7-day window)
        df['temp_ma'] = df['temperature'].rolling(window=min(7, len(df)), center=True).mean()
        
        # Calculate slope of temperature curve (last 7 days if available)
        analysis_window = min(7, len(df))
        if analysis_window >= 3:
            recent_data = df['temp_ma'].tail(analysis_window).values
            x = np.arange(len(recent_data))
            slope = np.polyfit(x, recent_data, 1)[0]
            
            # Calculate completion percentage based on:
            # 1. Time elapsed vs projected duration
            # 2. Temperature trend (slope near zero or negative = completing/complete)
            
            batch_start = batch['start_date']
            batch_end = batch['projected_end_date']
            current_time = datetime.now(GMT8)
            
            total_duration = (batch_end - batch_start).total_seconds()
            elapsed = (current_time - batch_start).total_seconds()
            time_completion = min(100.0, (elapsed / total_duration) * 100) if total_duration > 0 else 0
            
            # Temperature-based completion (if slope is near zero or negative, composting is stabilizing)
            max_temp = df['temperature'].max()
            current_temp = df['temperature'].iloc[-1]
            temp_completion = min(100.0, ((max_temp - current_temp) / max_temp) * 100) if max_temp > 0 else 0
            
            # Combined completion (weighted: 60% time, 40% temperature trend)
            completion = (time_completion * 0.6) + (temp_completion * 0.4)
            
            # Determine status
            if completion >= 90 and slope <= 0:
                status = "complete"
                estimated_days = 0
            elif completion >= 70 or slope <= 0.1:
                status = "completing"
                remaining_percent = max(0, 100 - completion)
                estimated_days = int((remaining_percent / 100) * (total_duration / 86400))
            else:
                status = "active"
                remaining_percent = max(0, 100 - completion)
                estimated_days = int((remaining_percent / 100) * (total_duration / 86400))
            
            return CompletionStatus(
                status=status,
                completion_percentage=round(completion, 2),
                estimated_days_remaining=estimated_days
            )
        else:
            # Not enough data
            return CompletionStatus(
                status="active",
                completion_percentage=0.0,
                estimated_days_remaining=None
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error calculating completion status: {e}")
        # Ensure connection is closed on error
        try:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()
        except:
            pass
        raise HTTPException(status_code=500, detail=f"Error calculating completion status: {str(e)}")

# Phase 2: Multi-Cycle Management Endpoints

@app.get("/api/v1/cycles", response_model=List[CompostBatch])
async def get_cycles():
    """
    Get all compost cycles (all statuses)
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute(
            """
            SELECT id, start_date, projected_end_date, status, created_at,
                   green_waste_kg, brown_waste_kg, total_volume_liters, 
                   cn_ratio, initial_volume_liters
            FROM compost_batch
            ORDER BY created_at DESC
            """
        )
        
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        
        cycles = [
            CompostBatch(
                id=row['id'],
                start_date=row['start_date'],
                projected_end_date=row['projected_end_date'],
                status=row['status'],
                created_at=row['created_at'],
                green_waste_kg=float(row['green_waste_kg']) if row['green_waste_kg'] else None,
                brown_waste_kg=float(row['brown_waste_kg']) if row['brown_waste_kg'] else None,
                total_volume_liters=float(row['total_volume_liters']) if row['total_volume_liters'] else None,
                cn_ratio=float(row['cn_ratio']) if row['cn_ratio'] else None,
                initial_volume_liters=float(row['initial_volume_liters']) if row['initial_volume_liters'] else None
            )
            for row in rows
        ]
        
        return cycles
        
    except Exception as e:
        logger.error(f"Error retrieving cycles: {e}")
        # Ensure connection is closed on error
        try:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()
        except:
            pass
        raise HTTPException(status_code=500, detail=f"Error retrieving cycles: {str(e)}")

@app.get("/api/v1/cycles/{cycle_id}", response_model=CompostBatch)
async def get_cycle(cycle_id: int):
    """
    Get a specific compost cycle by ID
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute(
            """
            SELECT id, start_date, projected_end_date, status, created_at,
                   green_waste_kg, brown_waste_kg, total_volume_liters, 
                   cn_ratio, initial_volume_liters
            FROM compost_batch
            WHERE id = %s
            """,
            (cycle_id,)
        )
        
        row = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not row:
            raise HTTPException(status_code=404, detail=f"Cycle with ID {cycle_id} not found")
        
        return CompostBatch(
            id=row['id'],
            start_date=row['start_date'],
            projected_end_date=row['projected_end_date'],
            status=row['status'],
            created_at=row['created_at'],
            green_waste_kg=float(row['green_waste_kg']) if row['green_waste_kg'] else None,
            brown_waste_kg=float(row['brown_waste_kg']) if row['brown_waste_kg'] else None,
            total_volume_liters=float(row['total_volume_liters']) if row['total_volume_liters'] else None,
            cn_ratio=float(row['cn_ratio']) if row['cn_ratio'] else None,
            initial_volume_liters=float(row['initial_volume_liters']) if row['initial_volume_liters'] else None
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving cycle: {e}")
        # Ensure connection is closed on error
        try:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()
        except:
            pass
        raise HTTPException(status_code=500, detail=f"Error retrieving cycle: {str(e)}")

@app.post("/api/v1/cycles", response_model=CompostBatch)
async def create_cycle(batch: CompostBatchCreate):
    """
    Create a new compost cycle
    Calculates projected_end_date based on total volume if not provided
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Calculate projected_end_date based on volume if not explicitly set
        # Formula: ~21 days base + 1 day per 5 liters of volume
        if batch.projected_end_date:
            projected_end = batch.projected_end_date
        elif batch.initial_volume_liters and batch.initial_volume_liters > 0:
            # Base composting time: 21 days
            # Additional time: 1 day per 5 liters
            base_days = 21
            additional_days = int(batch.initial_volume_liters / 5.0)
            total_days = base_days + additional_days
            # Cap at 90 days maximum
            total_days = min(total_days, 90)
            projected_end = batch.start_date + timedelta(days=total_days)
        else:
            # Default to 21 days if no volume and no end date specified
            projected_end = batch.start_date + timedelta(days=21)
        
        # Insert new cycle
        cursor.execute(
            """
            INSERT INTO compost_batch (start_date, projected_end_date, status, 
                                      green_waste_kg, brown_waste_kg, initial_volume_liters)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id, start_date, projected_end_date, status, created_at,
                      green_waste_kg, brown_waste_kg, total_volume_liters, 
                      cn_ratio, initial_volume_liters
            """,
            (batch.start_date, projected_end, batch.status,
             batch.green_waste_kg, batch.brown_waste_kg, batch.initial_volume_liters)
        )
        
        row = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info(f"Created new compost cycle: ID={row[0]}")
        
        return CompostBatch(
            id=row[0],
            start_date=row[1],
            projected_end_date=row[2],
            status=row[3],
            created_at=row[4],
            green_waste_kg=float(row[5]) if row[5] else None,
            brown_waste_kg=float(row[6]) if row[6] else None,
            total_volume_liters=float(row[7]) if row[7] else None,
            cn_ratio=float(row[8]) if row[8] else None,
            initial_volume_liters=float(row[9]) if row[9] else None
        )
        
    except Exception as e:
        logger.error(f"Error creating cycle: {e}")
        if conn:
            conn.rollback()
            conn.close()
        raise HTTPException(status_code=500, detail=f"Error creating cycle: {str(e)}")

@app.put("/api/v1/cycles/{cycle_id}", response_model=CompostBatch)
async def update_cycle(cycle_id: int, update: CompostBatchUpdate):
    """
    Update a compost cycle (waste amounts, volume, status)
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Build dynamic UPDATE query
        updates = []
        values = []
        
        if update.green_waste_kg is not None:
            updates.append("green_waste_kg = %s")
            values.append(update.green_waste_kg)
        if update.brown_waste_kg is not None:
            updates.append("brown_waste_kg = %s")
            values.append(update.brown_waste_kg)
        if update.initial_volume_liters is not None:
            updates.append("initial_volume_liters = %s")
            values.append(update.initial_volume_liters)
        if update.status is not None:
            updates.append("status = %s")
            values.append(update.status)
        
        if not updates:
            raise HTTPException(status_code=400, detail="No fields to update")
        
        values.append(cycle_id)
        query = f"""
            UPDATE compost_batch
            SET {', '.join(updates)}
            WHERE id = %s
            RETURNING id, start_date, projected_end_date, status, created_at,
                      green_waste_kg, brown_waste_kg, total_volume_liters, 
                      cn_ratio, initial_volume_liters
        """
        
        cursor.execute(query, values)
        row = cursor.fetchone()
        
        if not row:
            cursor.close()
            conn.close()
            raise HTTPException(status_code=404, detail=f"Cycle with ID {cycle_id} not found")
        
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info(f"Updated compost cycle: ID={cycle_id}")
        
        return CompostBatch(
            id=row['id'],
            start_date=row['start_date'],
            projected_end_date=row['projected_end_date'],
            status=row['status'],
            created_at=row['created_at'],
            green_waste_kg=float(row['green_waste_kg']) if row['green_waste_kg'] else None,
            brown_waste_kg=float(row['brown_waste_kg']) if row['brown_waste_kg'] else None,
            total_volume_liters=float(row['total_volume_liters']) if row['total_volume_liters'] else None,
            cn_ratio=float(row['cn_ratio']) if row['cn_ratio'] else None,
            initial_volume_liters=float(row['initial_volume_liters']) if row['initial_volume_liters'] else None
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating cycle: {e}")
        if conn:
            conn.rollback()
            conn.close()
        raise HTTPException(status_code=500, detail=f"Error updating cycle: {str(e)}")

@app.put("/api/v1/cycles/{cycle_id}/activate")
async def activate_cycle(cycle_id: int):
    """
    Set a cycle as active (deactivates all other cycles)
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # First, deactivate all active cycles
        cursor.execute(
            """
            UPDATE compost_batch
            SET status = 'completed'
            WHERE status = 'active'
            """
        )
        
        # Activate the specified cycle
        cursor.execute(
            """
            UPDATE compost_batch
            SET status = 'active'
            WHERE id = %s
            RETURNING id
            """,
            (cycle_id,)
        )
        
        row = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        if not row:
            raise HTTPException(status_code=404, detail=f"Cycle with ID {cycle_id} not found")
        
        logger.info(f"Activated compost cycle: ID={cycle_id}")
        return {"message": f"Cycle {cycle_id} activated successfully", "cycle_id": cycle_id}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error activating cycle: {e}")
        if conn:
            conn.rollback()
            conn.close()
        raise HTTPException(status_code=500, detail=f"Error activating cycle: {str(e)}")

# Import calculation utilities
from compost_calculations import calculate_cn_ratio

class CyclePreviewRequest(BaseModel):
    green_waste_kg: float
    start_date: datetime

class CyclePreviewResponse(BaseModel):
    brown_waste_kg: float
    total_volume_liters: float
    projected_end_date: datetime
    green_volume_liters: float
    brown_volume_liters: float
    duration_days: int

@app.post("/api/v1/cycles/preview", response_model=CyclePreviewResponse)
async def preview_cycle(preview: CyclePreviewRequest):
    """
    Preview cycle calculations without creating a cycle
    Calculates brown waste, total volume, and projected end date based on green waste
    """
    try:
        if preview.green_waste_kg <= 0:
            raise HTTPException(status_code=400, detail="Green waste must be greater than 0")
        
        # Calculate brown waste (for optimal C:N ratio of 27.5)
        # Formula: B = G * (27.5 - 20) / (60 - 27.5) ≈ G * 0.231
        brown_waste_kg = preview.green_waste_kg * 0.231
        
        # Calculate volumes
        # Green waste density: 0.5 kg/L (kitchen scraps)
        # Brown waste density: 0.1 kg/L (dry leaves)
        GREEN_DENSITY = 0.5
        BROWN_DENSITY = 0.1
        
        green_volume_liters = preview.green_waste_kg / GREEN_DENSITY
        brown_volume_liters = brown_waste_kg / BROWN_DENSITY
        total_volume_liters = green_volume_liters + brown_volume_liters
        
        # Calculate projected end date
        # Base: 21 days + 1 day per 5 liters, max 90 days
        base_days = 21
        additional_days = int(total_volume_liters / 5.0)
        total_days = base_days + additional_days
        total_days = min(total_days, 90)  # Cap at 90 days
        projected_end_date = preview.start_date + timedelta(days=total_days)
        
        return CyclePreviewResponse(
            brown_waste_kg=round(brown_waste_kg, 3),
            total_volume_liters=round(total_volume_liters, 2),
            projected_end_date=projected_end_date,
            green_volume_liters=round(green_volume_liters, 2),
            brown_volume_liters=round(brown_volume_liters, 2),
            duration_days=total_days
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error calculating preview: {e}")
        raise HTTPException(status_code=500, detail=f"Error calculating preview: {str(e)}")

@app.post("/api/v1/cycles/{cycle_id}/calculate-ratio", response_model=CNRatioResponse)
async def calculate_cycle_ratio(cycle_id: int):
    """
    Calculate C:N ratio for a specific cycle
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute(
            """
            SELECT green_waste_kg, brown_waste_kg
            FROM compost_batch
            WHERE id = %s
            """,
            (cycle_id,)
        )
        
        row = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not row:
            raise HTTPException(status_code=404, detail=f"Cycle with ID {cycle_id} not found")
        
        green_kg = float(row['green_waste_kg']) if row['green_waste_kg'] else 0.0
        brown_kg = float(row['brown_waste_kg']) if row['brown_waste_kg'] else 0.0
        
        if green_kg == 0 and brown_kg == 0:
            raise HTTPException(status_code=400, detail="Cycle has no waste data. Please add green and brown waste amounts first.")
        
        result = calculate_cn_ratio(green_kg, brown_kg)
        
        # Update the cycle's cn_ratio in database
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            """
            UPDATE compost_batch
            SET cn_ratio = %s
            WHERE id = %s
            """,
            (result['current_ratio'], cycle_id)
        )
        conn.commit()
        cursor.close()
        conn.close()
        
        return CNRatioResponse(**result)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error calculating C:N ratio: {e}")
        raise HTTPException(status_code=500, detail=f"Error calculating C:N ratio: {str(e)}")

@app.get("/api/v1/cycles/{cycle_id}/progress")
async def get_cycle_progress(cycle_id: int):
    """
    Get volume-based progress for a cycle
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute(
            """
            SELECT id, start_date, projected_end_date, status,
                   initial_volume_liters, total_volume_liters
            FROM compost_batch
            WHERE id = %s
            """,
            (cycle_id,)
        )
        
        row = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not row:
            raise HTTPException(status_code=404, detail=f"Cycle with ID {cycle_id} not found")
        
        initial_volume = float(row['initial_volume_liters']) if row['initial_volume_liters'] else None
        current_volume = float(row['total_volume_liters']) if row['total_volume_liters'] else None
        
        # Calculate progress based on volume reduction
        if initial_volume and current_volume:
            volume_reduction = ((initial_volume - current_volume) / initial_volume) * 100
            volume_progress = min(100.0, max(0.0, volume_reduction))
        else:
            volume_progress = None
        
        # Time-based progress
        start_date = row['start_date']
        end_date = row['projected_end_date']
        current_time = datetime.now(GMT8)
        
        total_duration = (end_date - start_date).total_seconds()
        elapsed = (current_time - start_date).total_seconds()
        time_progress = min(100.0, (elapsed / total_duration) * 100) if total_duration > 0 else 0
        
        return {
            "cycle_id": cycle_id,
            "time_progress": round(time_progress, 2),
            "volume_progress": round(volume_progress, 2) if volume_progress else None,
            "initial_volume_liters": initial_volume,
            "current_volume_liters": current_volume,
            "estimated_completion_date": end_date.isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting cycle progress: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting cycle progress: {str(e)}")

@app.get("/api/v1/materials", response_model=List[CompostMaterial])
async def get_materials():
    """
    Get list of all compost materials with their C:N ratios
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute(
            """
            SELECT id, name, material_type, carbon_nitrogen_ratio, 
                   density_kg_per_liter, description
            FROM compost_materials
            ORDER BY material_type, name
            """
        )
        
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        
        materials = [
            CompostMaterial(
                id=row['id'],
                name=row['name'],
                material_type=row['material_type'],
                carbon_nitrogen_ratio=float(row['carbon_nitrogen_ratio']),
                density_kg_per_liter=float(row['density_kg_per_liter']) if row['density_kg_per_liter'] else None,
                description=row['description']
            )
            for row in rows
        ]
        
        return materials
        
    except Exception as e:
        logger.error(f"Error retrieving materials: {e}")
        raise HTTPException(status_code=500, detail=f"Error retrieving materials: {str(e)}")

# Optimization Settings Endpoints

class OptimizationStatus(BaseModel):
    enabled: bool

@app.get("/api/v1/optimization/status", response_model=OptimizationStatus)
async def get_optimization_status():
    """
    Get current optimization (automated control) status
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute(
            """
            SELECT setting_value
            FROM system_settings
            WHERE setting_key = 'optimization_enabled'
            """
        )
        
        row = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not row:
            # Default to enabled if not found
            return OptimizationStatus(enabled=True)
        
        enabled = row['setting_value'].lower() == 'true'
        return OptimizationStatus(enabled=enabled)
        
    except Exception as e:
        logger.error(f"Error retrieving optimization status: {e}")
        # Default to enabled on error
        return OptimizationStatus(enabled=True)

@app.put("/api/v1/optimization/status", response_model=OptimizationStatus)
async def set_optimization_status(status: OptimizationStatus):
    """
    Set optimization (automated control) status
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            """
            INSERT INTO system_settings (setting_key, setting_value, description, updated_at)
            VALUES ('optimization_enabled', %s, 'Automated temperature and humidity control optimization', CURRENT_TIMESTAMP)
            ON CONFLICT (setting_key) 
            DO UPDATE SET 
                setting_value = EXCLUDED.setting_value,
                updated_at = CURRENT_TIMESTAMP
            """,
            (str(status.enabled).lower(),)
        )
        
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info(f"Optimization status updated to: {status.enabled}")
        return status
        
    except Exception as e:
        logger.error(f"Error updating optimization status: {e}")
        raise HTTPException(status_code=500, detail=f"Error updating optimization status: {str(e)}")

# Analytics Endpoints for Completed Cycles

class CycleAnalytics(BaseModel):
    total_completed_cycles: int
    average_composting_days: float
    total_composted_waste_kg: float
    average_temperature: float
    average_humidity: float
    optimization_enabled_percentage: float
    cycles_by_month: List[dict]
    temperature_trend: List[dict]
    humidity_trend: List[dict]
    waste_processed_trend: List[dict]

@app.get("/api/v1/analytics/completed-cycles", response_model=CycleAnalytics)
async def get_completed_cycles_analytics():
    """
    Get analytics for all completed cycles
    Returns average composting time, total waste processed, average temperature, etc.
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get all completed cycles
        cursor.execute(
            """
            SELECT id, start_date, projected_end_date, 
                   green_waste_kg, brown_waste_kg, initial_volume_liters
            FROM compost_batch
            WHERE status = 'completed'
            ORDER BY start_date DESC
            """
        )
        cycles = cursor.fetchall()
        
        if not cycles or len(cycles) == 0:
            # Return empty analytics if no completed cycles
            return CycleAnalytics(
                total_completed_cycles=0,
                average_composting_days=0.0,
                total_composted_waste_kg=0.0,
                average_temperature=0.0,
                average_humidity=0.0,
                optimization_enabled_percentage=0.0,
                cycles_by_month=[],
                temperature_trend=[],
                humidity_trend=[],
                waste_processed_trend=[]
            )
        
        # Calculate average composting days
        total_days = 0
        valid_cycles = 0
        total_waste_kg = 0.0
        
        for cycle in cycles:
            start_date = cycle['start_date']
            end_date = cycle['projected_end_date']
            if start_date and end_date:
                days = (end_date - start_date).days
                if days > 0:
                    total_days += days
                    valid_cycles += 1
            
            # Sum total waste
            if cycle['green_waste_kg']:
                total_waste_kg += float(cycle['green_waste_kg'])
            if cycle['brown_waste_kg']:
                total_waste_kg += float(cycle['brown_waste_kg'])
        
        average_days = total_days / valid_cycles if valid_cycles > 0 else 0.0
        
        # Get average temperature and humidity from sensor data for completed cycles
        # Use date range from oldest to newest completed cycle
        if cycles:
            oldest_start = min(c['start_date'] for c in cycles if c['start_date'])
            newest_end = max(c['projected_end_date'] for c in cycles if c['projected_end_date'])
            
            if oldest_start and newest_end:
                # Convert to UTC for query (database stores UTC but contains GMT+8 values)
                oldest_utc = oldest_start.astimezone(timezone.utc) - timedelta(hours=8)
                newest_utc = newest_end.astimezone(timezone.utc) - timedelta(hours=8)
                
                cursor.execute(
                    """
                    SELECT AVG(temperature) as avg_temp, AVG(humidity) as avg_hum
                    FROM sensor_data
                    WHERE timestamp >= %s AND timestamp <= %s
                      AND timestamp <= NOW() + INTERVAL '1 day'
                    """,
                    (oldest_utc, newest_utc)
                )
                temp_hum_row = cursor.fetchone()
                avg_temp = float(temp_hum_row['avg_temp']) if temp_hum_row['avg_temp'] else 0.0
                avg_hum = float(temp_hum_row['avg_hum']) if temp_hum_row['avg_hum'] else 0.0
            else:
                avg_temp = 0.0
                avg_hum = 0.0
        else:
            avg_temp = 0.0
            avg_hum = 0.0
        
        # Get optimization enabled percentage (check system_settings)
        cursor.execute(
            """
            SELECT setting_value
            FROM system_settings
            WHERE setting_key = 'optimization_enabled'
            """
        )
        opt_row = cursor.fetchone()
        optimization_percentage = 100.0 if (opt_row and opt_row['setting_value'].lower() == 'true') else 0.0
        
        # Cycles by month (last 12 months)
        cycles_by_month = []
        for i in range(12):
            month_date = datetime.now(GMT8) - timedelta(days=30 * i)
            month_start = month_date.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            if i == 0:
                month_end = datetime.now(GMT8)
            else:
                next_month = month_start + timedelta(days=32)
                month_end = next_month.replace(day=1) - timedelta(days=1)
            
            cursor.execute(
                """
                SELECT COUNT(*) as count
                FROM compost_batch
                WHERE status = 'completed'
                  AND start_date >= %s AND start_date <= %s
                """,
                (month_start, month_end)
            )
            count_row = cursor.fetchone()
            cycles_by_month.append({
                'month': month_start.strftime('%Y-%m'),
                'count': count_row['count'] if count_row else 0
            })
        
        cycles_by_month.reverse()  # Oldest to newest
        
        # Temperature trend (average per month for last 6 months)
        temperature_trend = []
        for i in range(6):
            month_date = datetime.now(GMT8) - timedelta(days=30 * i)
            month_start = month_date.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            if i == 0:
                month_end = datetime.now(GMT8)
            else:
                next_month = month_start + timedelta(days=32)
                month_end = next_month.replace(day=1) - timedelta(days=1)
            
            month_start_utc = month_start.astimezone(timezone.utc) - timedelta(hours=8)
            month_end_utc = month_end.astimezone(timezone.utc) - timedelta(hours=8)
            
            cursor.execute(
                """
                SELECT AVG(temperature) as avg_temp
                FROM sensor_data
                WHERE timestamp >= %s AND timestamp <= %s
                  AND timestamp <= NOW() + INTERVAL '1 day'
                """,
                (month_start_utc, month_end_utc)
            )
            temp_row = cursor.fetchone()
            avg_temp_month = float(temp_row['avg_temp']) if temp_row['avg_temp'] else 0.0
            temperature_trend.append({
                'month': month_start.strftime('%Y-%m'),
                'average_temperature': round(avg_temp_month, 1)
            })
        
        temperature_trend.reverse()
        
        # Humidity trend (average per month for last 6 months)
        humidity_trend = []
        for i in range(6):
            month_date = datetime.now(GMT8) - timedelta(days=30 * i)
            month_start = month_date.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            if i == 0:
                month_end = datetime.now(GMT8)
            else:
                next_month = month_start + timedelta(days=32)
                month_end = next_month.replace(day=1) - timedelta(days=1)
            
            month_start_utc = month_start.astimezone(timezone.utc) - timedelta(hours=8)
            month_end_utc = month_end.astimezone(timezone.utc) - timedelta(hours=8)
            
            cursor.execute(
                """
                SELECT AVG(humidity) as avg_hum
                FROM sensor_data
                WHERE timestamp >= %s AND timestamp <= %s
                  AND timestamp <= NOW() + INTERVAL '1 day'
                """,
                (month_start_utc, month_end_utc)
            )
            hum_row = cursor.fetchone()
            avg_hum_month = float(hum_row['avg_hum']) if hum_row['avg_hum'] else 0.0
            humidity_trend.append({
                'month': month_start.strftime('%Y-%m'),
                'average_humidity': round(avg_hum_month, 1)
            })
        
        humidity_trend.reverse()
        
        # Waste processed trend (total waste per month for last 6 months)
        waste_processed_trend = []
        for i in range(6):
            month_date = datetime.now(GMT8) - timedelta(days=30 * i)
            month_start = month_date.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            if i == 0:
                month_end = datetime.now(GMT8)
            else:
                next_month = month_start + timedelta(days=32)
                month_end = next_month.replace(day=1) - timedelta(days=1)
            
            cursor.execute(
                """
                SELECT COALESCE(SUM(green_waste_kg + brown_waste_kg), 0) as total_waste
                FROM compost_batch
                WHERE status = 'completed'
                  AND start_date >= %s AND start_date <= %s
                """,
                (month_start, month_end)
            )
            waste_row = cursor.fetchone()
            total_waste_month = float(waste_row['total_waste']) if waste_row['total_waste'] else 0.0
            waste_processed_trend.append({
                'month': month_start.strftime('%Y-%m'),
                'total_waste_kg': round(total_waste_month, 2)
            })
        
        waste_processed_trend.reverse()
        
        cursor.close()
        conn.close()
        
        return CycleAnalytics(
            total_completed_cycles=len(cycles),
            average_composting_days=round(average_days, 1),
            total_composted_waste_kg=round(total_waste_kg, 2),
            average_temperature=round(avg_temp, 1),
            average_humidity=round(avg_hum, 1),
            optimization_enabled_percentage=optimization_percentage,
            cycles_by_month=cycles_by_month,
            temperature_trend=temperature_trend,
            humidity_trend=humidity_trend,
            waste_processed_trend=waste_processed_trend
        )
        
    except Exception as e:
        logger.error(f"Error retrieving completed cycles analytics: {e}")
        import traceback
        logger.error(traceback.format_exc())
        # Ensure connection is closed on error
        try:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()
        except:
            pass
        raise HTTPException(status_code=500, detail=f"Error retrieving analytics: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=config.API_HOST,
        port=config.API_PORT,
        log_level="info"
    )

