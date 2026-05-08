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

type ChatHandler struct {
	Repo            repository.ChatRepository
	ProfileRepo     repository.ProfileRepository
	GigaChatService service.GigaChatService
}

func NewChatHandler(repo repository.ChatRepository, profileRepo repository.ProfileRepository, aiService service.GigaChatService) *ChatHandler {
	return &ChatHandler{
		Repo:            repo,
		ProfileRepo:     profileRepo,
		GigaChatService: aiService,
	}
}

func (h *ChatHandler) SendMessage(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	// 1. Сначала подтягиваем профиль для контекста
	profile, err := h.ProfileRepo.GetProfileByID(userID)
	logs, err := h.ProfileRepo.GetProgress(userID)

	systemContent := "Ты персональный фитнес-тренер и нутрициолог GigaFit. Отвечай кратко, дружелюбно и по делу."

	if err == nil && profile != nil {
		// По умолчанию берем начальные параметры
		currentWeight := profile.InitialWeight
		currentHeight := profile.InitialHeight

		// Если есть история замеров, берем самый последний (свежий)
		if len(logs) > 0 {
			lastLog := logs[len(logs)-1] // берем самый свежий замер
			currentWeight = lastLog.Weight
			currentHeight = lastLog.Height
		}

		// Добавляем контекст только если вес больше 0 (чтобы не передавать ИИ нули)
		if currentWeight > 0 {
			systemContent += fmt.Sprintf(
				" Контекст клиента: Имя - %s, Текущий вес - %.1f кг, Рост - %.1f см, Цель - %s.",
				profile.Username, currentWeight, currentHeight, profile.Goal,
			)
		}
	}

	// 2. Декодируем входящее сообщение
	var input struct {
		SessionID string `json:"session_id,omitempty"`
		Message   string `json:"message"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid JSON format"})
		return
	}

	// 3. Работа с SessionID
	var sessionID uuid.UUID
	if input.SessionID == "" {
		sessionID = uuid.New()
	} else {
		sessionID, _ = uuid.Parse(input.SessionID)
	}

	// 4. Достаем историю
	history, _ := h.Repo.GetSessionHistory(userID, sessionID)

	// 5. Собираем массив сообщений для ИИ
	messages := []map[string]string{
		{
			"role":    "system",
			"content": systemContent, // Тот самый прокачанный контекст
		},
	}

	// Добавляем историю из БД
	for _, req := range history {
		messages = append(messages, map[string]string{"role": "user", "content": req.Prompt})
		if aiText, ok := req.Response.Data["text"].(string); ok {
			messages = append(messages, map[string]string{"role": "assistant", "content": aiText})
		}
	}

	// Добавляем новое сообщение пользователя
	messages = append(messages, map[string]string{"role": "user", "content": input.Message})

	// 6. Отправляем в GigaChat
	aiReply, err := h.GigaChatService.SendMessage(messages)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "AI failed"})
		return
	}

	// 7. Сохраняем в лог и отвечаем
	aiRequestLog := models.AIRequest{
		UserID:    userID,
		SessionID: sessionID,
		Prompt:    input.Message,
		Response:  models.JSONB[map[string]any]{Data: map[string]any{"text": aiReply}},
		CreatedAt: time.Now(),
	}
	_ = h.Repo.SaveInteraction(&aiRequestLog)

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

	sessionIDStr := r.URL.Query().Get("session_id")
	sessionID, err := uuid.Parse(sessionIDStr)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Valid session_id query parameter is required"})
		return
	}

	history, err := h.Repo.GetSessionHistory(userID, sessionID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to get history"})
		return
	}

	writeJSON(w, http.StatusOK, Response{Status: "success", Data: history})
}
