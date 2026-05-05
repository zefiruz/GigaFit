package handler

import (
	"encoding/json"
	"net/http"

	"gigafit/internal/models"
	"gigafit/internal/repository"

	"github.com/google/uuid"
)

type PlanHandler struct {
	Repo repository.TrainingPlanRepository
}

func NewPlanHandler(repo repository.TrainingPlanRepository) *PlanHandler {
	return &PlanHandler{Repo: repo}
}

func (h *PlanHandler) CreatePlan(w http.ResponseWriter, r *http.Request) {
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
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid request body"})
		return
	}

	if input.Title == "" {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Title cannot be empty"})
		return
	}

	plan := models.TrainingPlan{
		AuthorID:      userID,
		Title:         input.Title,
		Description:   input.Description,
		IsPublic:      input.IsPublic,
		DurationWeeks: input.DurationWeeks,
	}

	if err := h.Repo.CreatePlan(&plan); err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to create plan"})
		return
	}

	writeJSON(w, http.StatusCreated, Response{Status: "success", Data: plan})
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