package handler

import (
	"encoding/json"
	"net/http"
	"time"

	"gigafit/internal/models"
	"gigafit/internal/repository"
	"gigafit/service"

	"github.com/google/uuid"
)

type ChatHandler struct {
	Repo            repository.ChatRepository
	GigaChatService service.GigaChatService
}

func NewChatHandler(repo repository.ChatRepository, aiService service.GigaChatService) *ChatHandler {
	return &ChatHandler{
		Repo:            repo,
		GigaChatService: aiService,
	}
}

func (h *ChatHandler) SendMessage(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	var input struct {
		SessionID string `json:"session_id,omitempty"` // Может быть пустым для нового чата
		Message   string `json:"message"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid JSON format"})
		return
	}

	if input.Message == "" {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Message cannot be empty"})
		return
	}

	// 1. Обработка SessionID
	var sessionID uuid.UUID
	if input.SessionID == "" {
		sessionID = uuid.New() // Начинаем новый диалог
	} else {
		var err error
		sessionID, err = uuid.Parse(input.SessionID)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid session_id"})
			return
		}
	}

	// 2. Достаем историю переписки из БД
	history, _ := h.Repo.GetSessionHistory(userID, sessionID)

	// 3. Собираем контекст для GigaChat
	messages := []map[string]string{
		{
			"role":    "system",
			"content": "Ты персональный фитнес-тренер и нутрициолог GigaFit. Отвечай кратко, дружелюбно и по делу. Помогай пользователю с тренировками и питанием.",
		},
	}

	// Добавляем старые сообщения в массив
	for _, req := range history {
		// Сообщение пользователя
		messages = append(messages, map[string]string{"role": "user", "content": req.Prompt})

		// Ответ ИИ (достаем текст из JSONB)
		if aiResponseText, ok := req.Response.Data["text"].(string); ok {
			messages = append(messages, map[string]string{"role": "assistant", "content": aiResponseText})
		}
	}

	// Добавляем новое текущее сообщение
	messages = append(messages, map[string]string{"role": "user", "content": input.Message})

	// 4. Запрашиваем ответ у ИИ
	aiReply, err := h.GigaChatService.SendMessage(messages)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "AI failed to respond"})
		return
	}

	// 5. Сохраняем новую пару (Запрос-Ответ) в базу данных
	aiRequestLog := models.AIRequest{
		UserID:    userID,
		SessionID: sessionID,
		Prompt:    input.Message,
		Response: models.JSONB[map[string]any]{
			Data: map[string]any{"text": aiReply},
		},
		CreatedAt: time.Now(),
	}
	_ = h.Repo.SaveInteraction(&aiRequestLog)

	// 6. Возвращаем ответ клиенту (обязательно отдаем SessionID, чтобы фронт знал, куда слать некст сообщения)
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
