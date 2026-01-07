-- Migration: Insert Mock Data for Completed Cycles Analytics
-- Created: 2026-01-06
-- Description: Inserts mock completed cycles and sensor data for analytics testing

-- Insert mock completed cycles (last 6 months)
INSERT INTO compost_batch (start_date, projected_end_date, status, green_waste_kg, brown_waste_kg, initial_volume_liters, total_volume_liters, cn_ratio)
VALUES
  -- Cycle 1: Completed 1 month ago
  (NOW() - INTERVAL '2 months', NOW() - INTERVAL '1 month', 'completed', 0.8, 0.185, 15.0, 12.0, 27.5),
  -- Cycle 2: Completed 2 months ago
  (NOW() - INTERVAL '3 months', NOW() - INTERVAL '2 months', 'completed', 0.9, 0.208, 18.0, 14.0, 27.8),
  -- Cycle 3: Completed 3 months ago
  (NOW() - INTERVAL '4 months', NOW() - INTERVAL '3 months', 'completed', 0.7, 0.162, 12.0, 10.0, 27.2),
  -- Cycle 4: Completed 4 months ago
  (NOW() - INTERVAL '5 months', NOW() - INTERVAL '4 months', 'completed', 1.0, 0.231, 20.0, 16.0, 27.5),
  -- Cycle 5: Completed 5 months ago
  (NOW() - INTERVAL '6 months', NOW() - INTERVAL '5 months', 'completed', 0.6, 0.139, 10.0, 8.0, 27.0),
  -- Cycle 6: Completed 6 months ago
  (NOW() - INTERVAL '7 months', NOW() - INTERVAL '6 months', 'completed', 0.85, 0.196, 16.0, 13.0, 27.6)
ON CONFLICT DO NOTHING;

-- Insert mock sensor data for completed cycles (temperature and humidity readings)
-- This simulates sensor readings during the composting process
DO $$
DECLARE
  cycle_record RECORD;
  cycle_date TIMESTAMP;
  days_diff INTEGER;
  temp_value NUMERIC;
  hum_value NUMERIC;
  i INTEGER;
BEGIN
  -- Loop through completed cycles
  FOR cycle_record IN 
    SELECT id, start_date, projected_end_date 
    FROM compost_batch 
    WHERE status = 'completed'
  LOOP
    days_diff := EXTRACT(DAY FROM (cycle_record.projected_end_date - cycle_record.start_date))::INTEGER;
    cycle_date := cycle_record.start_date;
    
    -- Generate sensor readings every 6 hours during the cycle
    FOR i IN 0..(days_diff * 4) LOOP
      -- Simulate temperature: starts low, peaks in middle, cools at end
      temp_value := 25.0 + 
                    (55.0 * SIN(PI() * i / (days_diff * 4))) + 
                    (RANDOM() * 5.0 - 2.5); -- Add some randomness
      
      -- Simulate humidity: starts high, decreases, then stabilizes
      hum_value := 75.0 - 
                   (20.0 * SIN(PI() * i / (days_diff * 4))) + 
                   (RANDOM() * 5.0 - 2.5);
      
      -- Ensure values are in reasonable ranges
      temp_value := GREATEST(20.0, LEAST(70.0, temp_value));
      hum_value := GREATEST(40.0, LEAST(80.0, hum_value));
      
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
  SUM(green_waste_kg + brown_waste_kg) as total_waste_kg
FROM compost_batch
WHERE status = 'completed';

