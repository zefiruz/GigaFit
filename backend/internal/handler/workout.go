package handler

import (
	"encoding/json"
	"net/http"

	"gigafit/internal/middleware"
	"gigafit/internal/models"
	"gigafit/internal/repository"
	"gigafit/service"

	"github.com/google/uuid"
)

type WorkoutHandler struct {
	WorkoutRepo     repository.WorkoutRepository
	ExersiceRepo    repository.ExerciseRepository
	GigaChatService service.GigaChatService
}

func NewWorkoutHandler(workoutRepo repository.WorkoutRepository, exerciseRepo repository.ExerciseRepository, gigaChatService service.GigaChatService) *WorkoutHandler {
	return &WorkoutHandler{
		WorkoutRepo:     workoutRepo,
		ExersiceRepo:    exerciseRepo,
		GigaChatService: gigaChatService,
	}
}

func (h *WorkoutHandler) CreateManualWorkout(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Title            string `json:"title"`
		Description      string `json:"description"`
		TotalDurationEst int    `json:"total_duration_est"`
		Exercises        []struct {
			ID   uuid.UUID `json:"id"`
			Sets int       `json:"sets"`
			Reps int       `json:"reps"`
		} `json:"exercises"`
	}

	err := json.NewDecoder(r.Body).Decode(&input)
	if err != nil {
		http.Error(w, "Некорректный JSON", http.StatusBadRequest)
		return
	}

	workoutID := uuid.New()

	var workoutExercises []models.WorkoutExercise

	for i, ex := range input.Exercises {
		workoutExercises = append(workoutExercises, models.WorkoutExercise{
			ID:         uuid.New(), // Генерируем ID для самой связи
			WorkoutID:  workoutID,  // Привязываем к нашей новой тренировке
			ExerciseID: ex.ID,      // ID самого упражнения из базы
			OrderIndex: i,          // Опционально: сохраняем порядок (0, 1, 2...)
			Sets:       ex.Sets,    // Используем значения из входных данных
			Reps:       ex.Reps,    // Используем значения из входных данных
		})
	}

	newWorkout := models.Workout{
		ID:               workoutID,
		Title:            input.Title,
		Description:      input.Description,
		IsAIGenerated:    false,
		TotalDurationEst: input.TotalDurationEst,
		IsPublic:         false,
		Exercises:        workoutExercises,
	}

	err = h.WorkoutRepo.CreateWorkout(&newWorkout)
	if err != nil {
		http.Error(w, "Ошибка при сохранении тренировки", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(newWorkout)
}

func (h *WorkoutHandler) CreateAIWorkout(w http.ResponseWriter, r *http.Request) {
	// 1. userID из контекста
	userID, ok := r.Context().Value(middleware.UserIDKey).(uuid.UUID)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// 2. Получаем цель из запроса
	var req struct {
		Goal string `json:"goal"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Goal == "" {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// 3. Получаем доступные упражнения из БД
	exercises, err := h.ExersiceRepo.GetAllExercises(userID)
	if err != nil {
		http.Error(w, "Failed to fetch exercises", http.StatusInternalServerError)
		return
	}

	availableExercises := make(map[uuid.UUID]string)
	for _, ex := range exercises {
		availableExercises[ex.ID] = ex.Name
	}

	// 4. Генерация тренировки через GigaChat
	aiResponse, err := h.GigaChatService.GenerateWorkout(req.Goal, availableExercises)
	if err != nil {
		http.Error(w, "AI generation failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 5. Собираем workout
	workoutID := uuid.New()
	var workoutExercises []models.WorkoutExercise

	for i, ex := range aiResponse.Exercises {
		workoutExercises = append(workoutExercises, models.WorkoutExercise{
			ID:         uuid.New(),
			WorkoutID:  workoutID,
			ExerciseID: ex.ID,
			OrderIndex: i,
			Sets:       ex.Sets,
			Reps:       ex.Reps,
		})
	}

	newWorkout := models.Workout{
		ID:               workoutID,
		AuthorID:         userID,
		Title:            aiResponse.Title,
		Description:      aiResponse.Description,
		IsAIGenerated:    true,
		TotalDurationEst: 45, // можно потом тоже от ИИ считать
		IsPublic:         false,
		Exercises:        workoutExercises,
	}

	// 6. Сохраняем
	if err := h.WorkoutRepo.CreateWorkout(&newWorkout); err != nil {
		http.Error(w, "Save error", http.StatusInternalServerError)
		return
	}

	// 7. Ответ
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(newWorkout)
}
