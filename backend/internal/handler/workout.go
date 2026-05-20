package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"gigafit/internal/models"
	"gigafit/internal/repository"
	"gigafit/service"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

type WorkoutHandler struct {
	WorkoutRepo  repository.WorkoutRepository
	ExersiceRepo repository.ExerciseRepository
	AiService    service.GigaChatService
	Rdb          *redis.Client
}

func NewWorkoutHandler(workoutRepo repository.WorkoutRepository, exerciseRepo repository.ExerciseRepository, aiService service.GigaChatService, rdb *redis.Client) *WorkoutHandler {
	return &WorkoutHandler{
		WorkoutRepo:  workoutRepo,
		ExersiceRepo: exerciseRepo,
		AiService:    aiService,
		Rdb:          rdb,
	}
}

// ================= CREATE WORKOUTS =================

func (h *WorkoutHandler) CreateManualWorkout(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	var input struct {
		Title            string `json:"title"`
		Description      string `json:"description"`
		TotalDurationEst int    `json:"total_duration_est"`
		Exercises        []struct {
			ExerciseID uuid.UUID `json:"exercise_id"` 
			Sets       int       `json:"sets"`
			Reps       int       `json:"reps"`
		} `json:"exercises"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		http.Error(w, "Некорректный JSON", http.StatusBadRequest)
		return
	}

	previewID := uuid.New()
	var workoutExercises []models.WorkoutExercise

	for i, ex := range input.Exercises {
		workoutExercises = append(workoutExercises, models.WorkoutExercise{
			ID:         uuid.New(),
			WorkoutID:  previewID,
			ExerciseID: ex.ExerciseID,
			OrderIndex: i,
			Sets:       ex.Sets,
			Reps:       ex.Reps,
		})
	}

	newWorkout := models.Workout{
		ID:               previewID,
		Title:            input.Title,
		Description:      input.Description,
		IsAIGenerated:    false,
		IsSystem:         false,
		TotalDurationEst: input.TotalDurationEst,
		IsPublic:         false,
		Exercises:        workoutExercises,
	}

	workoutJSON, _ := json.Marshal(newWorkout)
	draftKey := fmt.Sprintf("draft:workout:user:%s:preview:%s", userID.String(), previewID.String())

	h.Rdb.Set(context.Background(), draftKey, workoutJSON, 30*time.Minute)

	writeJSON(w, http.StatusCreated, Response{
		Status: "success",
		Data: map[string]interface{}{
			"preview_id": previewID,
			"workout":    newWorkout,
		},
	})
}

func (h *WorkoutHandler) CreateAIWorkout(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	var req struct {
		Goal string `json:"goal"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Goal == "" {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	exercises, err := h.ExersiceRepo.GetAllExercises(userID)
	if err != nil {
		http.Error(w, "Failed to fetch exercises: "+err.Error(), http.StatusInternalServerError)
		return
	}

	availableExercises := make(map[uuid.UUID]string)
	for _, ex := range exercises {
		availableExercises[ex.ID] = ex.Name
	}

	aiResponse, err := h.AiService.GenerateWorkout(req.Goal, availableExercises)
	if err != nil {
		http.Error(w, "AI generation failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	previewID := uuid.New()
	var workoutExercises []models.WorkoutExercise

	for i, ex := range aiResponse.Exercises {
		workoutExercises = append(workoutExercises, models.WorkoutExercise{
			ID:         uuid.New(),
			WorkoutID:  previewID,
			ExerciseID: ex.ID,
			OrderIndex: i,
			Sets:       ex.Sets,
			Reps:       ex.Reps,
		})
	}

	newWorkout := models.Workout{
		ID:               previewID,
		UserID:           userID,
		Title:            aiResponse.Title,
		Description:      aiResponse.Description,
		IsSystem:         false,
		IsAIGenerated:    true,
		TotalDurationEst: 45,
		IsPublic:         false,
		Exercises:        workoutExercises,
	}

	workoutJSON, _ := json.Marshal(newWorkout)
	draftKey := fmt.Sprintf("draft:workout:user:%s:preview:%s", userID.String(), previewID.String())

	h.Rdb.Set(context.Background(), draftKey, workoutJSON, 30*time.Minute)

	writeJSON(w, http.StatusCreated, Response{
		Status: "success",
		Data: map[string]interface{}{
			"preview_id": previewID,
			"workout":    newWorkout,
		},
	})
}

func (h *WorkoutHandler) ConfirmWorkout(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	var input struct {
		PreviewID string `json:"preview_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil || input.PreviewID == "" {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	draftKey := fmt.Sprintf("draft:workout:user:%s:preview:%s", userID.String(), input.PreviewID)

	draftData, err := h.Rdb.Get(r.Context(), draftKey).Result()
	if err != nil {
		writeJSON(w, http.StatusNotFound, Response{Status: "error", Message: "Draft expired or not found"})
		return
	}

	var workout models.Workout
	if err := json.Unmarshal([]byte(draftData), &workout); err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to parse draft"})
		return
	}

	workout.UserID = userID

	if err := h.WorkoutRepo.CreateWorkout(&workout); err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to save workout to DB"})
		return
	}

	listKey := fmt.Sprintf("workouts:user:%s", userID.String())

	h.Rdb.Del(context.Background(), draftKey, listKey)

	writeJSON(w, http.StatusCreated, Response{Status: "success", Message: "Workout saved permanently", Data: workout})
}

// ================= GET WORKOUTS (WITH CACHE) =================

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

	cacheKey := fmt.Sprintf("workouts:user:%s:id:%s", userID.String(), idStr)

	responseData, err := GetWithCache(r.Context(), h.Rdb, cacheKey, 10*time.Minute, func() (interface{}, error) {
		workout, dbErr := h.WorkoutRepo.GetWorkoutByID(id)
		if dbErr != nil {
			return nil, dbErr
		}

		if workout.UserID != userID && !workout.IsPublic {
			return nil, fmt.Errorf("forbidden")
		}
		return workout, nil
	})
	if err != nil {
		if err.Error() == "forbidden" {
			http.Error(w, "Forbidden", http.StatusForbidden)
			return
		}
		http.Error(w, "Workout not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(responseData)
}

func (h *WorkoutHandler) GetSystemWorkouts(w http.ResponseWriter, r *http.Request) {
	cacheKey := "workouts:system:all"

	responseData, err := GetWithCache(r.Context(), h.Rdb, cacheKey, 24*time.Hour, func() (interface{}, error) {
		return h.WorkoutRepo.GetAllSystemWorkouts()
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to fetch system workouts"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(responseData)
}

func (h *WorkoutHandler) GetAllWorkouts(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	cacheKey := fmt.Sprintf("workouts:user:%s", userID.String())

	responseData, err := GetWithCache(r.Context(), h.Rdb, cacheKey, 10*time.Minute, func() (interface{}, error) {
		return h.WorkoutRepo.GetAllWorkouts(userID)
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to fetch workouts"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(responseData)
}

// ================= UPDATE WORKOUT =================

func (h *WorkoutHandler) UpdateWorkoutMeta(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		http.Error(w, "Invalid ID", http.StatusBadRequest)
		return
	}

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

	listKey := fmt.Sprintf("workouts:user:%s", userID.String())
	detailKey := fmt.Sprintf("workouts:user:%s:id:%s", userID.String(), id.String())

	h.Rdb.Del(context.Background(), listKey, detailKey)

	w.WriteHeader(http.StatusOK)
}

func (h *WorkoutHandler) UpdateWorkoutExercises(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	workoutID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		http.Error(w, "Invalid ID", http.StatusBadRequest)
		return
	}

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

	listKey := fmt.Sprintf("workouts:user:%s", userID.String())
	detailKey := fmt.Sprintf("workouts:user:%s:id:%s", userID.String(), workoutID.String())

	h.Rdb.Del(context.Background(), listKey, detailKey)

	w.WriteHeader(http.StatusNoContent)
}

// ================= DELETE WORKOUT =================

func (h *WorkoutHandler) DeleteWorkout(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	workoutID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid workout ID"})
		return
	}

	isHardDelete := r.URL.Query().Get("hard") == "true"

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

	listKey := fmt.Sprintf("workouts:user:%s", userID.String())
	detailKey := fmt.Sprintf("workouts:user:%s:id:%s", userID.String(), workoutID.String())

	h.Rdb.Del(context.Background(), listKey, detailKey)

	writeJSON(w, http.StatusOK, Response{Status: "success", Message: "Workout deleted successfully"})
}
