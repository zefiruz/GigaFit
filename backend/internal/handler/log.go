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

type LogHandler struct {
	Repo            repository.LogRepository
	GigaChatService service.GigaChatService
}

func NewLogHandler(repo repository.LogRepository, GigaChatService service.GigaChatService) *LogHandler {
	return &LogHandler{
		Repo:            repo,
		GigaChatService: GigaChatService,
	}
}

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

	writeJSON(w, http.StatusCreated, Response{Status: "success", Message: "Workout logged successfully"})
}

func (h *LogHandler) GetAllLogs(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	logs, err := h.Repo.GetAllLogs(userID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Failed to fetch logs"})
		return
	}

	writeJSON(w, http.StatusOK, Response{Status: "success", Data: logs})
}

func (h *LogHandler) GetAIAdvice(w http.ResponseWriter, r *http.Request) {
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

	prompt := fmt.Sprintf(
		"Пользователь фитнес-приложения только что завершил тренировку. Время: %d минут. Оценка самочувствия: '%s'. Дополнительный комментарий: '%s'. Дай ему короткий мотивирующий совет по восстановлению (не более 3 предложений). Будь дружелюбным тренером.",
		input.ActualDurationMins, input.Mood, input.Comment,
	)

	advice, err := h.GigaChatService.GenerateAdvice(prompt)
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
