package handler

import (
	"encoding/json"
	"net/http"

	"gigafit/internal/models"
	"gigafit/internal/repository"
	"gigafit/service"

	"github.com/google/uuid"
)

type PlanHandler struct {
	Repo      repository.TrainingPlanRepository
	AiService service.GigaChatService
	ExerciseRepo repository.ExerciseRepository
}

func NewPlanHandler(repo repository.TrainingPlanRepository, aiService service.GigaChatService, exerciseRepo repository.ExerciseRepository) *PlanHandler {
	return &PlanHandler{
		Repo: repo, 
		AiService: aiService, 
		ExerciseRepo: exerciseRepo,
	}
}

func (h *PlanHandler) CreateManualPlan(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	var input struct {
		Title         string `json:"title"`
		Description   string `json:"description"`
		IsPublic      bool   `json:"is_public"`
		DurationWeeks int    `json:"duration_weeks"`
		Workouts      []struct {
			WorkoutID  uuid.UUID `json:"workout_id"`
			DayNumber  int       `json:"day_number"`
			WeekNumber int       `json:"week_number"`
		} `json:"workouts"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid request body"})
		return
	}

	if input.Title == "" {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Title cannot be empty"})
		return
	}

	planID := uuid.New()
	var planWorkouts []models.PlanWorkout

	for _, wInput := range input.Workouts {
		planWorkouts = append(planWorkouts, models.PlanWorkout{
			ID:         uuid.New(),
			PlanID:     planID,
			WorkoutID:  wInput.WorkoutID,
			DayNumber:  wInput.DayNumber,
			WeekNumber: wInput.WeekNumber,
		})
	}

	plan := models.TrainingPlan{
		ID:            planID,
		UserID:      userID,
		Title:         input.Title,
		Description:   input.Description,
		IsPublic:      input.IsPublic,
		DurationWeeks: input.DurationWeeks,
		Workouts:      planWorkouts,
	}

	if err := h.Repo.CreatePlan(&plan); err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to create manual plan"})
		return
	}

	writeJSON(w, http.StatusCreated, Response{Status: "success", Data: plan})
}

func (h *PlanHandler) CreateAIPlan(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	var input struct {
		Goal          string `json:"goal"`
		DaysPerWeek   int    `json:"days_per_week"`
		DurationWeeks int    `json:"duration_weeks"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil || input.Goal == "" {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid request body"})
		return
	}

	exercises, _ := h.ExerciseRepo.GetAllExercises(userID)
	availableExercises := make(map[uuid.UUID]string)
	for _, ex := range exercises {
		availableExercises[ex.ID] = ex.Name
	}

	// 2. Просим ИИ сгенерировать план (название, описание и массив тренировок)
	aiPlanResponse, err := h.AiService.GeneratePlan(input.Goal, input.DaysPerWeek, availableExercises) // Передай доступные упражнения вместо nil
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "AI failed to generate plan"})
		return
	}

	// 3. Сохраняем сгенерированный план
	planID := uuid.New()
	var planWorkouts []models.PlanWorkout

	// ИИ вернул нам структуру плана, внутри которой массив тренировок
	for _, aiWorkout := range aiPlanResponse.Workouts {

		// Создаем саму тренировку (Workout) в базе
		workoutID := uuid.New()

		// ... здесь логика парсинга упражнений для тренировки (аналогично CreateAIWorkout) ...
		// В рамках MVP можно сохранять тренировки прямо через твой WorkoutRepo!

		// Привязываем созданную тренировку к нашему плану
		planWorkouts = append(planWorkouts, models.PlanWorkout{
			ID:         uuid.New(),
			PlanID:     planID,
			WorkoutID:  workoutID,
			DayNumber:  aiWorkout.DayNumber,
			WeekNumber: 1, // Для простоты MVP генерируем 1 неделю и повторяем её
		})
	}

	newPlan := models.TrainingPlan{
		ID:            planID,
		UserID:      userID,
		Title:         aiPlanResponse.Title,
		Description:   aiPlanResponse.Description,
		IsPublic:      false, // Сгенерированное ИИ по умолчанию приватно
		DurationWeeks: input.DurationWeeks,
		Workouts:      planWorkouts,
	}

	if err := h.Repo.CreatePlan(&newPlan); err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to save AI plan"})
		return
	}

	writeJSON(w, http.StatusCreated, Response{Status: "success", Data: newPlan})
}

func (h *PlanHandler) GetAllPlans(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	plans, err := h.Repo.GetAllTrainingPlans(userID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to get plans"})
		return
	}

	writeJSON(w, http.StatusOK, Response{Status: "success", Data: plans})
}

func (h *PlanHandler) GetPlanByID(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	planID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid plan ID"})
		return
	}

	plan, err := h.Repo.GetTrainingPlanByID(planID, userID)
	if err != nil {
		writeJSON(w, http.StatusNotFound, Response{Status: "error", Message: "Plan not found or access denied"})
		return
	}

	writeJSON(w, http.StatusOK, Response{Status: "success", Data: plan})
}

func (h *PlanHandler) UpdatePlan(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	planID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid plan ID"})
		return
	}

	// Декодируем прямо в map, чтобы обновить только переданные поля
	var updates map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&updates); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid JSON format"})
		return
	}

	delete(updates, "id")
	delete(updates, "author_id")
	delete(updates, "created_at")

	if len(updates) == 0 {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "No valid fields to update"})
		return
	}

	if err := h.Repo.UpdateTrainingPlan(planID, userID, updates); err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to update plan"})
		return
	}

	writeJSON(w, http.StatusOK, Response{Status: "success", Message: "Plan updated successfully"})
}

func (h *PlanHandler) DeletePlan(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	planID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid plan ID"})
		return
	}

	if err := h.Repo.DeleteTrainingPlan(planID, userID); err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to delete plan"})
		return
	}

	writeJSON(w, http.StatusOK, Response{Status: "success", Message: "Plan deleted successfully"})
}
