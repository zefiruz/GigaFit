package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Вспомогательные структуры для JSONB полей

type UserStats struct {
	LastActivity   time.Time          `json:"last_activity"`
	CompletedTotal int                `json:"completed_total"`
	PersonalBests  map[string]float64 `json:"personal_bests"`
	CurrentStreak  int                `json:"current_streak"`
	AIPrefs        map[string]string  `json:"ai_prefs"`
}

type ExerciseParams struct {
	Weight      float64 `json:"weight"`
	Intensity   int     `json:"intensity"`
	RestSeconds int     `json:"rest_seconds"`
	Tempo       string  `json:"tempo"`
	TargetRPE   int     `json:"target_rpe"`
}

type ExerciseLog struct {
	ExerciseID   uuid.UUID `json:"exercise_id"`
	ActualReps   []int     `json:"actual_reps"`
	ActualWeight []float64 `json:"actual_weight"`
	Notes        string    `json:"notes"`
}

type WorkoutSessionPayload struct {
	Exercises          []ExerciseLog `json:"exercises"`
	ActualDurationMins int           `json:"actual_duration_mins"`
	Mood               string        `json:"mood"`
}

type MuscleData struct {
	Primary   []string `json:"primary"`
	Secondary []string `json:"secondary,omitempty"`
}

type ExerciseInWorkout struct {
	Name   string `json:"name"`
	Sets   int    `json:"sets"`
	Reps   int    `json:"reps"`
	Advice string `json:"advice"`
}

// Основные модели для GORM

type User struct {
	ID            uuid.UUID        `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	Username      string           `gorm:"uniqueIndex;not null" json:"username"`
	Email         string           `gorm:"uniqueIndex;not null" json:"email"`
	PasswordHash  string           `gorm:"not null" json:"-"`
	InitialWeight float64          `json:"initial_weight"`
	InitialHeight float64          `json:"initial_height"`
	CurrentWeight float64          `json:"current_weight"`
	CurrentHeight float64          `json:"current_height"`
	Gender        string           `json:"gender"`
	Goal          string           `json:"goal"`
	CachedStats   JSONB[UserStats] `gorm:"type:jsonb" json:"cached_stats"`
	CreatedAt     time.Time        `json:"created_at"`
	UpdatedAt     time.Time        `json:"updated_at"`
	DeletedAt     gorm.DeletedAt   `gorm:"index" json:"-"`
	AvatarURL     string           `json:"avatar_url"`
}

type MeasurementLog struct {
	ID        uuid.UUID `gorm:"type:uuid;primary_key" json:"id"`
	UserID    uuid.UUID `gorm:"type:uuid;index;not null" json:"user_id"`
	Weight    float64   `json:"weight"`
	Height    float64   `json:"height"`
	CreatedAt time.Time `json:"date"`
}

type Exercise struct {
	ID           uuid.UUID         `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID       *uuid.UUID        `gorm:"type:uuid" json:"user_id"` // NULL для системных
	Name         string            `gorm:"not null" json:"name"`
	Status       string            `gorm:"default:'system'" json:"status"`
	MuscleGroups JSONB[MuscleData] `gorm:"type:jsonb" json:"muscle_groups"`
	Description  string            `json:"description"`
	VideoURL     string            `json:"video_url"`
	DeletedAt    gorm.DeletedAt    `gorm:"index" json:"-"`
	ImageURL     string            `json:"image_url"`
}

type Workout struct {
	ID               uuid.UUID         `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	AuthorID         uuid.UUID         `gorm:"type:uuid;not null" json:"author_id"`
	Title            string            `gorm:"not null" json:"title"`
	Description      string            `json:"description"`
	IsAIGenerated    bool              `gorm:"default:false" json:"is_ai_generated"`
	TotalDurationEst int               `json:"total_duration_est"`
	IsPublic         bool              `gorm:"default:false" json:"is_public"`
	LikesCount       int               `gorm:"default:0" json:"likes_count"`
	Exercises        []WorkoutExercise `gorm:"foreignKey:WorkoutID" json:"exercises"` // Связь один-ко-многим
	DeletedAt        gorm.DeletedAt    `gorm:"index" json:"-"`
	ImageURL         string            `json:"image_url"`
}

// WorkoutExercise — промежуточная таблица с доп. параметрами нагрузки
type WorkoutExercise struct {
	ID         uuid.UUID             `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkoutID  uuid.UUID             `gorm:"type:uuid;index" json:"workout_id"`
	ExerciseID uuid.UUID             `gorm:"type:uuid" json:"exercise_id"`
	Exercise   Exercise              `gorm:"foreignKey:ExerciseID" json:"exercise_info"` // Чтобы подтягивать детали упражнения
	Sets       int                   `json:"sets"`
	Reps       int                   `json:"reps"`
	LoadParams JSONB[ExerciseParams] `gorm:"type:jsonb" json:"load_params"`
	OrderIndex int                   `json:"order_index"`
}

type TrainingPlan struct {
	ID            uuid.UUID      `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	AuthorID      uuid.UUID      `gorm:"type:uuid;not null" json:"author_id"`
	Title         string         `gorm:"not null" json:"title"`
	Description   string         `json:"description"`
	IsPublic      bool           `gorm:"default:false" json:"is_public"`
	DurationWeeks int            `json:"duration_weeks"`
	Workouts      []PlanWorkout  `gorm:"foreignKey:PlanID" json:"workouts"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
}

type PlanWorkout struct {
	ID         uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	PlanID     uuid.UUID `gorm:"type:uuid;index" json:"plan_id"`
	WorkoutID  uuid.UUID `gorm:"type:uuid" json:"workout_id"`
	Workout    Workout   `gorm:"foreignKey:WorkoutID" json:"workout_info"`
	DayOfWeek  int       `json:"day_of_week"`
	OrderIndex int       `json:"order_index"`
}

type WorkoutLog struct {
	ID        uuid.UUID                    `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID    uuid.UUID                    `gorm:"type:uuid;index" json:"user_id"`
	WorkoutID uuid.UUID                    `gorm:"type:uuid" json:"workout_id"`
	Payload   JSONB[WorkoutSessionPayload] `gorm:"type:jsonb" json:"payload"`
	CreatedAt time.Time                    `json:"created_at"`
}

type WorkoutLike struct {
	UserID    uuid.UUID `gorm:"type:uuid;primaryKey" json:"user_id"`
	WorkoutID uuid.UUID `gorm:"type:uuid;primaryKey" json:"workout_id"`
	CreatedAt time.Time `json:"created_at"`
}

type SavedWorkout struct {
	UserID    uuid.UUID `gorm:"type:uuid;primaryKey" json:"user_id"`
	WorkoutID uuid.UUID `gorm:"type:uuid;primaryKey" json:"workout_id"`
	Workout   Workout   `gorm:"foreignKey:WorkoutID" json:"workout_info"`
	CreatedAt time.Time `json:"saved_at"`
}

type AIRequest struct {
	ID        uuid.UUID             `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID    uuid.UUID             `gorm:"type:uuid;index" json:"user_id"`
	Prompt    string                `gorm:"not null" json:"prompt"`
	Response  JSONB[map[string]any] `gorm:"type:jsonb" json:"response"`
	CreatedAt time.Time             `json:"created_at"`
	SessionID uuid.UUID             `gorm:"type:uuid;index" json:"session_id"`
}
