# Exercise Tracker Setup

Complete example: Set up a fitness tracking system with workouts, exercises, and progress tracking.

## Goal
Create a comprehensive exercise tracking tenant with schemas for workouts, exercises, and user progress.

## Prerequisites
- Monk CLI configured and authenticated
- New tenant created for the fitness tracker

## Step-by-Step Setup

### 1. Create the Tenant
```bash
monk tenant add fitness-tracker "Personal Fitness Tracker"
monk tenant use fitness-tracker
monk auth login fitness-tracker admin
```

### 2. Define Exercise Types Schema
```bash
monk describe create exercise-types << 'EOF'
{
  "name": "exercise-types",
  "description": "Master list of exercise types",
  "fields": {
    "name": {
      "type": "string",
      "required": true,
      "description": "Exercise name (e.g., 'Bench Press', 'Running')"
    },
    "category": {
      "type": "string",
      "required": true,
      "enum": ["strength", "cardio", "flexibility", "sports"],
      "description": "Exercise category"
    },
    "muscle_groups": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Primary muscle groups targeted"
    },
    "equipment": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Required equipment"
    },
    "instructions": {
      "type": "string",
      "description": "How to perform the exercise"
    }
  }
}
EOF
```

### 3. Define Workouts Schema
```bash
monk describe create workouts << 'EOF'
{
  "name": "workouts",
  "description": "Individual workout sessions",
  "fields": {
    "name": {
      "type": "string",
      "required": true,
      "description": "Workout name (e.g., 'Upper Body Day 1')"
    },
    "date": {
      "type": "string",
      "format": "date",
      "required": true,
      "description": "Date of the workout"
    },
    "duration_minutes": {
      "type": "integer",
      "description": "Total workout duration in minutes"
    },
    "notes": {
      "type": "string",
      "description": "Workout notes and observations"
    },
    "exercises": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "exercise_type_id": {"type": "string"},
          "sets": {"type": "integer"},
          "reps": {"type": "integer"},
          "weight_kg": {"type": "number"},
          "rest_seconds": {"type": "integer"},
          "notes": {"type": "string"}
        }
      },
      "description": "Exercises performed in this workout"
    }
  }
}
EOF
```

### 4. Define Progress Tracking Schema
```bash
monk describe create progress << 'EOF'
{
  "name": "progress",
  "description": "Track fitness progress over time",
  "fields": {
    "date": {
      "type": "string",
      "format": "date",
      "required": true
    },
    "weight_kg": {
      "type": "number",
      "description": "Body weight in kilograms"
    },
    "measurements": {
      "type": "object",
      "properties": {
        "chest_cm": {"type": "number"},
        "waist_cm": {"type": "number"},
        "arms_cm": {"type": "number"},
        "thighs_cm": {"type": "number"}
      },
      "description": "Body measurements"
    },
    "notes": {
      "type": "string",
      "description": "Progress notes"
    }
  }
}
EOF
```

### 5. Add Sample Exercise Types
```bash
# Strength exercises
monk data create exercise-types << 'EOF'
[
  {
    "name": "Bench Press",
    "category": "strength",
    "muscle_groups": ["chest", "triceps", "shoulders"],
    "equipment": ["barbell", "bench"],
    "instructions": "Lie on bench, lower bar to chest, press up explosively"
  },
  {
    "name": "Squats",
    "category": "strength",
    "muscle_groups": ["quadriceps", "glutes", "hamstrings"],
    "equipment": ["barbell"],
    "instructions": "Stand with feet shoulder-width, lower until thighs parallel to ground, stand up"
  },
  {
    "name": "Deadlifts",
    "category": "strength",
    "muscle_groups": ["hamstrings", "glutes", "back", "traps"],
    "equipment": ["barbell"],
    "instructions": "Stand over barbell, grip with hands outside legs, lift by extending hips and knees"
  }
]
EOF

# Cardio exercises
monk data create exercise-types << 'EOF'
[
  {
    "name": "Running",
    "category": "cardio",
    "muscle_groups": ["quadriceps", "calves", "hamstrings"],
    "equipment": ["running shoes"],
    "instructions": "Maintain steady pace, focus on form and breathing"
  },
  {
    "name": "Cycling",
    "category": "cardio",
    "muscle_groups": ["quadriceps", "calves", "glutes"],
    "equipment": ["bicycle"],
    "instructions": "Maintain consistent cadence, adjust resistance as needed"
  }
]
EOF
```

### 6. Add Sample Workout
```bash
monk data create workouts << 'EOF'
{
  "name": "Upper Body Strength Day",
  "date": "2024-12-15",
  "duration_minutes": 45,
  "notes": "Felt strong today, good form on all lifts",
  "exercises": [
    {
      "exercise_type_id": "bench-press-1",
      "sets": 4,
      "reps": 8,
      "weight_kg": 80,
      "rest_seconds": 120,
      "notes": "Last set was challenging but completed"
    },
    {
      "exercise_type_id": "overhead-press-1",
      "sets": 3,
      "reps": 10,
      "weight_kg": 50,
      "rest_seconds": 90,
      "notes": "Shoulder felt good"
    },
    {
      "exercise_type_id": "rows-1",
      "sets": 3,
      "reps": 12,
      "weight_kg": 60,
      "rest_seconds": 75,
      "notes": "Focus on back engagement"
    }
  ]
}
EOF
```

### 7. Add Progress Entry
```bash
monk data create progress << 'EOF'
{
  "date": "2024-12-15",
  "weight_kg": 75.5,
  "measurements": {
    "chest_cm": 95,
    "waist_cm": 82,
    "arms_cm": 32,
    "thighs_cm": 58
  },
  "notes": "Starting strength training program. Feeling motivated!"
}
EOF
```

## Verification Commands

### Check Your Schemas
```bash
monk describe select exercise-types
monk describe select workouts
monk describe select progress
```

### View Your Data
```bash
monk data select exercise-types
monk data select workouts
monk data select progress
```

### Query Examples
```bash
# Find all strength exercises
monk data select exercise-types --filter '{"category": "strength"}'

# Get workouts from this week
monk data select workouts --filter '{"date": {"$gte": "2024-12-09"}}'

# Get latest progress entry
monk data select progress --filter '{}' --sort '{"date": -1}' --limit 1
```

## Usage Examples

### Log a New Workout
```bash
monk data create workouts << 'EOF'
{
  "name": "Lower Body Power",
  "date": "2024-12-16",
  "duration_minutes": 50,
  "exercises": [
    {
      "exercise_type_id": "squats-1",
      "sets": 4,
      "reps": 6,
      "weight_kg": 100,
      "rest_seconds": 180
    },
    {
      "exercise_type_id": "deadlifts-1",
      "sets": 3,
      "reps": 8,
      "weight_kg": 120,
      "rest_seconds": 150
    }
  ]
}
EOF
```

### Track Weekly Progress
```bash
monk data create progress << 'EOF'
{
  "date": "2024-12-22",
  "weight_kg": 76.2,
  "measurements": {
    "chest_cm": 96,
    "waist_cm": 81,
    "arms_cm": 33,
    "thighs_cm": 59
  },
  "notes": "Good progress this week. Strength is increasing."
}
EOF
```

### Analyze Your Training
```bash
# Total workouts this month
monk data select workouts --filter '{"date": {"$gte": "2024-12-01"}}' | jq length

# Exercises by muscle group
monk data select exercise-types --filter '{"muscle_groups": {"$in": ["chest"]}}'

# Recent progress trend
monk data select progress --filter '{}' --sort '{"date": -1}' --limit 4
```

## Advanced Features

### Bulk Data Operations
```bash
# Export all workout data
monk data export workouts ./backup/workouts.json

# Import exercise library
monk data import exercise-types ./exercise-library.json
```

### Cross-References
```bash
# Get workout with full exercise details
WORKOUT_ID=$(monk data select workouts | jq -r '.[0].id')
monk data select workouts $WORKOUT_ID

# Link exercises to workouts dynamically
monk data update workouts $WORKOUT_ID << 'EOF'
{
  "exercises": [
    {
      "exercise_type_id": "$(monk data select exercise-types --filter '{"name": "Bench Press"}' | jq -r '.[0].id')",
      "sets": 4,
      "reps": 10,
      "weight_kg": 85
    }
  ]
}
EOF
```

## Next Steps
- Add more exercise types as you discover new movements
- Track nutrition data by creating a `nutrition` schema
- Set up automated progress reports
- Create workout templates for repeated routines

This setup gives you a complete fitness tracking system that grows with your training needs!</content>
<parameter name="filePath">/Users/ianzepp/Workspaces/monk-cli/examples/exercise-tracker.md