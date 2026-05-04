package handler

import (
	"encoding/json"
	"net/http"
	"strings"

	"gigafit/internal/repository"
)

type ProfileHandler struct {
	Repo repository.ProfileRepository
}

func NewProfileHandler(repo repository.ProfileRepository) *ProfileHandler {
	return &ProfileHandler{Repo: repo}
}

func (h *ProfileHandler) GetProfile(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	profile, err := h.Repo.GetProfileByID(userID)
	if err != nil {
		writeJSON(w, http.StatusNotFound, Response{Status: "error", Message: "Profile not found"})
		return
	}
	writeJSON(w, http.StatusOK, Response{Status: "success", Data: profile})
}

func (h *ProfileHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}
	var input struct {
		Username  string `json:"username"`
		AvatarURL string `json:"avatar_url"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid request body"})
		return
	}

	if strings.TrimSpace(input.Username) == "" {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Username cannot be empty"})
		return
	}

	if err := h.Repo.UpdateProfile(userID, input.Username, input.AvatarURL); err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to update profile"})
		return
	}

	writeJSON(w, http.StatusOK, Response{Status: "success", Message: "Profile updated"})
}

func (h *ProfileHandler) UpdateAnthropometry(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	var input struct {
		Height float64 `json:"height"`
		Weight float64 `json:"weight"`
		Goal   string  `json:"goal"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid request body"})
		return
	}

	if input.Height <= 0 || input.Weight <= 0 {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Height and weight must be positive numbers"})
		return
	}
	if input.Goal == "" {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Goal cannot be empty"})
		return
	}

	if err := h.Repo.UpdateAnthropometry(userID, input.Height, input.Weight, input.Goal); err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to update anthropometry"})
		return
	}

	writeJSON(w, http.StatusOK, Response{Status: "success", Message: "Anthropometry updated"})
}

func (h *ProfileHandler) GetProgress(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "unauthorized"})
		return
	}

	logs, err := h.Repo.GetProgress(userID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "failed to get progress"})
		return
	}

	writeJSON(w, http.StatusOK, Response{
		Status: "success",
		Data:   logs,
	})
}

func (h *ProfileHandler) GetStats(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "unauthorized"})
		return
	}

	stats, err := h.Repo.GetStats(userID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "failed to get stats"})
		return
	}

	writeJSON(w, http.StatusOK, Response{Status: "success", Data: stats})
}
