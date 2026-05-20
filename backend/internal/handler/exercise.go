package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"gigafit/internal/models"
	"gigafit/internal/repository"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

type ExerciseHandler struct {
	Repo repository.ExerciseRepository
	Rdb  *redis.Client
}

func NewExerciseHandler(repo repository.ExerciseRepository, rdb *redis.Client) *ExerciseHandler {
	return &ExerciseHandler{
		Repo: repo,
		Rdb:  rdb,
	}
}

func (h *ExerciseHandler) CreateExercise(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	var input struct {
		Name             string   `json:"name"`
		Description      string   `json:"description"`
		PrimaryMuscles   []string `json:"primary_muscles"`
		SecondaryMuscles []string `json:"secondary_muscles"`
		VideoURL         string   `json:"video_url"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid JSON"})
		return
	}

	if input.Name == "" {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Name is required"})
		return
	}

	exercise := models.Exercise{
		ID:          uuid.New(),
		UserID:      &userID,
		Name:        input.Name,
		IsSystem:    false,
		Description: input.Description,
		MuscleGroups: models.JSONB[models.MuscleData]{
			Data: models.MuscleData{
				Primary:   input.PrimaryMuscles,
				Secondary: input.SecondaryMuscles,
			},
		},
		VideoURL: input.VideoURL,
	}

	if err := h.Repo.CreateExercise(&exercise); err != nil {
		log.Println("CreateExercise error:", err)
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to create exercise"})
		return
	}

	listKey := fmt.Sprintf("exercises:user:%s", userID.String())
	h.Rdb.Del(context.Background(), listKey)

	writeJSON(w, http.StatusCreated, Response{
		Status: "success",
		Data:   exercise,
	})
}

func (h *ExerciseHandler) GetExerciseByID(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid UUID"})
		return
	}

	cacheKey := fmt.Sprintf("exercises:%s", id)

	responseData, err := GetWithCache(r.Context(), h.Rdb, cacheKey, 10*time.Minute, func() (interface{}, error) {
		exercise, dbErr := h.Repo.GetExerciseByID(id, userID)
		if dbErr != nil {
			return nil, dbErr
		}

		if *exercise.UserID != userID {
			return nil, fmt.Errorf("forbidden")
		}
		return exercise, nil
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

func (h *ExerciseHandler) GetAllExercises(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	cacheKey := fmt.Sprintf("exercises:user:%s", userID.String())

	responseData, err := GetWithCache(r.Context(), h.Rdb, cacheKey, 10*time.Minute, func() (interface{}, error) {
		return h.Repo.GetAllExercises(userID)
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to fetch exercises"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(responseData)
}

func (h *ExerciseHandler) UpdateExercise(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid UUID"})
		return
	}

	var input struct {
		Name             string   `json:"name"`
		Description      string   `json:"description"`
		PrimaryMuscles   []string `json:"primary_muscles"`
		SecondaryMuscles []string `json:"secondary_muscles"`
		VideoURL         string   `json:"video_url"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid JSON"})
		return
	}

	exercise, err := h.Repo.GetExerciseByID(id, userID)
	if err != nil {
		writeJSON(w, http.StatusNotFound, Response{Status: "error", Message: "Exercise not found"})
		return
	}

	exercise.Name = input.Name
	exercise.Description = input.Description
	exercise.VideoURL = input.VideoURL
	exercise.MuscleGroups = models.JSONB[models.MuscleData]{
		Data: models.MuscleData{
			Primary:   input.PrimaryMuscles,
			Secondary: input.SecondaryMuscles,
		},
	}

	if err := h.Repo.UpdateExercise(exercise, userID); err != nil {
		log.Println("UpdateExercise error:", err)
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to update exercise"})
		return
	}

	listKey := fmt.Sprintf("exercises:user:%s", userID)
	detailKey := fmt.Sprintf("exercises:user:%s:id:%s", userID, id)

	h.Rdb.Del(context.Background(), listKey, detailKey)

	w.WriteHeader(http.StatusOK)
}

func (h *ExerciseHandler) DeleteExercise(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid UUID"})
		return
	}

	if err := h.Repo.DeleteExercise(id, userID); err != nil {
		writeJSON(w, http.StatusForbidden, Response{Status: "error", Message: err.Error()})
		return
	}

	listKey := fmt.Sprintf("exercises:user:%s", userID)
	detailKey := fmt.Sprintf("exercises:user:%s:id:%s", userID, id)

	h.Rdb.Del(context.Background(), listKey, detailKey)

	w.WriteHeader(http.StatusOK)
}

func (h *ExerciseHandler) GetExercisesByMuscleGroup(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	muscleGroups := r.URL.Query()["muscle_group"]
	if len(muscleGroups) == 0 {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "muscle_group required"})
		return
	}

	muscleStr := strings.Join(muscleGroups, ",")

	cacheKey := fmt.Sprintf("exercises:user:%s:muscle_groups:%s", userID, muscleStr)

	responseData, err := GetWithCache(r.Context(), h.Rdb, cacheKey, 10*time.Minute, func() (interface{}, error) {
		return h.Repo.GetExercisesByMuscleGroup(userID, muscleGroups)
	})
	if err != nil {
		log.Println("GetExercisesByMuscleGroup error:", err)
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Database error"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(responseData)
}
