package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"gigafit/internal/middleware"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

// Response — стандартная структура ответа для всего API
type Response struct {
	Status  string      `json:"status"`
	Data    interface{} `json:"data,omitempty"`
	Message string      `json:"message,omitempty"`
}

type UserProfileResponse struct {
	ID            uuid.UUID `json:"id"`
	Username      string    `json:"username"`
	Email         string    `json:"email"`
	AvatarURL     string    `json:"avatar_url"`
	Gender        string    `json:"gender"`
	Goal          string    `json:"goal"`
	InitialWeight float64   `json:"initial_weight"`
	InitialHeight float64   `json:"initial_height"`
	CurrentWeight float64   `json:"current_weight"` // Вычисляемое поле
	CurrentHeight float64   `json:"current_height"` // Вычисляемое поле
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

func GetWithCache(ctx context.Context, rdb *redis.Client, cacheKey string, ttl time.Duration, fetcher func() (interface{}, error)) ([]byte, error) {
	cachedData, err := rdb.Get(ctx, cacheKey).Bytes()
	if err == nil {
		return cachedData, nil
	}

	data, err := fetcher()
	if err != nil {
		return nil, err 
	}

	responseJSON, err := json.Marshal(Response{Status: "success", Data: data})
	if err != nil {
		return nil, err
	}

	rdb.Set(context.Background(), cacheKey, responseJSON, ttl)

	return responseJSON, nil
}
