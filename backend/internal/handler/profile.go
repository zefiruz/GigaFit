package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"gigafit/internal/repository"
	"gigafit/service"

	"github.com/redis/go-redis/v9"
)

type ProfileHandler struct {
	Repo      repository.ProfileRepository
	AiService service.GigaChatService
	Rdb       *redis.Client 
}

func NewProfileHandler(repo repository.ProfileRepository, aiService service.GigaChatService, rdb *redis.Client) *ProfileHandler {
	return &ProfileHandler{
		Repo:      repo,
		AiService: aiService,
		Rdb:       rdb, 
	}
}

// ================= GET PROFILE (С КЭШЕМ) =================
func (h *ProfileHandler) GetProfile(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	cacheKey := fmt.Sprintf("profile:user:%s", userID.String())

	responseData, err := GetWithCache(r.Context(), h.Rdb, cacheKey, 1*time.Hour, func() (interface{}, error) {
		user, err := h.Repo.GetProfileByID(userID)
		if err != nil {
			return nil, err
		}

		logs, err := h.Repo.GetProgress(userID)
		currentWeight := user.InitialWeight
		currentHeight := user.InitialHeight

		if err == nil && len(logs) > 0 {
			lastLog := logs[len(logs)-1]
			currentWeight = lastLog.Weight
			currentHeight = lastLog.Height
		}

		return UserProfileResponse{
			ID:            user.ID,
			Username:      user.Username,
			Email:         user.Email,
			AvatarURL:     user.AvatarURL,
			Gender:        user.Gender,
			Goal:          user.Goal,
			InitialWeight: user.InitialWeight,
			InitialHeight: user.InitialHeight,
			CurrentWeight: currentWeight,
			CurrentHeight: currentHeight,
		}, nil
	})
	if err != nil {
		writeJSON(w, http.StatusNotFound, Response{Status: "error", Message: "Profile not found"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(responseData)
}

// ================= UPDATE PROFILE (С ИНВАЛИДАЦИЕЙ) =================
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

	cacheKey := fmt.Sprintf("profile:user:%s", userID.String())
	h.Rdb.Del(context.Background(), cacheKey)

	writeJSON(w, http.StatusOK, Response{Status: "success", Message: "Profile updated"})
}

// ================= UPDATE ANTHROPOMETRY (КАСКАДНАЯ ИНВАЛИДАЦИЯ) =================
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

	profileKey := fmt.Sprintf("profile:user:%s", userID.String())
	progressKey := fmt.Sprintf("progress:user:%s", userID.String())
	adviceKey := fmt.Sprintf("advice:user:%s", userID.String())

	h.Rdb.Del(context.Background(), profileKey, progressKey, adviceKey)

	writeJSON(w, http.StatusOK, Response{Status: "success", Message: "Anthropometry updated"})
}

// ================= GET PROGRESS (С КЭШЕМ) =================
func (h *ProfileHandler) GetProgress(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "unauthorized"})
		return
	}

	cacheKey := fmt.Sprintf("progress:user:%s", userID.String())

	responseData, err := GetWithCache(r.Context(), h.Rdb, cacheKey, 1*time.Hour, func() (interface{}, error) {
		return h.Repo.GetProgress(userID)
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "failed to get progress"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(responseData)
}

// ================= GET STATS (С КЭШЕМ) =================
func (h *ProfileHandler) GetStats(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "unauthorized"})
		return
	}

	cacheKey := fmt.Sprintf("stats:user:%s", userID.String())

	responseData, err := GetWithCache(r.Context(), h.Rdb, cacheKey, 30*time.Minute, func() (interface{}, error) {
		return h.Repo.GetStats(userID)
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "failed to get stats"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(responseData)
}

// ================= GET BIOMETRIC ADVICE =================
func (h *ProfileHandler) GetBiometricAdvice(w http.ResponseWriter, r *http.Request) {
	userID, ok := getUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "Unauthorized"})
		return
	}

	cacheKey := fmt.Sprintf("advice:user:%s", userID.String())

	responseData, err := GetWithCache(r.Context(), h.Rdb, cacheKey, 24*time.Hour, func() (interface{}, error) {
		profile, err := h.Repo.GetProfileByID(userID)
		if err != nil {
			return nil, fmt.Errorf("profile_error")
		}

		logs, err := h.Repo.GetProgress(userID)
		if err != nil {
			return nil, fmt.Errorf("logs_error")
		}

		if len(logs) == 0 {
			return nil, fmt.Errorf("NO_LOGS")
		}

		advice, err := h.AiService.GenerateBiometricAdvice(logs, profile.Goal)
		if err != nil {
			fmt.Printf("Ошибка ИИ (совет): %v\n", err)
			return nil, fmt.Errorf("ai_error")
		}

		return map[string]string{"advice": advice}, nil
	})
	if err != nil {
		if err.Error() == "NO_LOGS" {
			writeJSON(w, http.StatusBadRequest, Response{
				Status:  "error",
				Message: "Для получения совета нужно добавить хотя бы один замер веса.",
			})
			return
		}
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "Нейросеть или БД недоступна"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(responseData)
}
