package handler

import (
	"encoding/json"
	"net/http"

	"gigafit/internal/models"
	"gigafit/internal/repository"
	"gigafit/service"

	"github.com/google/uuid"
)

type WorkoutHandler struct {
	WorkoutRepo  repository.WorkoutRepository
	ExersiceRepo repository.ExerciseRepository
	AiService    service.GigaChatService
}

func NewWorkoutHandler(workoutRepo repository.WorkoutRepository, exerciseRepo repository.ExerciseRepository, aiService service.GigaChatService) *WorkoutHandler {
	return &WorkoutHandler{
		WorkoutRepo:  workoutRepo,
		ExersiceRepo: exerciseRepo,
		AiService:    aiService,
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
		IsSystem:         false,
		TotalDurationEst: input.TotalDurationEst,
		IsPublic:         false,
		Exercises:        workoutExercises,
	}

	err = h.WorkoutRepo.CreateWorkout(&newWorkout)
	if err != nil {
		http.Error(w, "Ошибка при сохранении тренировки", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusCreated, Response{Status: "success", Data: newWorkout})
}

func (h *WorkoutHandler) CreateAIWorkout(w http.ResponseWriter, r *http.Request) {
	// 1. userID из контекста
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
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
		http.Error(w, "Failed to fetch exercises: "+err.Error(), http.StatusInternalServerError)
		return
	}

	availableExercises := make(map[uuid.UUID]string)
	for _, ex := range exercises {
		availableExercises[ex.ID] = ex.Name
	}

	// 4. Генерация тренировки через GigaChat
	aiResponse, err := h.AiService.GenerateWorkout(req.Goal, availableExercises)
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
		UserID:           userID,
		Title:            aiResponse.Title,
		Description:      aiResponse.Description,
		IsSystem:         false,
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

	fullWorkout, err := h.WorkoutRepo.GetWorkoutByID(workoutID)
	if err != nil {
		fullWorkout = &newWorkout
	}

	writeJSON(w, http.StatusCreated, Response{Status: "success", Data: fullWorkout})
}

// ================= GET WORKOUT BY ID =================
func (h *WorkoutHandler) GetWorkoutByID(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	idStr := r.PathValue("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		http.Error(w, "Invalid workout ID", http.StatusBadRequest)
		return
	}

	workout, err := h.WorkoutRepo.GetWorkoutByID(id)
	if err != nil {
		http.Error(w, "Workout not found", http.StatusNotFound)
		return
	}

	if workout.UserID != userID && !workout.IsPublic {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}

	writeJSON(w, http.StatusCreated, Response{Status: "success", Data: workout})
}

func (h *WorkoutHandler) GetSystemWorkouts(w http.ResponseWriter, r *http.Request) {
	workouts, err := h.WorkoutRepo.GetAllSystemWorkouts()
	if err != nil {
		http.Error(w, "Workout not found", http.StatusNotFound)
		return
	}

	writeJSON(w, http.StatusOK, Response{Status: "success", Data: workouts})
}

// ================= GET ALL WORKOUTS =================
func (h *WorkoutHandler) GetAllWorkouts(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	workouts, err := h.WorkoutRepo.GetAllWorkouts(userID)
	if err != nil {
		http.Error(w, "Failed to fetch workouts", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, Response{Status: "success", Data: workouts})
}

// ================= UPDATE WORKOUT =================

func (h *WorkoutHandler) UpdateWorkoutMeta(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	id, _ := uuid.Parse(r.PathValue("id"))

	var input struct {
		Title            *string `json:"title"`
		Description      *string `json:"description"`
		TotalDurationEst *int    `json:"total_duration_est"`
		IsPublic         *bool   `json:"is_public"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	updates := map[string]interface{}{}

	if input.Title != nil {
		updates["title"] = *input.Title
	}
	if input.Description != nil {
		updates["description"] = *input.Description
	}
	if input.TotalDurationEst != nil {
		updates["total_duration_est"] = *input.TotalDurationEst
	}
	if input.IsPublic != nil {
		updates["is_public"] = *input.IsPublic
	}

	if len(updates) == 0 {
		http.Error(w, "No fields to update", http.StatusBadRequest)
		return
	}

	if err := h.WorkoutRepo.UpdateWorkoutMeta(id, userID, updates); err != nil {
		http.Error(w, "Update failed", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *WorkoutHandler) UpdateWorkoutExercises(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	workoutID, _ := uuid.Parse(r.PathValue("id"))

	var input struct {
		Exercises []struct {
			ExerciseID uuid.UUID `json:"exercise_id"`
			Sets       int       `json:"sets"`
			Reps       int       `json:"reps"`
		} `json:"exercises"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	var exercises []models.WorkoutExercise

	for _, ex := range input.Exercises {
		if ex.ExerciseID == uuid.Nil {
			http.Error(w, "Invalid exercise_id", http.StatusBadRequest)
			return
		}

		exercises = append(exercises, models.WorkoutExercise{
			ExerciseID: ex.ExerciseID,
			Sets:       ex.Sets,
			Reps:       ex.Reps,
		})
	}

	if err := h.WorkoutRepo.ReplaceWorkoutExercises(workoutID, userID, exercises); err != nil {
		http.Error(w, "Update failed", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// ================= DELETE WORKOUT =================
func (h *WorkoutHandler) DeleteWorkout(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	// 2. Достаем ID тренировки из URL
	workoutID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid workout ID"})
		return
	}

	// 3. ПРОВЕРЯЕМ ПАРАМЕТР ?hard=true ИЗ URL
	isHardDelete := r.URL.Query().Get("hard") == "true"

	// 4. Вызываем нужный метод репозитория
	if isHardDelete {
		if err := h.WorkoutRepo.HardDeleteWorkout(workoutID, userID); err != nil {
			writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to hard delete workout"})
			return
		}
	} else {
		if err := h.WorkoutRepo.DeleteWorkout(workoutID, userID); err != nil {
			writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to delete workout"})
			return
		}
	}

	writeJSON(w, http.StatusOK, Response{Status: "success", Message: "Workout deleted successfully"})
}
