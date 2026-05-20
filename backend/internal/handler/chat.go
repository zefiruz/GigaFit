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

type ChatHandler struct {
	Repo            repository.ChatRepository
	ProfileRepo     repository.ProfileRepository
	GigaChatService service.GigaChatService
	Rdb             *redis.Client
}

func NewChatHandler(repo repository.ChatRepository, profileRepo repository.ProfileRepository, aiService service.GigaChatService, rdb *redis.Client) *ChatHandler {
	return &ChatHandler{
		Repo:            repo,
		ProfileRepo:     profileRepo,
		GigaChatService: aiService,
		Rdb:             rdb,
	}
}

func (h *ChatHandler) SendMessage(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	profile, err := h.ProfileRepo.GetProfileByID(userID)
	logs, _ := h.ProfileRepo.GetProgress(userID)

	systemContent := "Ты персональный фитнес-тренер и нутрициолог GigaFit. Отвечай кратко, дружелюбно и по делу."

	if err == nil && profile != nil {
		currentWeight := profile.InitialWeight
		currentHeight := profile.InitialHeight

		if len(logs) > 0 {
			lastLog := logs[len(logs)-1]
			currentWeight = lastLog.Weight
			currentHeight = lastLog.Height
		}

		if currentWeight > 0 {
			systemContent += fmt.Sprintf(
				" Контекст клиента: Имя - %s, Текущий вес - %.1f кг, Рост - %.1f см, Цель - %s.",
				profile.Username, currentWeight, currentHeight, profile.Goal,
			)
		}
	}

	var input struct {
		SessionID string `json:"session_id,omitempty"`
		Message   string `json:"message"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil || input.Message == "" {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid JSON or empty message"})
		return
	}

	var sessionID uuid.UUID
	if input.SessionID == "" {
		sessionID = uuid.New()
	} else {
		var parseErr error
		sessionID, parseErr = uuid.Parse(input.SessionID)
		if parseErr != nil {
			writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid session_id format"})
			return
		}
	}

	history, err := h.Repo.GetSessionHistory(userID, sessionID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to load chat history"})
		return
	}

	messages := []map[string]string{
		{
			"role":    "system",
			"content": systemContent,
		},
	}

	for _, req := range history {
		messages = append(messages, map[string]string{"role": "user", "content": req.Prompt})
		if aiText, ok := req.Response.Data["text"].(string); ok {
			messages = append(messages, map[string]string{"role": "assistant", "content": aiText})
		}
	}

	messages = append(messages, map[string]string{"role": "user", "content": input.Message})

	aiReply, err := h.GigaChatService.SendMessage(messages)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "AI failed to respond"})
		return
	}

	aiRequestLog := models.AIRequest{
		UserID:    userID,
		SessionID: sessionID,
		Prompt:    input.Message,
		Response:  models.JSONB[map[string]any]{Data: map[string]any{"text": aiReply}},
		CreatedAt: time.Now(),
	}
	_ = h.Repo.SaveInteraction(&aiRequestLog)

	cacheKey := fmt.Sprintf("chat:history:user:%s:session:%s", userID.String(), sessionID.String())
	h.Rdb.Del(context.Background(), cacheKey)

	writeJSON(w, http.StatusOK, Response{
		Status: "success",
		Data: map[string]interface{}{
			"session_id": sessionID,
			"reply":      aiReply,
		},
	})
}

func (h *ChatHandler) GetHistory(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	sessionID, err := uuid.Parse(r.URL.Query().Get("session_id"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Valid session_id query parameter is required"})
		return
	}

	cacheKey := fmt.Sprintf("chat:history:user:%s:session:%s", userID, sessionID)

	responseData, err := GetWithCache(r.Context(), h.Rdb, cacheKey, 15*time.Minute, func() (interface{}, error) {
		return h.Repo.GetSessionHistory(userID, sessionID)
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to fetch exercises"})
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(responseData)
}
