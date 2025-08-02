package models

import (
	"time"
)

// Task represents a user's task
type Task struct {
	ID             string     `json:"id" db:"id"`
	UserID         string     `json:"user_id" db:"user_id"`
	Title          string     `json:"title" db:"title"`
	Description    *string    `json:"description,omitempty" db:"description"`
	Duration       int        `json:"duration" db:"duration"` // in minutes
	ScheduledAt    *time.Time `json:"scheduled_at,omitempty" db:"scheduled_at"`
	CompletedAt    *time.Time `json:"completed_at,omitempty" db:"completed_at"`
	TaskType       string     `json:"task_type" db:"task_type"`             // focus, meeting, break, admin
	EnergyRequired int        `json:"energy_required" db:"energy_required"` // 1-5 scale
	Priority       int        `json:"priority" db:"priority"`               // 1-5 scale
	IsFlexible     bool       `json:"is_flexible" db:"is_flexible"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at" db:"updated_at"`
}

// EnergyLevel represents a user's energy level at a point in time
type EnergyLevel struct {
	ID         string                 `json:"id" db:"id"`
	UserID     string                 `json:"user_id" db:"user_id"`
	Level      int                    `json:"level" db:"level"` // 1-100
	RecordedAt time.Time              `json:"recorded_at" db:"recorded_at"`
	Factors    map[string]interface{} `json:"factors,omitempty" db:"factors"` // JSON field
	Source     string                 `json:"source" db:"source"`             // manual, wearable, predicted
	CreatedAt  time.Time              `json:"created_at" db:"created_at"`
}

// FocusSession represents a work session
type FocusSession struct {
	ID          string     `json:"id" db:"id"`
	UserID      string     `json:"user_id" db:"user_id"`
	TaskID      *string    `json:"task_id,omitempty" db:"task_id"`
	StartedAt   time.Time  `json:"started_at" db:"started_at"`
	EndedAt     *time.Time `json:"ended_at,omitempty" db:"ended_at"`
	PausedAt    *time.Time `json:"paused_at,omitempty" db:"paused_at"`
	Duration    int        `json:"duration" db:"duration"`         // in seconds
	SessionType string     `json:"session_type" db:"session_type"` // pomodoro, timeboxing, deepwork
	Status      string     `json:"status" db:"status"`             // active, paused, completed, cancelled
	CreatedAt   time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at" db:"updated_at"`
}

// UserPreferences represents user's scheduling preferences
type UserPreferences struct {
	ID                string    `json:"id" db:"id"`
	UserID            string    `json:"user_id" db:"user_id"`
	WorkHoursStart    string    `json:"work_hours_start" db:"work_hours_start"`     // "09:00"
	WorkHoursEnd      string    `json:"work_hours_end" db:"work_hours_end"`         // "17:00"
	BreakDuration     int       `json:"break_duration" db:"break_duration"`         // minutes
	FocusProtocol     string    `json:"focus_protocol" db:"focus_protocol"`         // pomodoro, timeboxing, deepwork
	EnergyUpdateFreq  int       `json:"energy_update_freq" db:"energy_update_freq"` // minutes
	NotificationsOn   bool      `json:"notifications_on" db:"notifications_on"`
	SmartScheduling   bool      `json:"smart_scheduling" db:"smart_scheduling"`
	PreferredTaskTime int       `json:"preferred_task_time" db:"preferred_task_time"` // preferred task duration in minutes
	CreatedAt         time.Time `json:"created_at" db:"created_at"`
	UpdatedAt         time.Time `json:"updated_at" db:"updated_at"`
}

// EnergyPattern represents learned energy patterns for a user
type EnergyPattern struct {
	ID            string    `json:"id" db:"id"`
	UserID        string    `json:"user_id" db:"user_id"`
	DayOfWeek     int       `json:"day_of_week" db:"day_of_week"` // 0-6
	HourOfDay     int       `json:"hour_of_day" db:"hour_of_day"` // 0-23
	AverageEnergy float64   `json:"average_energy" db:"average_energy"`
	SampleCount   int       `json:"sample_count" db:"sample_count"`
	CreatedAt     time.Time `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time `json:"updated_at" db:"updated_at"`
}

// Request/Response models

type CreateTaskRequest struct {
	Title          string     `json:"title" validate:"required,min=1,max=200"`
	Description    *string    `json:"description,omitempty" validate:"omitempty,max=1000"`
	Duration       int        `json:"duration" validate:"required,min=5,max=480"` // 5 min to 8 hours
	ScheduledAt    *time.Time `json:"scheduled_at,omitempty"`
	TaskType       string     `json:"task_type" validate:"required,oneof=focus meeting break admin"`
	EnergyRequired int        `json:"energy_required" validate:"required,min=1,max=5"`
	Priority       int        `json:"priority" validate:"required,min=1,max=5"`
	IsFlexible     bool       `json:"is_flexible"`
}

type UpdateTaskRequest struct {
	Title          *string    `json:"title,omitempty" validate:"omitempty,min=1,max=200"`
	Description    *string    `json:"description,omitempty" validate:"omitempty,max=1000"`
	Duration       *int       `json:"duration,omitempty" validate:"omitempty,min=5,max=480"`
	ScheduledAt    *time.Time `json:"scheduled_at,omitempty"`
	TaskType       *string    `json:"task_type,omitempty" validate:"omitempty,oneof=focus meeting break admin"`
	EnergyRequired *int       `json:"energy_required,omitempty" validate:"omitempty,min=1,max=5"`
	Priority       *int       `json:"priority,omitempty" validate:"omitempty,min=1,max=5"`
	IsFlexible     *bool      `json:"is_flexible,omitempty"`
}

type RecordEnergyRequest struct {
	Level   int                    `json:"level" validate:"required,min=1,max=100"`
	Factors map[string]interface{} `json:"factors,omitempty"`
	Source  string                 `json:"source" validate:"required,oneof=manual wearable"`
}

type StartSessionRequest struct {
	TaskID      *string `json:"task_id,omitempty"`
	SessionType string  `json:"session_type" validate:"required,oneof=pomodoro timeboxing deepwork"`
	Duration    int     `json:"duration,omitempty" validate:"omitempty,min=1,max=240"` // minutes
}

type TimeSlotSuggestion struct {
	StartTime     time.Time `json:"start_time"`
	EndTime       time.Time `json:"end_time"`
	EnergyLevel   int       `json:"energy_level"`
	ConflictScore float64   `json:"conflict_score"` // 0-1, lower is better
	Reason        string    `json:"reason"`
}

type ScheduleOptimizationRequest struct {
	Date           time.Time `json:"date" validate:"required"`
	RespectCurrent bool      `json:"respect_current"` // Don't move already scheduled tasks
}

type DailyStats struct {
	Date               time.Time `json:"date"`
	TasksCompleted     int       `json:"tasks_completed"`
	TotalFocusTime     int       `json:"total_focus_time"` // minutes
	AverageEnergyLevel float64   `json:"average_energy_level"`
	ProductivityScore  float64   `json:"productivity_score"`
	MostProductiveHour int       `json:"most_productive_hour"`
	TaskCompletionRate float64   `json:"task_completion_rate"`
}

type UpdatePreferencesRequest struct {
	WorkHoursStart    *string `json:"work_hours_start,omitempty" validate:"omitempty,len=5"`
	WorkHoursEnd      *string `json:"work_hours_end,omitempty" validate:"omitempty,len=5"`
	BreakDuration     *int    `json:"break_duration,omitempty" validate:"omitempty,min=5,max=60"`
	FocusProtocol     *string `json:"focus_protocol,omitempty" validate:"omitempty,oneof=pomodoro timeboxing deepwork"`
	EnergyUpdateFreq  *int    `json:"energy_update_freq,omitempty" validate:"omitempty,min=15,max=120"`
	NotificationsOn   *bool   `json:"notifications_on,omitempty"`
	SmartScheduling   *bool   `json:"smart_scheduling,omitempty"`
	PreferredTaskTime *int    `json:"preferred_task_time,omitempty" validate:"omitempty,min=15,max=180"`
}
