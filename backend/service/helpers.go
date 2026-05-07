package service

import "github.com/google/uuid"

// AIWorkoutResponse описывает структуру, которую мы ждем от ИИ
type AIWorkoutResponse struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Exercises   []struct {
		ID   uuid.UUID `json:"id"`
		Sets int       `json:"sets"`
		Reps int       `json:"reps"`
	} `json:"exercises"`
}

// AIPlanResponse описывает структуру плана тренировок от ИИ
type AIPlanResponse struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Workouts    []struct {
		DayNumber int    `json:"day_number"` // День недели (например, 1, 3, 5)
		Title     string `json:"title"`      // Название конкретной тренировки (напр., "День ног")
		Exercises []struct {
			ID   uuid.UUID `json:"id"`
			Sets int       `json:"sets"`
			Reps int       `json:"reps"`
		} `json:"exercises"`
	} `json:"workouts"`
}
