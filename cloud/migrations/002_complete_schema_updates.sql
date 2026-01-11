-- Complete Schema Updates: Phase 2 + Optimization Settings
-- Migration: 002_complete_schema_updates.sql
-- Created: 2026-01-06
-- Description: Combined migration for Phase 2 multi-cycle management and optimization settings
-- 
-- This migration includes:
-- 1. Phase 2: Multi-cycle management schema updates
-- 2. Optimization settings table
--
-- Note: All operations are idempotent (safe to run multiple times)

-- ============================================================================
-- PHASE 2: MULTI-CYCLE MANAGEMENT SCHEMA UPDATES
-- ============================================================================

-- Update compost_batch table with waste tracking columns
ALTER TABLE compost_batch ADD COLUMN IF NOT EXISTS green_waste_kg DECIMAL(5,2);
ALTER TABLE compost_batch ADD COLUMN IF NOT EXISTS brown_waste_kg DECIMAL(5,2);
ALTER TABLE compost_batch ADD COLUMN IF NOT EXISTS total_volume_liters DECIMAL(8,2);
ALTER TABLE compost_batch ADD COLUMN IF NOT EXISTS cn_ratio DECIMAL(6,2);
ALTER TABLE compost_batch ADD COLUMN IF NOT EXISTS initial_volume_liters DECIMAL(8,2);

-- Update status column to support: 'planning', 'active', 'completed', 'archived'
-- Note: If status column already exists, this will not change existing values
-- Existing 'active' batches will remain 'active'
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'compost_batch' AND column_name = 'status'
    ) THEN
        ALTER TABLE compost_batch ADD COLUMN status VARCHAR(20) DEFAULT 'active';
    END IF;
END $$;

-- Create cycle_waste_input table (optional, for detailed tracking)
CREATE TABLE IF NOT EXISTS cycle_waste_input (
    id SERIAL PRIMARY KEY,
    batch_id INT REFERENCES compost_batch(id) ON DELETE CASCADE,
    material_type VARCHAR(50) NOT NULL, -- 'green' or 'brown'
    material_name VARCHAR(100),
    amount_kg DECIMAL(5,2) NOT NULL,
    carbon_nitrogen_ratio DECIMAL(6,2),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create material database (for C:N ratios)
CREATE TABLE IF NOT EXISTS compost_materials (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    material_type VARCHAR(50) NOT NULL, -- 'green' or 'brown'
    carbon_nitrogen_ratio DECIMAL(6,2) NOT NULL,
    density_kg_per_liter DECIMAL(5,3), -- For volume calculations
    description TEXT
);

-- Insert common materials
INSERT INTO compost_materials (name, material_type, carbon_nitrogen_ratio, density_kg_per_liter) VALUES
('Kitchen Scraps', 'green', 20.0, 0.5),
('Vegetable Peels', 'green', 25.0, 0.4),
('Grass Clippings', 'green', 20.0, 0.3),
('Coffee Grounds', 'green', 20.0, 0.4),
('Dry Leaves', 'brown', 60.0, 0.1),
('Cardboard', 'brown', 350.0, 0.2),
('Wood Chips', 'brown', 400.0, 0.3),
('Straw', 'brown', 80.0, 0.1),
('Newspaper', 'brown', 175.0, 0.2)
ON CONFLICT (name) DO NOTHING;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_compost_batch_status ON compost_batch(status);
CREATE INDEX IF NOT EXISTS idx_cycle_waste_input_batch_id ON cycle_waste_input(batch_id);
CREATE INDEX IF NOT EXISTS idx_compost_materials_type ON compost_materials(material_type);

-- ============================================================================
-- OPTIMIZATION SETTINGS
-- ============================================================================

-- Create system settings table for optimization control
CREATE TABLE IF NOT EXISTS system_settings (
    id SERIAL PRIMARY KEY,
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(100) DEFAULT 'system'
);

-- Insert default optimization setting (enabled by default)
INSERT INTO system_settings (setting_key, setting_value, description)
VALUES ('optimization_enabled', 'true', 'Automated temperature and humidity control optimization')
ON CONFLICT (setting_key) DO NOTHING;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_system_settings_key ON system_settings(setting_key);
