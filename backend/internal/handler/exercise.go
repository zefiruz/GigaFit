package handler

import (
	"encoding/json"
	"log"
	"net/http"

	"gigafit/internal/models"
	"gigafit/internal/repository"

	"github.com/google/uuid"
)

type ExerciseHandler struct {
	Repo repository.ExerciseRepository
}

func NewExerciseHandler(repo repository.ExerciseRepository) *ExerciseHandler {
	return &ExerciseHandler{Repo: repo}
}

// ====== HANDLERS ======

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
		Status:      "custom",
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

	exercise, err := h.Repo.GetExerciseByID(id, userID)
	if err != nil {
		writeJSON(w, http.StatusNotFound, Response{Status: "error", Message: "Exercise not found"})
		return
	}

	writeJSON(w, http.StatusOK, Response{
		Status: "success",
		Data:   exercise,
	})
}

func (h *ExerciseHandler) GetAllExercises(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	exercises, err := h.Repo.GetAllExercises(userID)
	if err != nil {
		log.Println("GetAllExercises error:", err)
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to fetch exercises"})
		return
	}

	writeJSON(w, http.StatusOK, Response{
		Status: "success",
		Data:   exercises,
	})
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

	writeJSON(w, http.StatusOK, Response{
		Status: "success",
		Data:   exercise,
	})
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

	writeJSON(w, http.StatusOK, Response{
		Status:  "success",
		Message: "Exercise deleted",
	})
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

	exercises, err := h.Repo.GetExercisesByMuscleGroup(userID, muscleGroups)
	if err != nil {
		log.Println("GetExercisesByMuscleGroup error:", err)
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Database error"})
		return
	}

	writeJSON(w, http.StatusOK, Response{
		Status: "success",
		Data:   exercises,
	})
}
