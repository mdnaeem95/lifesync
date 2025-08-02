package database

import (
	"database/sql"
	"fmt"
)

func RunFlowTimeMigrations(db *sql.DB) error {
	migrations := []string{
		createTasksTable,
		createEnergyLevelsTable,
		createFocusSessionsTable,
		createUserPreferencesTable,
		createEnergyPatternsTable,
		createFlowTimeIndexes,
	}

	for i, migration := range migrations {
		if _, err := db.Exec(migration); err != nil {
			return fmt.Errorf("failed to run flowtime migration %d: %w", i+1, err)
		}
	}

	return nil
}

const createTasksTable = `
CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    duration INTEGER NOT NULL CHECK (duration >= 5 AND duration <= 480),
    scheduled_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    task_type VARCHAR(20) NOT NULL CHECK (task_type IN ('focus', 'meeting', 'break', 'admin')),
    energy_required INTEGER NOT NULL CHECK (energy_required >= 1 AND energy_required <= 5),
    priority INTEGER NOT NULL DEFAULT 3 CHECK (priority >= 1 AND priority <= 5),
    is_flexible BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
`

const createEnergyLevelsTable = `
CREATE TABLE IF NOT EXISTS energy_levels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    level INTEGER NOT NULL CHECK (level >= 1 AND level <= 100),
    recorded_at TIMESTAMP WITH TIME ZONE NOT NULL,
    factors JSONB,
    source VARCHAR(20) NOT NULL CHECK (source IN ('manual', 'wearable', 'predicted')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
`

const createFocusSessionsTable = `
CREATE TABLE IF NOT EXISTS focus_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id UUID REFERENCES tasks(id) ON DELETE SET NULL,
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ended_at TIMESTAMP WITH TIME ZONE,
    paused_at TIMESTAMP WITH TIME ZONE,
    duration INTEGER DEFAULT 0,
    session_type VARCHAR(20) NOT NULL CHECK (session_type IN ('pomodoro', 'timeboxing', 'deepwork')),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
`

const createUserPreferencesTable = `
CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    work_hours_start VARCHAR(5) DEFAULT '09:00',
    work_hours_end VARCHAR(5) DEFAULT '17:00',
    break_duration INTEGER DEFAULT 15,
    focus_protocol VARCHAR(20) DEFAULT 'pomodoro' CHECK (focus_protocol IN ('pomodoro', 'timeboxing', 'deepwork')),
    energy_update_freq INTEGER DEFAULT 60,
    notifications_on BOOLEAN DEFAULT true,
    smart_scheduling BOOLEAN DEFAULT true,
    preferred_task_time INTEGER DEFAULT 60,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
`

const createEnergyPatternsTable = `
CREATE TABLE IF NOT EXISTS energy_patterns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
    hour_of_day INTEGER NOT NULL CHECK (hour_of_day >= 0 AND hour_of_day <= 23),
    average_energy FLOAT NOT NULL,
    sample_count INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, day_of_week, hour_of_day)
);
`

const createFlowTimeIndexes = `
CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_scheduled_at ON tasks(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_tasks_completed_at ON tasks(completed_at);
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at);

CREATE INDEX IF NOT EXISTS idx_energy_levels_user_id ON energy_levels(user_id);
CREATE INDEX IF NOT EXISTS idx_energy_levels_recorded_at ON energy_levels(recorded_at);

CREATE INDEX IF NOT EXISTS idx_focus_sessions_user_id ON focus_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_focus_sessions_task_id ON focus_sessions(task_id);
CREATE INDEX IF NOT EXISTS idx_focus_sessions_started_at ON focus_sessions(started_at);
CREATE INDEX IF NOT EXISTS idx_focus_sessions_status ON focus_sessions(status);

CREATE INDEX IF NOT EXISTS idx_energy_patterns_user_id ON energy_patterns(user_id);
CREATE INDEX IF NOT EXISTS idx_energy_patterns_lookup ON energy_patterns(user_id, day_of_week, hour_of_day);
`
