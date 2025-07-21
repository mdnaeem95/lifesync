-- FlowTime specific tables

-- Task types enum
CREATE TYPE task_type AS ENUM ('focus', 'meeting', 'break', 'admin');
CREATE TYPE task_priority AS ENUM ('low', 'medium', 'high', 'urgent');

-- FlowTime tasks
CREATE TABLE flowtime_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    scheduled_at TIMESTAMP WITH TIME ZONE NOT NULL,
    duration INTEGER NOT NULL, -- in minutes
    task_type task_type NOT NULL,
    priority task_priority DEFAULT 'medium',
    energy_required INTEGER CHECK (energy_required BETWEEN 1 AND 5),
    is_completed BOOLEAN DEFAULT false,
    is_flexible BOOLEAN DEFAULT true,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB DEFAULT '{}'
);

-- Energy levels tracking
CREATE TABLE flowtime_energy_levels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    level INTEGER NOT NULL CHECK (level BETWEEN 1 AND 100),
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    factors JSONB DEFAULT '{}', -- sleep, exercise, stress, etc.
    source VARCHAR(50) DEFAULT 'manual' -- manual, wearable, predicted
);

-- Focus sessions
CREATE TABLE flowtime_focus_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id UUID REFERENCES flowtime_tasks(id) ON DELETE SET NULL,
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ended_at TIMESTAMP WITH TIME ZONE,
    planned_duration INTEGER NOT NULL, -- in minutes
    actual_duration INTEGER, -- in minutes
    focus_protocol VARCHAR(50), -- pomodoro, timeboxing, deepwork
    interruptions INTEGER DEFAULT 0,
    energy_level_start INTEGER,
    energy_level_end INTEGER,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- User preferences for FlowTime
CREATE TABLE flowtime_user_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    work_hours_start TIME DEFAULT '09:00',
    work_hours_end TIME DEFAULT '17:00',
    break_duration INTEGER DEFAULT 15, -- in minutes
    focus_duration INTEGER DEFAULT 45, -- in minutes
    notification_settings JSONB DEFAULT '{}',
    chronotype VARCHAR(20), -- morning_lark, night_owl, third_bird
    integrations JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Analytics aggregations (for faster queries)
CREATE TABLE flowtime_daily_stats (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_focus_time INTEGER DEFAULT 0, -- in minutes
    completed_tasks INTEGER DEFAULT 0,
    average_energy_level DECIMAL(3,1),
    flow_score DECIMAL(3,1), -- calculated metric
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, date)
);

-- Indexes for performance
CREATE INDEX idx_flowtime_tasks_user_scheduled ON flowtime_tasks(user_id, scheduled_at);
CREATE INDEX idx_flowtime_tasks_completed ON flowtime_tasks(user_id, is_completed);
CREATE INDEX idx_flowtime_energy_user_time ON flowtime_energy_levels(user_id, recorded_at DESC);
CREATE INDEX idx_flowtime_sessions_user_time ON flowtime_focus_sessions(user_id, started_at DESC);
CREATE INDEX idx_flowtime_daily_stats_user_date ON flowtime_daily_stats(user_id, date DESC);

-- Triggers for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_flowtime_tasks_updated_at BEFORE UPDATE
    ON flowtime_tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_flowtime_user_preferences_updated_at BEFORE UPDATE
    ON flowtime_user_preferences FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();