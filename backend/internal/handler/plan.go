package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"gigafit/internal/models"
	"gigafit/internal/repository"
	"gigafit/service"

	"github.com/google/uuid"
)

type PlanHandler struct {
	Repo         repository.TrainingPlanRepository
	AiService    service.GigaChatService
	ExerciseRepo repository.ExerciseRepository
	WorkoutRepo  repository.WorkoutRepository
}

func NewPlanHandler(
	repo repository.TrainingPlanRepository,
	aiService service.GigaChatService,
	exerciseRepo repository.ExerciseRepository,
	workoutRepo repository.WorkoutRepository,
) *PlanHandler {
	return &PlanHandler{
		Repo:         repo,
		AiService:    aiService,
		ExerciseRepo: exerciseRepo,
		WorkoutRepo:  workoutRepo,
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
		UserID:        userID,
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

	// 1. Достаем доступные упражнения
	exercises, err := h.ExerciseRepo.GetAllExercises(userID)
	if err != nil || len(exercises) == 0 {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "База упражнений пуста"})
		return
	}
	availableExercises := make(map[uuid.UUID]string)
	for _, ex := range exercises {
		availableExercises[ex.ID] = ex.Name
	}

	// 2. ШАГ ОРКЕСТРАЦИИ: Просим ИИ разбить цель на дни
	blueprint, err := h.AiService.GeneratePlanOrchestrator(input.Goal, input.DaysPerWeek)
	if err != nil {
		fmt.Println("Ошибка Оркестратора:", err)
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "AI failed to orchestrate plan"})
		return
	}

	// 3. Подготавливаемся к сохранению
	planID := uuid.New()
	var planWorkouts []models.PlanWorkout

	// 4. ЦИКЛ ГЕНЕРАЦИИ: Проходимся по каждому придуманному дню
	for i, dailyGoal := range blueprint.DailyGoals {
		dayNumber := i + 1

		var aiWorkout *service.AIWorkoutResponse
		var err error

		for attempt := 1; attempt <= 2; attempt++ {
			aiWorkout, err = h.AiService.GenerateWorkout(fmt.Sprintf("Цель: %s. Фокус: %s", input.Goal, dailyGoal), availableExercises)
			if err == nil {
				break
			}
			fmt.Printf("Попытка %d для дня %d провалилась: %v. Пробуем еще раз...\n", attempt, dayNumber, err)
			time.Sleep(1 * time.Second)
		}

		if err != nil {
			fmt.Printf("Критическая ошибка генерации дня %d, пропускаем...\n", dayNumber)
			continue
		}

		workoutID := uuid.New()
		var workoutExercises []models.WorkoutExercise

		// 4.2. Собираем упражнения
		for j, ex := range aiWorkout.Exercises {
			workoutExercises = append(workoutExercises, models.WorkoutExercise{
				ID:         uuid.New(),
				WorkoutID:  workoutID,
				ExerciseID: ex.ID,
				OrderIndex: j,
				Sets:       ex.Sets,
				Reps:       ex.Reps,
			})
		}

		// 4.3. Формируем модель тренировки
		newWorkout := models.Workout{
			ID:               workoutID,
			UserID:           userID,
			Title:            aiWorkout.Title,
			Description:      fmt.Sprintf("Часть плана '%s'. Фокус: %s", input.Goal, dailyGoal),
			IsAIGenerated:    true,
			TotalDurationEst: 45,
			IsPublic:         false,
			Exercises:        workoutExercises,
		}

		// 4.4. Сохраняем тренировку
		if err := h.WorkoutRepo.CreateWorkout(&newWorkout); err != nil {
			continue // Пропускаем при ошибке БД
		}

		// 4.5. Привязываем к плану
		planWorkouts = append(planWorkouts, models.PlanWorkout{
			ID:         uuid.New(),
			PlanID:     planID,
			WorkoutID:  workoutID,
			DayNumber:  dayNumber,
			WeekNumber: 1,
		})
	}

	if len(planWorkouts) == 0 {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Не удалось сгенерировать ни одной тренировки"})
		return
	}

	// 5. Формируем и сохраняем финальный План
	newPlan := models.TrainingPlan{
		ID:            planID,
		UserID:        userID,
		Title:         blueprint.Title,      
		Description:   blueprint.Description,
		IsPublic:      false,
		DurationWeeks: input.DurationWeeks,
		Workouts:      planWorkouts,
	}

	if err := h.Repo.CreatePlan(&newPlan); err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to save plan"})
		return
	}

	// 6. Достаем полный план из базы со всеми Preload-вложениями (как мы чинили раньше!)
	fullPlan, err := h.Repo.GetTrainingPlanByID(planID, userID)
	if err != nil {
		writeJSON(w, http.StatusCreated, Response{Status: "success", Data: newPlan})
		return
	}

	writeJSON(w, http.StatusCreated, Response{Status: "success", Data: fullPlan})
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
