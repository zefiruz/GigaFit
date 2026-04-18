package models

import (
	"time"

	"github.com/google/uuid"
)

// Для User.CachedStats
type UserStats struct {
	LastActivity   time.Time `json:"last_activity"`
	CompletedTotal int       `json:"completed_total"`
	// Личные рекорды: "название_упражнения" -> вес
	// Например: {"bench_press": 100.0, "deadlift": 150.0}
	PersonalBests map[string]float64 `json:"personal_bests"`
	CurrentStreak int                `json:"current_streak"` // Дней подряд
	AIPrefs       map[string]string  `json:"ai_prefs"`
}

// Для WorkoutExercise.LoadParams
type ExerciseParams struct {
	Weight      float64 `json:"weight"`
	Intensity   int     `json:"intensity"` // % от максимума
	RestSeconds int     `json:"rest_seconds"`
	Tempo       string  `json:"tempo"`      // например, "3010" (фазы движения)
	TargetRPE   int     `json:"target_rpe"` // Желаемая интенсивность по 10-балльной шкале
}

type ExerciseLog struct {
	ExerciseID   uuid.UUID `json:"exercise_id"`
	ActualReps   []int     `json:"actual_reps"`   // [10, 10, 8] - по подходам
	ActualWeight []float64 `json:"actual_weight"` // [60, 60, 55]
	Notes        string    `json:"notes"`
}

// Payload для всей тренировки (WorkoutLog.Payload)
type WorkoutSessionPayload struct {
	Exercises          []ExerciseLog `json:"exercises"`
	ActualDurationMins int           `json:"actual_duration_mins"`
	Mood               string        `json:"mood"` // например: "энергично", "устал"
}

type MuscleData struct {
	Primary   []string `json:"primary"`
	Secondary []string `json:"secondary"`
}

type ExerciseInWorkout struct {
	Name   string `json:"name"`
	Sets   int    `json:"sets"`
	Reps   int    `json:"reps"`
	Advice string `json:"advice"`
}

// User represents the users table.
type User struct {
	ID            uuid.UUID        `json:"id" db:"id"`
	Username      string           `json:"username" db:"username"`
	Email         string           `json:"email" db:"email"`
	PasswordHash  string           `json:"password_hash" db:"password_hash"`
	CurrentWeight float64          `json:"current_weight" db:"current_weight"`
	Height        float64          `json:"height" db:"height"`
	Goal          string           `json:"goal" db:"goal"`
	CachedStats   JSONB[UserStats] `json:"cached_stats" db:"cached_stats"` // jsonb
}

// Exercise represents the exercises table.
type Exercise struct {
	ID           uuid.UUID         `json:"id" db:"id"`
	AuthorID     *uuid.UUID        `json:"author_id,omitempty" db:"author_id"` // nullable: NULL for system
	Name         string            `json:"name" db:"name"`
	Status       string            `json:"status" db:"status"`               // "system" | "custom"
	MuscleGroups JSONB[MuscleData] `json:"muscle_groups" db:"muscle_groups"` // jsonb array like ["Legs","Back"]
	Description  string            `json:"description" db:"description"`
	VideoURL     string            `json:"video_url" db:"video_url"`
}

// Workout represents the workouts table.
type Workout struct {
	ID               uuid.UUID `json:"id" db:"id"`
	AuthorID         uuid.UUID `json:"author_id" db:"author_id"`
	Title            string    `json:"title" db:"title"`
	IsAIGenerated    bool      `json:"is_ai_generated" db:"is_ai_generated"`
	TotalDurationEst int       `json:"total_duration_est" db:"total_duration_est"`
	IsPublic         bool      `json:"is_public" db:"is_public"`
}

// WorkoutExercise links exercises to workouts with parameters.
type WorkoutExercise struct {
	ID         uuid.UUID             `json:"id" db:"id"`
	WorkoutID  uuid.UUID             `json:"workout_id" db:"workout_id"`
	ExerciseID uuid.UUID             `json:"exercise_id" db:"exercise_id"`
	Sets       int                   `json:"sets" db:"sets"`
	Reps       int                   `json:"reps" db:"reps"`
	LoadParams JSONB[ExerciseParams] `json:"load_params" db:"load_params"` // jsonb
	OrderIndex int                   `json:"order_index" db:"order_index"`
}

// TrainingPlan represents training plans.
type TrainingPlan struct {
	ID            uuid.UUID `json:"id" db:"id"`
	AuthorID      uuid.UUID `json:"author_id" db:"author_id"`
	Title         string    `json:"title" db:"title"`
	Description   string    `json:"description" db:"description"`
	IsPublic      bool      `json:"is_public" db:"is_public"`
	DurationWeeks int       `json:"duration_weeks" db:"duration_weeks"`
}

// PlanWorkout links plans to workouts on specific days.
type PlanWorkout struct {
	ID         uuid.UUID `json:"id" db:"id"`
	PlanID     uuid.UUID `json:"plan_id" db:"plan_id"`
	WorkoutID  uuid.UUID `json:"workout_id" db:"workout_id"`
	DayOfWeek  int       `json:"day_of_week" db:"day_of_week"` // 1-7
	OrderIndex int       `json:"order_index" db:"order_index"`
}

// WorkoutLog stores completed workout instances.
type WorkoutLog struct {
	ID        uuid.UUID                    `json:"id" db:"id"`
	UserID    uuid.UUID                    `json:"user_id" db:"user_id"`
	WorkoutID uuid.UUID                    `json:"workout_id" db:"workout_id"`
	Payload   JSONB[WorkoutSessionPayload] `json:"payload" db:"payload"` // jsonb
	CreatedAt time.Time                    `json:"created_at" db:"created_at"`
}

// AIGeneratedWorkout stores requests sent to the AI subsystem.
type AIGeneratedWorkout struct {
	PlanTitle   string                     `json:"plan_title"`
	Description string                     `json:"description"`
	Exercises   JSONB[[]ExerciseInWorkout] `json:"exercises"` // jsonb array of exercises with sets/reps/advice
}

type AIRequest struct {
	ID        uuid.UUID             `json:"id" db:"id"`
	UserID    uuid.UUID             `json:"user_id" db:"user_id"`
	Prompt    string                `json:"prompt" db:"prompt"`
	Response  JSONB[map[string]any] `json:"response" db:"response"`
	CreatedAt time.Time             `json:"created_at" db:"created_at"`
}
