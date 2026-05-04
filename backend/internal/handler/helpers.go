package handler

import (
	"encoding/json"
	"net/http"

	"gigafit/internal/middleware"

	"github.com/google/uuid"
)

// Response — стандартная структура ответа для всего API
type Response struct {
	Status  string      `json:"status"`
	Data    interface{} `json:"data,omitempty"`
	Message string      `json:"message,omitempty"`
}

// getUserID достает ID пользователя из контекста запроса
func getUserID(r *http.Request) (uuid.UUID, bool) {
	userID, ok := r.Context().Value(middleware.UserIDKey).(uuid.UUID)
	return userID, ok
}

// writeJSON отправляет стандартизированный JSON ответ
func writeJSON(w http.ResponseWriter, status int, resp Response) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(resp)
}
