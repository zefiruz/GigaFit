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

type LogHandler struct {
	Repo            repository.LogRepository
	GigaChatService service.GigaChatService
	Rdb             *redis.Client 
}

func NewLogHandler(repo repository.LogRepository, aiService service.GigaChatService, rdb *redis.Client) *LogHandler {
	return &LogHandler{
		Repo:            repo,
		GigaChatService: aiService,
		Rdb:             rdb, 
	}
}

// ================= CREATE LOG =================
func (h *LogHandler) CreateLog(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	var input struct {
		WorkoutID uuid.UUID                    `json:"workout_id"`
		Payload   models.WorkoutSessionPayload `json:"payload"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid request body"})
		return
	}

	if input.WorkoutID == uuid.Nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Workout ID is required"})
		return
	}

	log := models.WorkoutLog{
		UserID:    userID,
		WorkoutID: input.WorkoutID,
		Payload: models.JSONB[models.WorkoutSessionPayload]{
			Data: input.Payload,
		},
		CreatedAt: time.Now(),
	}

	if err := h.Repo.CreateLog(&log); err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to save workout log"})
		return
	}

	// 1. Сбрасываем кэш списка логов 
	// 2. Сбрасываем кэш статистики профиля 
	logsKey := fmt.Sprintf("logs:user:%s", userID.String())
	statsKey := fmt.Sprintf("stats:user:%s", userID.String())
	
	h.Rdb.Del(context.Background(), logsKey, statsKey)

	writeJSON(w, http.StatusCreated, Response{Status: "success", Message: "Workout logged successfully"})
}

// ================= GET ALL LOGS =================
func (h *LogHandler) GetAllLogs(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	cacheKey := fmt.Sprintf("logs:user:%s", userID.String())

	responseData, err := GetWithCache(r.Context(), h.Rdb, cacheKey, 30*time.Minute, func() (interface{}, error) {
		return h.Repo.GetAllLogs(userID)
	})

	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to fetch logs"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(responseData)
}

// ================= GET AI ADVICE =================
func (h *LogHandler) GetAIAdviceAfterWorkout(w http.ResponseWriter, r *http.Request) {
	_, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	var input struct {
		Mood               string `json:"mood"`
		Comment            string `json:"comment"`
		ActualDurationMins int    `json:"actual_duration_mins"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "Invalid request body"})
		return
	}

	if input.ActualDurationMins <= 0 {
		input.ActualDurationMins = 45 
	}
	if input.Mood == "" {
		input.Mood = "нормальное"
	}

	prompt := fmt.Sprintf(
		"Пользователь фитнес-приложения только что завершил тренировку. Время: %d минут. Оценка самочувствия: '%s'. Дополнительный комментарий: '%s'. Дай ему короткий мотивирующий совет по восстановлению (не более 3 предложений). Будь дружелюбным тренером.",
		input.ActualDurationMins, input.Mood, input.Comment,
	)

	advice, err := h.GigaChatService.GenerateAdviceAfterWorkout(prompt)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "AI is tired right now"})
		return
	}

	writeJSON(w, http.StatusOK, Response{
		Status: "success",
		Data: map[string]string{
			"advice": advice,
		},
	})
}