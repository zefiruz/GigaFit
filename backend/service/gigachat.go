package service

import (
	"bytes"
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

// AIWorkoutResponse описывает структуру, которую мы ждем от ИИ
type AIWorkoutResponse struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Exercises   []struct {
		ID   uuid.UUID `json:"id"`
		Sets int       `json:"sets"`
		Reps int       `json:"reps"`
	} `json:"exercises"`
}

type GigaChatService interface {
	GenerateWorkout(userGoal string, availableExercises map[uuid.UUID]string) (*AIWorkoutResponse, error)
	GenerateAdvice(prompt string) (string, error)
	SendMessage(messages []map[string]string) (string, error)
}

type gigaChatService struct {
	AuthKey     string
	Client      *http.Client
	accessToken string
	expiresAt   time.Time
	mu          sync.RWMutex
}

func NewGigaChatService(authKey string) GigaChatService {
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	return &gigaChatService{
		AuthKey: authKey,
		Client:  &http.Client{Transport: tr, Timeout: 45 * time.Second}, // Увеличил таймаут для генерации тренировок
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

func (s *gigaChatService) GenerateWorkout(userGoal string, availableExercises map[uuid.UUID]string) (*AIWorkoutResponse, error) {
	token, err := s.getAccessToken()
	if err != nil {
		return nil, err
	}

	// Формируем список упражнений для контекста ИИ
	var exercisesContext []string
	for id, name := range availableExercises {
		exercisesContext = append(exercisesContext, fmt.Sprintf("- %s (ID: %s)", name, id.String()))
	}

	// Промпт теперь требует JSON формат
	systemPrompt := fmt.Sprintf(
		"Ты профессиональный фитнес-тренер. Твоя задача — составить тренировку, используя ТОЛЬКО упражнения из списка ниже. "+
			"СПИСОК УПРАЖНЕНИЙ:\n%s\n\n"+
			"Ответь СТРОГО в формате JSON: "+
			"{\"title\": \"название\", \"description\": \"описание\", \"exercises\": [{\"id\": \"uuid\", \"sets\": 3, \"reps\": 12}]}. "+
			"Не пиши ничего, кроме JSON.",
		strings.Join(exercisesContext, "\n"),
	)

	payload := map[string]interface{}{
		"model": "GigaChat",
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt},
			{"role": "user", "content": fmt.Sprintf("Цель тренировки: %s", userGoal)},
		},
		"temperature": 0.8,
	}
	body, _ := json.Marshal(payload)

	req, _ := http.NewRequest("POST", "https://gigachat.devices.sberbank.ru/api/v1/chat/completions", bytes.NewBuffer(body))
	req.Header.Add("Content-Type", "application/json")
	req.Header.Add("Authorization", "Bearer "+token)

	res, err := s.Client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()

	var chatRes struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.NewDecoder(res.Body).Decode(&chatRes); err != nil || len(chatRes.Choices) == 0 {
		return nil, fmt.Errorf("ошибка нейросети")
	}

	// Парсим JSON из ответа ИИ в нашу структуру
	var workoutRes AIWorkoutResponse
	aiContent := chatRes.Choices[0].Message.Content

	// Иногда ИИ добавляет ```json ... ```, чистим это
	aiContent = strings.TrimPrefix(aiContent, "```json")
	aiContent = strings.TrimSuffix(aiContent, "```")
	aiContent = strings.TrimSpace(aiContent)

	if err := json.Unmarshal([]byte(aiContent), &workoutRes); err != nil {
		return nil, fmt.Errorf("ИИ вернул неверный формат: %v", err)
	}

	return &workoutRes, nil
}

func (s *gigaChatService) GenerateAdvice(prompt string) (string, error) {
	token, err := s.getAccessToken()
	if err != nil {
		return "", err
	}

	payload := map[string]interface{}{
		"model": "GigaChat",
		"messages": []map[string]string{
			{
				"role":    "system",
				"content": "Ты дружелюбный и заботливый фитнес-тренер. Твоя цель — хвалить пользователя за выполненную тренировку и давать короткий, мотивирующий совет по восстановлению или питанию. Отвечай кратко, не более 3 предложений.",
			},
			{
				"role":    "user",
				"content": prompt, 
			},
		},
		"temperature": 0.7, 
	}
	body, _ := json.Marshal(payload)

	req, _ := http.NewRequest("POST", "https://gigachat.devices.sberbank.ru/api/v1/chat/completions", bytes.NewBuffer(body))
	req.Header.Add("Content-Type", "application/json")
	req.Header.Add("Authorization", "Bearer "+token)

	res, err := s.Client.Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		return "", fmt.Errorf("gigachat response failed with status: %d", res.StatusCode)
	}

	var chatRes struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.NewDecoder(res.Body).Decode(&chatRes); err != nil || len(chatRes.Choices) == 0 {
		return "", fmt.Errorf("ошибка парсинга ответа от нейросети")
	}

	advice := strings.TrimSpace(chatRes.Choices[0].Message.Content)

	return advice, nil
}

func (s *gigaChatService) SendMessage(messages []map[string]string) (string, error) {
	token, err := s.getAccessToken()
	if err != nil {
		return "", err
	}

	payload := map[string]interface{}{
		"model":       "GigaChat",
		"messages":    messages,
		"temperature": 0.7,
	}
	body, _ := json.Marshal(payload)

	req, _ := http.NewRequest("POST", "https://gigachat.devices.sberbank.ru/api/v1/chat/completions", bytes.NewBuffer(body))
	req.Header.Add("Content-Type", "application/json")
	req.Header.Add("Authorization", "Bearer "+token)

	res, err := s.Client.Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		return "", fmt.Errorf("gigachat response failed with status: %d", res.StatusCode)
	}

	var chatRes struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.NewDecoder(res.Body).Decode(&chatRes); err != nil || len(chatRes.Choices) == 0 {
		return "", fmt.Errorf("ошибка парсинга ответа от нейросети")
	}

	return strings.TrimSpace(chatRes.Choices[0].Message.Content), nil
}