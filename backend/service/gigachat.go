package service

import (
	"crypto/tls"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
)

type GigaChatService interface {
	GenerateWorkout(userGoal string, availableExercises map[uuid.UUID]string) (*AIWorkoutResponse, error)
	GenerateAdvice(prompt string) (string, error)
	SendMessage(messages []map[string]string) (string, error)
	GeneratePlanOrchestrator(userGoal string, daysPerWeek int) (*PlanBlueprint, error)
}

type gigaChatService struct {
	AuthKey     string
	Client      *http.Client
	accessToken string
	expiresAt   time.Time
	mu          sync.RWMutex
}

type PlanBlueprint struct {
	Title       string
	Description string
	DailyGoals  []string
}

func NewGigaChatService(authKey string) GigaChatService {
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	return &gigaChatService{
		AuthKey: authKey,
		Client:  &http.Client{Transport: tr, Timeout: 45 * time.Second},
	}
}

func (s *gigaChatService) getAccessToken() (string, error) {
	s.mu.RLock()
	if s.accessToken != "" && time.Now().Before(s.expiresAt.Add(-1*time.Minute)) {
		s.mu.RUnlock()
		return s.accessToken, nil
	}
	s.mu.RUnlock()

	reqUrl := "https://ngw.devices.sberbank.ru:9443/api/v2/oauth"
	data := url.Values{}
	data.Set("scope", "GIGACHAT_API_PERS")

	req, _ := http.NewRequest("POST", reqUrl, strings.NewReader(data.Encode()))
	req.Header.Add("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Add("Accept", "application/json")
	req.Header.Add("RqUID", uuid.New().String())
	req.Header.Add("Authorization", "Basic "+s.AuthKey)

	res, err := s.Client.Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		return "", fmt.Errorf("oauth failed with status: %d", res.StatusCode)
	}

	var result struct {
		AccessToken string `json:"access_token"`
		ExpiresAt   int64  `json:"expires_at"`
	}

	if err := json.NewDecoder(res.Body).Decode(&result); err != nil {
		return "", err
	}

	s.accessToken = result.AccessToken
	s.expiresAt = time.UnixMilli(result.ExpiresAt)

	return result.AccessToken, nil
}
