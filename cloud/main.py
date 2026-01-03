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

class CompostBatchCreate(BaseModel):
    start_date: datetime
    projected_end_date: datetime
    status: str = "active"

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
        
        # Calculate start date (use GMT+8 to match stored timestamps)
        end_date = datetime.now(GMT8)
        start_date = end_date - timedelta(days=days)
        
        # Query sensor data
        cursor.execute(
            """
            SELECT timestamp, temperature, humidity
            FROM sensor_data
            WHERE timestamp >= %s AND timestamp <= %s
            ORDER BY timestamp ASC
            """,
            (start_date, end_date)
        )
        
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        
        # Convert to list of SensorDataPoint
        data = [
            SensorDataPoint(
                timestamp=row['timestamp'],
                temperature=float(row['temperature']),
                humidity=float(row['humidity'])
            )
            for row in rows
        ]
        
        logger.info(f"Retrieved {len(data)} sensor data points for last {days} days")
        return SensorDataResponse(data=data)
        
    except Exception as e:
        logger.error(f"Error retrieving sensor data: {e}")
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
            SELECT id, start_date, projected_end_date, status, created_at
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
            created_at=row['created_at']
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving current batch: {e}")
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
            INSERT INTO compost_batch (start_date, projected_end_date, status)
            VALUES (%s, %s, %s)
            RETURNING id, start_date, projected_end_date, status, created_at
            """,
            (batch.start_date, batch.projected_end_date, batch.status)
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
            created_at=row[4]
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
        
        # Get temperature data for analysis (use GMT+8 to match stored timestamps)
        end_date = datetime.now(GMT8)
        start_date = end_date - timedelta(days=min(days, 30))  # Analyze last 30 days max
        
        cursor.execute(
            """
            SELECT timestamp, temperature
            FROM sensor_data
            WHERE timestamp >= %s AND timestamp <= %s
            ORDER BY timestamp ASC
            """,
            (start_date, end_date)
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
        raise HTTPException(status_code=500, detail=f"Error calculating completion status: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=config.API_HOST,
        port=config.API_PORT,
        log_level="info"
    )

