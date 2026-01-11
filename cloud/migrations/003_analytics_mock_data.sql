-- Migration: Analytics Mock Data
-- Created: 2026-01-06
-- Updated: 2026-01-06 (Enhanced with better patterns, no zero waste, humidity trends)
-- Description: Inserts mock completed cycles and sensor data for analytics testing
-- Note: This migration is idempotent (safe to run multiple times). If you need to clean existing mock data,
--       manually delete completed cycles: DELETE FROM compost_batch WHERE status = 'completed';

-- Insert mock completed cycles (last 6 months with varied waste amounts)
-- All cycles have non-zero waste to ensure good analytics patterns
INSERT INTO compost_batch (start_date, projected_end_date, status, green_waste_kg, brown_waste_kg, initial_volume_liters, total_volume_liters, cn_ratio)
VALUES
  -- Cycle 1: Completed 1 month ago (small batch)
  (NOW() - INTERVAL '2 months', NOW() - INTERVAL '1 month', 'completed', 0.8, 0.185, 15.0, 12.0, 27.5),
  -- Cycle 2: Completed 2 months ago (medium batch)
  (NOW() - INTERVAL '3 months', NOW() - INTERVAL '2 months', 'completed', 0.9, 0.208, 18.0, 14.0, 27.8),
  -- Cycle 3: Completed 3 months ago (small batch)
  (NOW() - INTERVAL '4 months', NOW() - INTERVAL '3 months', 'completed', 0.7, 0.162, 12.0, 10.0, 27.2),
  -- Cycle 4: Completed 4 months ago (large batch)
  (NOW() - INTERVAL '5 months', NOW() - INTERVAL '4 months', 'completed', 1.0, 0.231, 20.0, 16.0, 27.5),
  -- Cycle 5: Completed 5 months ago (small batch)
  (NOW() - INTERVAL '6 months', NOW() - INTERVAL '5 months', 'completed', 0.6, 0.139, 10.0, 8.0, 27.0),
  -- Cycle 6: Completed 6 months ago (medium batch)
  (NOW() - INTERVAL '7 months', NOW() - INTERVAL '6 months', 'completed', 0.85, 0.196, 16.0, 13.0, 27.6),
  -- Additional cycles for better monthly distribution
  -- Cycle 7: Completed 1.5 months ago
  (NOW() - INTERVAL '2 months' - INTERVAL '15 days', NOW() - INTERVAL '1 month' - INTERVAL '15 days', 'completed', 0.75, 0.173, 14.0, 11.0, 27.4),
  -- Cycle 8: Completed 2.5 months ago
  (NOW() - INTERVAL '3 months' - INTERVAL '15 days', NOW() - INTERVAL '2 months' - INTERVAL '15 days', 'completed', 0.95, 0.219, 19.0, 15.0, 27.7),
  -- Cycle 9: Completed 3.5 months ago
  (NOW() - INTERVAL '4 months' - INTERVAL '15 days', NOW() - INTERVAL '3 months' - INTERVAL '15 days', 'completed', 0.65, 0.150, 11.0, 9.0, 27.1),
  -- Cycle 10: Completed 4.5 months ago
  (NOW() - INTERVAL '5 months' - INTERVAL '15 days', NOW() - INTERVAL '4 months' - INTERVAL '15 days', 'completed', 0.88, 0.203, 17.0, 13.5, 27.6)
ON CONFLICT DO NOTHING;

-- Insert mock sensor data for completed cycles with realistic patterns
-- This simulates sensor readings during the composting process with varied humidity patterns
DO $$
DECLARE
  cycle_record RECORD;
  cycle_date TIMESTAMP;
  days_diff INTEGER;
  temp_value NUMERIC;
  hum_value NUMERIC;
  i INTEGER;
  cycle_index INTEGER := 0;
  -- Variables for creating varied patterns
  base_temp NUMERIC;
  base_hum NUMERIC;
  temp_variation NUMERIC;
  hum_variation NUMERIC;
BEGIN
  -- Loop through completed cycles
  FOR cycle_record IN 
    SELECT id, start_date, projected_end_date 
    FROM compost_batch 
    WHERE status = 'completed'
    ORDER BY start_date ASC
  LOOP
    cycle_index := cycle_index + 1;
    days_diff := EXTRACT(DAY FROM (cycle_record.projected_end_date - cycle_record.start_date))::INTEGER;
    cycle_date := cycle_record.start_date;
    
    -- Create varied patterns for each cycle
    -- Temperature: varies between cycles (some hotter, some cooler)
    base_temp := 30.0 + (cycle_index % 3) * 5.0; -- Base temp varies: 30, 35, 40
    temp_variation := 25.0 + (cycle_index % 2) * 10.0; -- Variation: 25 or 35
    
    -- Humidity: varies between cycles (some more humid, some drier)
    -- Create a pattern where humidity trends vary by month
    base_hum := 50.0 + (cycle_index % 4) * 7.5; -- Base hum varies: 50, 57.5, 65, 72.5
    hum_variation := 15.0 + (cycle_index % 3) * 5.0; -- Variation: 15, 20, 25
    
    -- Generate sensor readings every 6 hours during the cycle
    FOR i IN 0..(days_diff * 4) LOOP
      -- Simulate temperature: starts low, peaks in middle, cools at end
      -- Use sine wave for smooth transition
      temp_value := base_temp + 
                    (temp_variation * SIN(PI() * i / GREATEST(days_diff * 4, 1))) + 
                    (RANDOM() * 3.0 - 1.5); -- Add small randomness
      
      -- Simulate humidity: create varied patterns
      -- Pattern 1: Starts high, decreases gradually (most common)
      -- Pattern 2: Starts low, increases then stabilizes
      -- Pattern 3: Stable with small variations
      -- Pattern 4: High throughout with small dips
      CASE (cycle_index % 4)
        WHEN 0 THEN
          -- Pattern 1: High start, gradual decrease
          hum_value := base_hum + hum_variation - 
                       (hum_variation * 0.7 * (i::NUMERIC / GREATEST(days_diff * 4, 1))) +
                       (RANDOM() * 4.0 - 2.0);
        WHEN 1 THEN
          -- Pattern 2: Low start, increases then stabilizes
          hum_value := base_hum - hum_variation * 0.5 + 
                       (hum_variation * 0.8 * SIN(PI() * i / (2 * GREATEST(days_diff * 4, 1)))) +
                       (RANDOM() * 4.0 - 2.0);
        WHEN 2 THEN
          -- Pattern 3: Stable with small variations
          hum_value := base_hum + 
                       (RANDOM() * 8.0 - 4.0) +
                       (2.0 * SIN(PI() * i / GREATEST(days_diff * 2, 1)));
        ELSE
          -- Pattern 4: High throughout with small dips
          hum_value := base_hum + hum_variation * 0.6 - 
                       (hum_variation * 0.3 * ABS(SIN(PI() * i / GREATEST(days_diff * 1.5, 1)))) +
                       (RANDOM() * 3.0 - 1.5);
      END CASE;
      
      -- Ensure values are in reasonable ranges
      temp_value := GREATEST(20.0, LEAST(70.0, temp_value));
      hum_value := GREATEST(35.0, LEAST(85.0, hum_value));
      
      -- Insert sensor data
      INSERT INTO sensor_data (timestamp, temperature, humidity)
      VALUES (
        cycle_date + (i * INTERVAL '6 hours'),
        temp_value,
        hum_value
      )
      ON CONFLICT DO NOTHING;
    END LOOP;
  END LOOP;
END $$;

-- Verify inserted data
SELECT 
  COUNT(*) as total_completed_cycles,
  AVG(EXTRACT(DAY FROM (projected_end_date - start_date))) as avg_days,
  SUM(green_waste_kg + brown_waste_kg) as total_waste_kg,
  MIN(green_waste_kg + brown_waste_kg) as min_waste_kg,
  MAX(green_waste_kg + brown_waste_kg) as max_waste_kg
FROM compost_batch
WHERE status = 'completed';

-- Verify sensor data distribution
SELECT 
  COUNT(*) as total_sensor_records,
  MIN(timestamp) as oldest_timestamp,
  MAX(timestamp) as newest_timestamp,
  AVG(temperature) as avg_temperature,
  AVG(humidity) as avg_humidity,
  MIN(humidity) as min_humidity,
  MAX(humidity) as max_humidity
FROM sensor_data
WHERE timestamp >= NOW() - INTERVAL '1 year';

-- Verify monthly distribution for trends
SELECT 
  TO_CHAR(start_date, 'YYYY-MM') as month,
  COUNT(*) as cycles_count,
  SUM(green_waste_kg + brown_waste_kg) as total_waste_kg
FROM compost_batch
WHERE status = 'completed'
GROUP BY TO_CHAR(start_date, 'YYYY-MM')
ORDER BY month DESC;
