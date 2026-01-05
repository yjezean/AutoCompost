# Phase 2 Implementation Plan - Multi-Cycle Management

## Overview

Phase 2 adds multi-cycle compost batch management with waste tracking and nitrogen balance calculations. This phase builds on the completed Phase 1 infrastructure.

## Current Status

- ✅ Phase 1 complete (all core features working)
- 🚧 Phase 2 not started

---

## GCP Environment Overview

**Server Details:**

- **IP Address:** `34.87.144.95`
- **User:** `mrchongyijian`
- **Backend Directory:** `/opt/compost-backend`
- **Database:** PostgreSQL (localhost)
- **MQTT Broker:** Mosquitto (localhost:1883)
- **API Port:** `8000`
- **Services:** Managed via systemd

**Connection:**

```bash
ssh mrchongyijian@34.87.144.95
```

**Key Directories:**

- `/opt/compost-backend/` - Backend code and configuration
- `/var/log/compost/` - Application logs
- `/etc/systemd/system/` - Service files

---

## Implementation Steps

### Step 1: Backend Database Schema Updates

**1.1 Connect to GCP Server:**

```bash
# SSH into your GCP server
ssh mrchongyijian@34.87.144.95
# Or use your SSH key if configured
ssh -i ~/.ssh/your_key mrchongyijian@34.87.144.95
```

**1.2 Create Migration SQL File:**

```bash
# Navigate to backend directory
cd /opt/compost-backend

# Create migrations directory if it doesn't exist
mkdir -p migrations

# Create Phase 2 migration file
nano migrations/002_phase2_schema_updates.sql
```

**1.3 Add Migration SQL Content:**

Copy the following SQL into the migration file:

```sql
-- Phase 2: Multi-Cycle Management Schema Updates
-- Migration: 002_phase2_schema_updates.sql

-- Update compost_batch table with waste tracking columns
ALTER TABLE compost_batch ADD COLUMN IF NOT EXISTS green_waste_kg DECIMAL(5,2);
ALTER TABLE compost_batch ADD COLUMN IF NOT EXISTS brown_waste_kg DECIMAL(5,2);
ALTER TABLE compost_batch ADD COLUMN IF NOT EXISTS total_volume_liters DECIMAL(8,2);
ALTER TABLE compost_batch ADD COLUMN IF NOT EXISTS cn_ratio DECIMAL(4,2);
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
    carbon_nitrogen_ratio DECIMAL(4,2),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create material database (for C:N ratios)
CREATE TABLE IF NOT EXISTS compost_materials (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    material_type VARCHAR(50) NOT NULL, -- 'green' or 'brown'
    carbon_nitrogen_ratio DECIMAL(4,2) NOT NULL,
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
```

**1.4 Apply Migration to Database:**

```bash
# Connect to PostgreSQL database
# Using psql with environment variables from .env
cd /opt/compost-backend
source venv/bin/activate

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

# Connect to database and run migration
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f migrations/002_phase2_schema_updates.sql

# Or connect directly (you'll be prompted for password)
psql -h localhost -U compost_user -d compost_db -f migrations/002_phase2_schema_updates.sql

# Alternative: Connect interactively and run SQL
psql -h localhost -U compost_user -d compost_db
# Then paste the SQL commands or use \i command:
\i migrations/002_phase2_schema_updates.sql
```

**1.5 Verify Migration:**

```bash
# Connect to database
psql -h localhost -U compost_user -d compost_db

# Check if new columns exist
\d compost_batch

# Check if new tables exist
\dt compost_materials
\dt cycle_waste_input

# Verify materials were inserted
SELECT * FROM compost_materials;

# Check compost_batch structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'compost_batch'
ORDER BY ordinal_position;

# Exit psql
\q
```

**1.6 Backup Database (Recommended Before Migration):**

```bash
# Create backup before migration
cd /opt/compost-backend
export $(cat .env | grep -v '^#' | xargs)
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME > backups/backup_before_phase2_$(date +%Y%m%d_%H%M%S).sql

# Or create backup directory first
mkdir -p backups
pg_dump -h localhost -U compost_user -d compost_db > backups/backup_before_phase2_$(date +%Y%m%d_%H%M%S).sql
```

---

### Step 2: Backend API Endpoints

**2.1 Update Code on GCP Server:**

```bash
# SSH into GCP server
ssh mrchongyijian@34.87.144.95

# Navigate to backend directory
cd /opt/compost-backend

# If using git, pull latest changes
git pull origin main
# Or if working directly on server, edit files with nano/vim
```

**2.2 Update `cloud/main.py` with new models:**

```python
class CompostBatchCreate(BaseModel):
    start_date: datetime
    projected_end_date: datetime
    status: str = "planning"
    green_waste_kg: Optional[float] = None
    brown_waste_kg: Optional[float] = None
    initial_volume_liters: Optional[float] = None

class CompostBatchUpdate(BaseModel):
    green_waste_kg: Optional[float] = None
    brown_waste_kg: Optional[float] = None
    initial_volume_liters: Optional[float] = None
    status: Optional[str] = None

class CNRatioResponse(BaseModel):
    current_ratio: float
    optimal_ratio: float = 27.5  # Target: 25-30:1
    green_waste_kg: float
    brown_waste_kg: float
    suggested_brown_kg: Optional[float] = None
    status: str  # "optimal", "too_much_green", "too_much_brown"
```

**2.2 Add new endpoints:**

- `GET /api/v1/cycles` - List all cycles (all statuses)
- `GET /api/v1/cycles/{id}` - Get cycle details
- `POST /api/v1/cycles` - Create new cycle
- `PUT /api/v1/cycles/{id}` - Update cycle (waste amounts, etc.)
- `PUT /api/v1/cycles/{id}/activate` - Set cycle as active
- `POST /api/v1/cycles/{id}/calculate-ratio` - Calculate C:N ratio
- `GET /api/v1/cycles/{id}/progress` - Get volume-based progress
- `GET /api/v1/materials` - Get list of compost materials

**2.3 Test API Endpoints After Implementation:**

```bash
# On GCP server, test endpoints locally
cd /opt/compost-backend
source venv/bin/activate

# Test with curl (replace with your server IP)
curl http://localhost:8000/api/v1/materials
curl http://localhost:8000/api/v1/cycles
curl http://localhost:8000/api/v1/cycles/1

# Or use the API documentation
# Visit: http://34.87.144.95:8000/docs
```

**2.4 Restart API Service After Code Changes:**

```bash
# Restart FastAPI service to apply changes
sudo systemctl restart compost-api

# Check service status
sudo systemctl status compost-api

# View logs to verify no errors
sudo journalctl -u compost-api -f
# Press Ctrl+C to exit log view

# Or view last 50 lines
sudo journalctl -u compost-api -n 50
```

**2.3 C:N Ratio Calculation Logic:**

```python
def calculate_cn_ratio(green_kg: float, brown_kg: float) -> dict:
    """
    Calculate C:N ratio based on typical values:
    - Greens: ~20:1 C:N
    - Browns: ~60:1 C:N
    - Target mix: 25-30:1 C:N
    """
    if green_kg == 0 or brown_kg == 0:
        return {"status": "insufficient_data"}

    # Simplified calculation (can be enhanced with material-specific ratios)
    green_cn = 20.0
    brown_cn = 60.0

    # Weighted average
    total_kg = green_kg + brown_kg
    green_weight = green_kg / total_kg
    brown_weight = brown_kg / total_kg

    current_ratio = (green_weight * green_cn) + (brown_weight * brown_cn)

    # Calculate suggested brown amount for optimal ratio (target: 27.5)
    target_ratio = 27.5
    if current_ratio < target_ratio:
        # Need more browns
        suggested_brown = green_kg * (green_cn / target_ratio - 1)
        status = "too_much_green"
    elif current_ratio > target_ratio * 1.2:
        # Too much browns
        suggested_brown = None
        status = "too_much_brown"
    else:
        suggested_brown = None
        status = "optimal"

    return {
        "current_ratio": round(current_ratio, 2),
        "optimal_ratio": target_ratio,
        "green_waste_kg": green_kg,
        "brown_waste_kg": brown_kg,
        "suggested_brown_kg": round(suggested_brown, 2) if suggested_brown else None,
        "status": status
    }
```

---

### Step 3: Flutter App - Data Models

**3.1 Update `models/compost_batch.dart`:**

```dart
class CompostBatch {
  final int id;
  final DateTime startDate;
  final DateTime projectedEndDate;
  final String status; // 'planning', 'active', 'completed', 'archived'
  final DateTime createdAt;
  final double? greenWasteKg;
  final double? brownWasteKg;
  final double? totalVolumeLiters;
  final double? cnRatio;
  final double? initialVolumeLiters;

  CompostBatch({
    required this.id,
    required this.startDate,
    required this.projectedEndDate,
    required this.status,
    required this.createdAt,
    this.greenWasteKg,
    this.brownWasteKg,
    this.totalVolumeLiters,
    this.cnRatio,
    this.initialVolumeLiters,
  });

  factory CompostBatch.fromJson(Map<String, dynamic> json) {
    return CompostBatch(
      id: json['id'] as int,
      startDate: DateTime.parse(json['start_date']),
      projectedEndDate: DateTime.parse(json['projected_end_date']),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at']),
      greenWasteKg: json['green_waste_kg'] as double?,
      brownWasteKg: json['brown_waste_kg'] as double?,
      totalVolumeLiters: json['total_volume_liters'] as double?,
      cnRatio: json['cn_ratio'] as double?,
      initialVolumeLiters: json['initial_volume_liters'] as double?,
    );
  }
}
```

**3.2 Create `models/compost_material.dart`:**

```dart
class CompostMaterial {
  final int id;
  final String name;
  final String materialType; // 'green' or 'brown'
  final double carbonNitrogenRatio;
  final double? densityKgPerLiter;
  final String? description;

  CompostMaterial({
    required this.id,
    required this.name,
    required this.materialType,
    required this.carbonNitrogenRatio,
    this.densityKgPerLiter,
    this.description,
  });

  factory CompostMaterial.fromJson(Map<String, dynamic> json) {
    return CompostMaterial(
      id: json['id'] as int,
      name: json['name'] as String,
      materialType: json['material_type'] as String,
      carbonNitrogenRatio: (json['carbon_nitrogen_ratio'] as num).toDouble(),
      densityKgPerLiter: json['density_kg_per_liter'] as double?,
      description: json['description'] as String?,
    );
  }
}
```

**3.3 Create `models/cn_ratio.dart`:**

```dart
class CNRatio {
  final double currentRatio;
  final double optimalRatio;
  final double greenWasteKg;
  final double brownWasteKg;
  final double? suggestedBrownKg;
  final String status; // 'optimal', 'too_much_green', 'too_much_brown'

  CNRatio({
    required this.currentRatio,
    required this.optimalRatio,
    required this.greenWasteKg,
    required this.brownWasteKg,
    this.suggestedBrownKg,
    required this.status,
  });

  factory CNRatio.fromJson(Map<String, dynamic> json) {
    return CNRatio(
      currentRatio: (json['current_ratio'] as num).toDouble(),
      optimalRatio: (json['optimal_ratio'] as num).toDouble(),
      greenWasteKg: (json['green_waste_kg'] as num).toDouble(),
      brownWasteKg: (json['brown_waste_kg'] as num).toDouble(),
      suggestedBrownKg: json['suggested_brown_kg'] as double?,
      status: json['status'] as String,
    );
  }
}
```

---

### Step 4: Flutter App - Services

**4.1 Update `services/api_service.dart`:**

Add new methods:

- `Future<List<CompostBatch>> getCycles()`
- `Future<CompostBatch> getCycle(int id)`
- `Future<CompostBatch> createCycle(CompostBatchCreate data)`
- `Future<CompostBatch> updateCycle(int id, Map<String, dynamic> data)`
- `Future<void> activateCycle(int id)`
- `Future<CNRatio> calculateCNRatio(int cycleId, double greenKg, double brownKg)`
- `Future<List<CompostMaterial>> getMaterials()`

---

### Step 5: Flutter App - Providers

**5.1 Create `providers/cycle_provider.dart`:**

```dart
class CycleProvider with ChangeNotifier {
  List<CompostBatch> _cycles = [];
  CompostBatch? _activeCycle;
  bool _isLoading = false;
  String? _error;

  List<CompostBatch> get cycles => _cycles;
  CompostBatch? get activeCycle => _activeCycle;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCycles() async {
    // Fetch all cycles from API
  }

  Future<void> createCycle(CompostBatch cycle) async {
    // Create new cycle
  }

  Future<void> activateCycle(int id) async {
    // Set cycle as active
  }

  Future<void> updateCycle(int id, Map<String, dynamic> data) async {
    // Update cycle data
  }
}
```

**5.2 Update `providers/compost_batch_provider.dart`:**

- Add support for multiple cycles
- Update to work with active cycle from CycleProvider

---

### Step 6: Flutter App - New Screens

**6.1 Create `screens/cycle_management_screen.dart`:**

- List of all cycles (grouped by status)
- Create new cycle button
- Cycle cards showing:
  - Status badge
  - Start date
  - Progress
  - Waste amounts
  - C:N ratio indicator
- Tap to view/edit cycle details
- Activate cycle button

**6.2 Create `screens/cycle_create_screen.dart`:**

- Form fields:
  - Start date picker
  - Projected end date picker
  - Green waste amount (kg)
  - Brown waste amount (kg)
  - Material type selectors (optional)
- C:N ratio calculator widget
- Volume estimation
- Create button

**6.3 Create `screens/cycle_detail_screen.dart`:**

- Cycle information display
- Waste input tracking
- C:N ratio visualization
- Progress tracking (time + volume)
- Edit button
- Activate button (if not active)

---

### Step 7: Flutter App - New Widgets

**7.1 Create `widgets/cn_ratio_indicator.dart`:**

- Visual indicator showing current vs optimal ratio
- Color coding (green = optimal, yellow = needs adjustment)
- Suggested brown amount display

**7.2 Create `widgets/waste_input_form.dart`:**

- Green waste input field
- Brown waste input field
- Material type dropdowns
- Real-time C:N ratio calculation
- Volume estimation display

**7.3 Create `widgets/cycle_card.dart`:**

- Cycle information card
- Status badge
- Progress indicator
- Quick actions (activate, edit)

**7.4 Update `widgets/batch_info_card.dart`:**

- Add cycle selector dropdown
- Show cycle-specific information
- Display waste amounts and C:N ratio

---

### Step 8: Flutter App - Navigation Updates

**8.1 Update `main.dart`:**

- Add CycleProvider to MultiProvider
- Add cycle management to navigation (optional: 5th tab or drawer)

**8.2 Update navigation:**

- Option A: Add 5th tab for "Cycles"
- Option B: Add drawer menu with cycle management
- Option C: Add cycle switcher in Dashboard AppBar

---

### Step 9: Integration & Testing

**9.1 Backend Testing:**

- Test database migrations
- Test all new API endpoints
- Test C:N ratio calculations
- Test cycle activation logic

**9.2 Frontend Testing:**

- Test cycle creation flow
- Test waste input forms
- Test C:N ratio calculator
- Test cycle switching
- Test volume progress tracking
- Test with multiple cycles

---

## Implementation Order

1. **Backend First:**

   - Database schema updates
   - API endpoints implementation
   - C:N ratio calculation logic
   - Testing with Postman/curl

2. **Frontend Models & Services:**

   - Update/create data models
   - Update API service
   - Test API integration

3. **Frontend Providers:**

   - Create CycleProvider
   - Update CompostBatchProvider
   - Test state management

4. **Frontend UI:**

   - Create cycle management screen
   - Create cycle creation screen
   - Create cycle detail screen
   - Create new widgets
   - Update existing screens

5. **Integration:**
   - Connect all pieces
   - End-to-end testing
   - Bug fixes and polish

---

## GCP Deployment Workflow

### Complete Deployment Checklist

**1. Local Development:**

```bash
# On your local machine
cd Project_app

# Make changes to code
# Test locally if possible

# Commit changes
git add .
git commit -m "Phase 2: Add multi-cycle management features"
git push origin main
```

**2. Deploy to GCP Server:**

```bash
# SSH into GCP server
ssh mrchongyijian@34.87.144.95

# Navigate to backend directory
cd /opt/compost-backend

# Pull latest changes (if using git)
git pull origin main

# Or manually copy files using scp from local machine:
# scp cloud/main.py mrchongyijian@34.87.144.95:/opt/compost-backend/
```

**3. Apply Database Migrations:**

```bash
# On GCP server
cd /opt/compost-backend
export $(cat .env | grep -v '^#' | xargs)
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f migrations/002_phase2_schema_updates.sql
```

**4. Restart Services:**

```bash
# Restart API service
sudo systemctl restart compost-api

# Check status
sudo systemctl status compost-api

# View logs
sudo journalctl -u compost-api -f
```

**5. Verify Deployment:**

```bash
# Test API endpoints
curl http://localhost:8000/api/v1/materials
curl http://localhost:8000/api/v1/cycles

# Check API documentation
# Visit: http://34.87.144.95:8000/docs
```

---

## Useful GCP Commands Reference

### Database Commands

```bash
# Connect to PostgreSQL
psql -h localhost -U compost_user -d compost_db

# List all tables
\dt

# Describe table structure
\d compost_batch

# Run SQL file
\i migrations/002_phase2_schema_updates.sql

# Execute SQL query
SELECT * FROM compost_batch LIMIT 5;

# Exit psql
\q

# Backup database
pg_dump -h localhost -U compost_user -d compost_db > backup.sql

# Restore database
psql -h localhost -U compost_user -d compost_db < backup.sql
```

### Service Management Commands

```bash
# Check service status
sudo systemctl status compost-api
sudo systemctl status compost-mqtt-listener

# Start services
sudo systemctl start compost-api
sudo systemctl start compost-mqtt-listener

# Stop services
sudo systemctl stop compost-api
sudo systemctl stop compost-mqtt-listener

# Restart services
sudo systemctl restart compost-api
sudo systemctl restart compost-mqtt-listener

# View logs (follow mode)
sudo journalctl -u compost-api -f
sudo journalctl -u compost-mqtt-listener -f

# View last N lines
sudo journalctl -u compost-api -n 100
sudo journalctl -u compost-mqtt-listener -n 100

# View logs since specific time
sudo journalctl -u compost-api --since "1 hour ago"
sudo journalctl -u compost-api --since "2024-01-01 00:00:00"
```

### File Management Commands

```bash
# Navigate to backend
cd /opt/compost-backend

# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Check Python version
python --version

# Edit files
nano main.py
# or
vim main.py

# View file contents
cat main.py
less main.py

# Check file permissions
ls -la

# Create directory
mkdir -p migrations backups
```

### Testing Commands

```bash
# Test API endpoint
curl http://localhost:8000/api/v1/materials
curl http://localhost:8000/api/v1/cycles

# Test with POST request
curl -X POST http://localhost:8000/api/v1/cycles \
  -H "Content-Type: application/json" \
  -d '{"start_date": "2024-01-01T00:00:00", "projected_end_date": "2024-01-21T00:00:00", "status": "planning"}'

# Test MQTT subscription (if mosquitto-clients installed)
mosquitto_sub -h localhost -t compost/sensor/data
mosquitto_sub -h localhost -t compost/status/#

# Check if port is listening
sudo netstat -tulpn | grep 8000
sudo netstat -tulpn | grep 1883
```

### Git Commands (if using git on server)

```bash
# Pull latest changes
cd /opt/compost-backend
git pull origin main

# Check git status
git status

# View commit history
git log --oneline -10

# Checkout specific branch
git checkout main
```

---

## Dependencies (No New Packages Needed)

All required packages are already in `pubspec.yaml`:

- `provider` - State management ✅
- `http` - API calls ✅
- `intl` - Date formatting ✅

---

## Troubleshooting

### Database Connection Issues

```bash
# Check if PostgreSQL is running
sudo systemctl status postgresql

# Check PostgreSQL connection
psql -h localhost -U compost_user -d compost_db -c "SELECT version();"

# Check database exists
psql -h localhost -U compost_user -l | grep compost_db

# Reset database password (if needed)
sudo -u postgres psql
ALTER USER compost_user WITH PASSWORD 'new_password';
\q
```

### API Service Issues

```bash
# Check if service is running
sudo systemctl status compost-api

# Check for errors in logs
sudo journalctl -u compost-api -n 100 | grep -i error

# Test API manually
cd /opt/compost-backend
source venv/bin/activate
python -c "from main import app; print('Import successful')"

# Check if port 8000 is in use
sudo lsof -i :8000
sudo netstat -tulpn | grep 8000
```

### Migration Issues

```bash
# Check if migration was applied
psql -h localhost -U compost_user -d compost_db -c "\d compost_batch"

# Rollback migration (if needed - be careful!)
psql -h localhost -U compost_user -d compost_db << EOF
ALTER TABLE compost_batch DROP COLUMN IF EXISTS green_waste_kg;
ALTER TABLE compost_batch DROP COLUMN IF EXISTS brown_waste_kg;
-- Add other rollback commands as needed
EOF

# Restore from backup
psql -h localhost -U compost_user -d compost_db < backups/backup_before_phase2_YYYYMMDD_HHMMSS.sql
```

### Permission Issues

```bash
# Check file ownership
ls -la /opt/compost-backend/

# Fix ownership (if needed)
sudo chown -R mrchongyijian:mrchongyijian /opt/compost-backend/

# Check service file permissions
ls -la /etc/systemd/system/compost-api.service
```

### Environment Variables

```bash
# Check .env file exists
ls -la /opt/compost-backend/.env

# Verify environment variables are loaded
cd /opt/compost-backend
source venv/bin/activate
export $(cat .env | grep -v '^#' | xargs)
echo $DB_HOST
echo $DB_NAME
```

---

## Notes

- Phase 2 builds on Phase 1 infrastructure
- Only one cycle can be "active" at a time (hardware limitation)
- C:N ratio calculation can be enhanced with material-specific ratios
- Volume tracking requires user input (no automatic measurement)
- Historical cycles can be viewed but not actively monitored
- Always backup database before running migrations
- Test API endpoints after deployment
- Monitor logs after service restart
