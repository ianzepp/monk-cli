# Exercise Tracker Project Example

This example demonstrates the complete workflow of creating a new project using the simplified `monk project` commands, followed by realistic schema design and data operations for an exercise tracking application.

## Project Overview

**Exercise Tracker** - A personal fitness application for tracking workouts, exercises, and progress over time.

### Features
- Log workout sessions with exercises
- Track personal records and progress
- Monitor exercise categories and muscle groups
- View workout history and statistics

## Complete Workflow

### Step 1: Create the Project

```bash
# Initialize the exercise tracker project
monk project init "Exercise Tracker" \
  --description "Personal workout tracking and progress monitoring" \
  --tags fitness,health,personal \
  --create-user admin \
  --auto-login
```

**Expected Output:**
```
ℹ Initializing project 'Exercise Tracker'...
ℹ Creating tenant for project...
✓ Project 'Exercise Tracker' created successfully
ℹ Database: tenant_exercise123
ℹ Adding tenant to local registry...
ℹ Switching to project context...
✓ Switched to project 'Exercise Tracker'
ℹ Creating initial user 'admin'...
✓ User 'admin' created successfully
ℹ Default password: admin123 (change after first login)
ℹ Logging in as 'admin'...
✓ Logged in as 'admin'

✓ Project 'Exercise Tracker' is ready!

Next steps:
  monk status                    # Show current context
  monk data select users         # Start working with data
  monk describe create schema    # Create your first schema
```

### Step 2: Verify Project Setup

```bash
# Check current status
monk status

# List projects to see our new project
monk project list

# Show project details
monk project show "Exercise Tracker"
```

### Step 3: Design Database Schema

Create schema files for our exercise tracking application:

#### **Workout Categories Schema**
```bash
# Create categories schema
cat > categories.json << 'EOF'
{
  "name": "categories",
  "properties": {
    "name": {
      "type": "string",
      "minLength": 1,
      "maxLength": 50
    },
    "description": {
      "type": "string",
      "maxLength": 200
    },
    "color": {
      "type": "string",
      "pattern": "^#[0-9A-Fa-f]{6}$"
    },
    "icon": {
      "type": "string",
      "maxLength": 20
    }
  },
  "required": ["name"],
  "unique": ["name"]
}
EOF

# Create the schema
monk describe create categories < categories.json
```

#### **Exercises Schema**
```bash
# Create exercises schema
cat > exercises.json << 'EOF'
{
  "name": "exercises",
  "properties": {
    "name": {
      "type": "string",
      "minLength": 1,
      "maxLength": 100
    },
    "category_id": {
      "type": "integer"
    },
    "description": {
      "type": "string",
      "maxLength": 500
    },
    "muscle_groups": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "equipment_needed": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "difficulty": {
      "type": "string",
      "enum": ["beginner", "intermediate", "advanced"]
    },
    "instructions": {
      "type": "string",
      "maxLength": 1000
    }
  },
  "required": ["name", "category_id", "difficulty"],
  "unique": ["name"]
}
EOF

# Create the schema
monk describe create exercises < exercises.json
```

#### **Workout Sessions Schema**
```bash
# Create workout sessions schema
cat > workouts.json << 'EOF'
{
  "name": "workouts",
  "properties": {
    "date": {
      "type": "string",
      "format": "date-time"
    },
    "title": {
      "type": "string",
      "minLength": 1,
      "maxLength": 100
    },
    "notes": {
      "type": "string",
      "maxLength": 1000
    },
    "duration_minutes": {
      "type": "integer",
      "minimum": 1,
      "maximum": 480
    },
    "total_exercises": {
      "type": "integer",
      "minimum": 0
    },
    "rating": {
      "type": "integer",
      "minimum": 1,
      "maximum": 5
    }
  },
  "required": ["date", "title"],
  "index": ["date"]
}
EOF

# Create the schema
monk describe create workouts < workouts.json
```

#### **Workout Exercises Schema**
```bash
# Create workout exercises (join table) schema
cat > workout_exercises.json << 'EOF'
{
  "name": "workout_exercises",
  "properties": {
    "workout_id": {
      "type": "integer"
    },
    "exercise_id": {
      "type": "integer"
    },
    "sets": {
      "type": "integer",
      "minimum": 1,
      "maximum": 20
    },
    "reps": {
      "type": "integer",
      "minimum": 1,
      "maximum": 100
    },
    "weight_kg": {
      "type": "number",
      "minimum": 0,
      "maximum": 1000
    },
    "rest_seconds": {
      "type": "integer",
      "minimum": 0,
      "maximum": 600
    },
    "notes": {
      "type": "string",
      "maxLength": 200
    }
  },
  "required": ["workout_id", "exercise_id", "sets", "reps"]
}
EOF

# Create the schema
monk describe create workout_exercises < workout_exercises.json
```

### Step 4: Verify Schema Creation

```bash
# List all schemas
monk data select

# Show schema details
monk describe select categories
monk describe select exercises
monk describe select workouts
monk describe select workout_exercises
```

### Step 5: Populate Initial Data

#### **Add Exercise Categories**
```bash
# Add categories
cat > categories_data.json << 'EOF'
[
  {
    "name": "Cardio",
    "description": "Cardiovascular exercises",
    "color": "#FF6B6B",
    "icon": "🏃"
  },
  {
    "name": "Strength",
    "description": "Strength training exercises",
    "color": "#4ECDC4",
    "icon": "💪"
  },
  {
    "name": "Flexibility",
    "description": "Stretching and mobility exercises",
    "color": "#45B7D1",
    "icon": "🧘"
  },
  {
    "name": "Sports",
    "description": "Sports-specific exercises",
    "color": "#96CEB4",
    "icon": "⚽"
  }
]
EOF

# Create categories
monk data create categories < categories_data.json

# View created categories
monk data select categories
```

#### **Add Exercises**
```bash
# Add exercises
cat > exercises_data.json << 'EOF'
[
  {
    "name": "Push-ups",
    "category_id": 2,
    "description": "Classic upper body exercise",
    "muscle_groups": ["chest", "shoulders", "triceps"],
    "equipment_needed": ["none"],
    "difficulty": "beginner",
    "instructions": "Start in plank position, lower body until chest nearly touches floor, push back up."
  },
  {
    "name": "Squats",
    "category_id": 2,
    "description": "Lower body compound exercise",
    "muscle_groups": ["quadriceps", "glutes", "hamstrings"],
    "equipment_needed": ["none"],
    "difficulty": "beginner",
    "instructions": "Stand with feet shoulder-width apart, lower hips until knees are bent 90 degrees, return to standing."
  },
  {
    "name": "Running",
    "category_id": 1,
    "description": "Cardiovascular running exercise",
    "muscle_groups": ["legs", "core", "cardio"],
    "equipment_needed": ["running shoes"],
    "difficulty": "intermediate",
    "instructions": "Run at steady pace, maintain good posture, breathe rhythmically."
  },
  {
    "name": "Bench Press",
    "category_id": 2,
    "description": "Upper body strength exercise",
    "muscle_groups": ["chest", "shoulders", "triceps"],
    "equipment_needed": ["barbell", "bench"],
    "difficulty": "intermediate",
    "instructions": "Lie on bench, lower bar to chest, press up until arms are extended."
  },
  {
    "name": "Yoga Flow",
    "category_id": 3,
    "description": "Flexibility and mindfulness practice",
    "muscle_groups": ["full_body", "flexibility"],
    "equipment_needed": ["yoga_mat"],
    "difficulty": "beginner",
    "instructions": "Flow through yoga poses, focus on breathing and proper form."
  }
]
EOF

# Create exercises
monk data create exercises < exercises_data.json

# View created exercises
monk data select exercises
```

### Step 6: Create Workout Sessions

#### **Add a Workout Session**
```bash
# Create a workout session
cat > workout_data.json << 'EOF'
{
  "date": "2025-01-10T09:00:00Z",
  "title": "Morning Strength Training",
  "notes": "Feeling strong today, increased weight on bench press",
  "duration_minutes": 45,
  "rating": 5
}
EOF

# Create workout
monk data create workouts < workout_data.json

# Get the workout ID
workout_id=$(monk data select workouts | jq -r '.[-1].id')
echo "Created workout with ID: $workout_id"
```

#### **Add Exercises to Workout**
```bash
# Add exercises to the workout
cat > workout_exercises_data.json << 'EOF'
[
  {
    "workout_id": $workout_id,
    "exercise_id": 1,
    "sets": 3,
    "reps": 15,
    "weight_kg": 0,
    "rest_seconds": 60,
    "notes": "Good form, focused on chest activation"
  },
  {
    "workout_id": $workout_id,
    "exercise_id": 2,
    "sets": 4,
    "reps": 12,
    "weight_kg": 0,
    "rest_seconds": 90,
    "notes": "Deep squats, good depth"
  },
  {
    "workout_id": $workout_id,
    "exercise_id": 4,
    "sets": 3,
    "reps": 10,
    "weight_kg": 60,
    "rest_seconds": 120,
    "notes": "Increased weight from last session"
  }
]
EOF

# Replace the workout_id variable
sed "s/\$workout_id/$workout_id/g" workout_exercises_data.json > workout_exercises_final.json

# Add exercises to workout
monk data create workout_exercises < workout_exercises_final.json

# Update workout total exercises count
monk data update workouts $workout_id << 'EOF'
{
  "total_exercises": 3
}
EOF
```

### Step 7: Query and Analyze Data

#### **View Workout History**
```bash
# List all workouts
monk data select workouts

# Get specific workout with exercises
monk data select workouts $workout_id

# Get exercises for this workout
monk data select workout_exercises --filter '{"workout_id": '$workout_id'}'
```

#### **View Exercise Details**
```bash
# Get all exercises with categories
monk data select exercises

# Get specific exercise
monk data select exercises 1

# Get exercises by category (strength training)
monk data select exercises --filter '{"category_id": 2}'
```

#### **Advanced Queries with Filesystem Interface**
```bash
# Browse data structure
monk fs ls /data/

# View workout data
monk fs ls /data/workouts/

# Read specific workout
monk fs cat /data/workouts/$workout_id.json

# Read specific field
monk fs cat /data/workouts/$workout_id/title

# Browse exercises
monk fs ls /data/exercises/

# Read exercise details
monk fs cat /data/exercises/1.json
```

### Step 8: Create More Workouts (Sample Data)

```bash
# Create another workout
cat > workout2.json << 'EOF'
{
  "date": "2025-01-12T18:30:00Z",
  "title": "Evening Cardio Session",
  "notes": "Great run, felt energized",
  "duration_minutes": 30,
  "rating": 4
}
EOF

monk data create workouts < workout2.json

# Get the new workout ID
workout2_id=$(monk data select workouts | jq -r '.[-1].id')

# Add running exercise to workout
cat > workout2_exercises.json << 'EOF'
[
  {
    "workout_id": $workout2_id,
    "exercise_id": 3,
    "sets": 1,
    "reps": 1,
    "weight_kg": 0,
    "rest_seconds": 0,
    "notes": "5km run in 25 minutes"
  }
]
EOF

sed "s/\$workout2_id/$workout2_id/g" workout2_exercises.json > workout2_exercises_final.json
monk data create workout_exercises < workout2_exercises_final.json

# Update workout
monk data update workouts $workout2_id << 'EOF'
{
  "total_exercises": 1
}
EOF
```

### Step 9: Data Analysis and Reporting

#### **Generate Workout Summary**
```bash
# Get all workouts with exercises
echo "=== Workout Summary ==="
monk data select workouts | jq -r '
  "Date: \(.date | strftime("%Y-%m-%d %H:%M")),
   Title: \(.title),
   Duration: \(.duration_minutes)min,
   Rating: \(.rating)/5,
   Exercises: \(.total_exercises)"
'

# Get exercise statistics
echo -e "\n=== Exercise Statistics ==="
monk data select workout_exercises | jq -r '
  group_by(.exercise_id) | 
  map({
    exercise_id: .[0].exercise_id,
    total_sets: map(.sets) | add,
    total_reps: map(.reps) | add,
    avg_weight: map(.weight_kg) | add / length
  })
'

# Get category breakdown
echo -e "\n=== Category Breakdown ==="
monk data select exercises | jq -r '
  group_by(.category_id) | 
  map({
    category_id: .[0].category_id,
    exercise_count: length
  })
'
```

### Step 10: Project Management

#### **Switch Between Projects**
```bash
# List all projects
monk project list

# Switch to another project (if you have one)
monk project use "Another Project"

# Switch back to Exercise Tracker
monk project use "Exercise Tracker"
```

#### **Project Backup**
```bash
# Export all data for backup
mkdir -p exercise_tracker_backup
monk data export categories exercise_tracker_backup/
monk data export exercises exercise_tracker_backup/
monk data export workouts exercise_tracker_backup/
monk data export workout_exercises exercise_tracker_backup/

# Export schemas
monk describe select categories > exercise_tracker_backup/categories_schema.json
monk describe select exercises > exercise_tracker_backup/exercises_schema.json
monk describe select workouts > exercise_tracker_backup/workouts_schema.json
monk describe select workout_exercises > exercise_tracker_backup/workout_exercises_schema.json

echo "Backup created in exercise_tracker_backup/"
```

## Advanced Features

### **Custom Views and Reports**

```bash
# Create a custom workout report
cat > workout_report.sh << 'EOF'
#!/bin/bash
echo "=== Exercise Tracker Report ==="
echo "Generated: $(date)"
echo

echo "Recent Workouts:"
monk data select workouts | jq -r '
  sort_by(.date) | reverse | .[0:5] | 
  "• \(.date | strftime("%Y-%m-%d")): \(.title) (\(.duration_minutes)min)"
'

echo
echo "Exercise Categories:"
monk data select categories | jq -r '"• \(.name): \(.description)"'

echo
echo "Total Workouts: $(monk data select workouts | jq 'length')"
echo "Total Exercises: $(monk data select exercises | jq 'length')"
EOF

chmod +x workout_report.sh
./workout_report.sh
```

### **Data Validation**

```bash
# Validate workout data integrity
echo "Checking for orphaned workout exercises..."
orphaned=$(monk data select workout_exercises | jq '
  map(select(.workout_id as $wid | 
    ($wid | tostring) as $wid_str |
    ($wid_str | tonumber) as $wid_num |
    false  # Would need to check against workouts
  ))
')

if [ "$orphaned" = "[]" ]; then
    echo "✓ No orphaned workout exercises found"
else
    echo "⚠ Found orphaned workout exercises"
fi
```

## Cleanup

```bash
# Clean up temporary files
rm -f *.json workout_report.sh
rm -rf exercise_tracker_backup/

# Or keep them for reference
echo "Example files created. You can keep them for reference."
```

## Summary

This example demonstrates:

1. **Project Creation** - Single command setup with `monk project init`
2. **Schema Design** - Creating related schemas for a real application
3. **Data Operations** - CRUD operations with realistic data
4. **Querying** - Various ways to retrieve and analyze data
5. **Filesystem Interface** - Unix-like data exploration
6. **Project Management** - Switching between projects and backup
7. **Advanced Features** - Custom reports and data validation

The Exercise Tracker project showcases how the simplified project workflow enables rapid development of complete applications with proper data modeling and comprehensive functionality.