package handler

import (
	"net/http"
	"gigafit/internal/repository"
	"github.com/google/uuid"
)

type CommunityHandler struct {
	Repo repository.CommunityRepository
}

func NewCommunityHandler(repo repository.CommunityRepository) *CommunityHandler {
	return &CommunityHandler{Repo: repo}
}

func (h *CommunityHandler) GetFeed(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok { return }

	workouts, err := h.Repo.GetFeed(userID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to load feed"})
		return
	}
	writeJSON(w, http.StatusOK, Response{Status: "success", Data: workouts})
}

func (h *CommunityHandler) PublishWorkout(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	id, err := uuid.Parse(r.PathValue("id"))
	if !ok || err != nil { return }

	if err := h.Repo.PublishWorkout(id, userID); err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to publish"})
		return
	}
	writeJSON(w, http.StatusOK, Response{Status: "success", Message: "Workout published to feed"})
}

func (h *CommunityHandler) ToggleLike(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	id, err := uuid.Parse(r.PathValue("id"))
	if !ok || err != nil { return }

	isLiked, err := h.Repo.ToggleLike(id, userID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Action failed"})
		return
	}

	msg := "Unliked"
	if isLiked { msg = "Liked" }
	writeJSON(w, http.StatusOK, Response{Status: "success", Message: msg})
}

func (h *CommunityHandler) SaveWorkout(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	id, err := uuid.Parse(r.PathValue("id"))
	if !ok || err != nil { return }

	if err := h.Repo.SaveWorkout(id, userID); err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to save"})
		return
	}
	writeJSON(w, http.StatusOK, Response{Status: "success", Message: "Saved to your profile"})
}