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

type GigaChatService interface {
	GenerateWorkout(userGoal string, availableExercises map[uuid.UUID]string) (*AIWorkoutResponse, error)
	GenerateAdvice(prompt string) (string, error)
	SendMessage(messages []map[string]string) (string, error)
	GeneratePlan(userGoal string, daysPerWeek int, availableExercises map[uuid.UUID]string) (*AIPlanResponse, error)
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

	// 1. ОПТИМИЗАЦИЯ: Создаем временный словарь для коротких ID
	shortToUUID := make(map[int]uuid.UUID)
	var exercisesContext []string
	
	counter := 1
	for id, name := range availableExercises {
		shortToUUID[counter] = id // Запоминаем, что номеру 1 принадлежит такой-то UUID
		// Передаем ИИ очень короткую строку: "1: Жим лежа"
		exercisesContext = append(exercisesContext, fmt.Sprintf("%d: %s", counter, name))
		counter++
	}

	// 2. ОПТИМИЗАЦИЯ: Просим меньше упражнений и используем короткие ID в примере
	systemPrompt := fmt.Sprintf(
		"Ты фитнес-тренер. Составь тренировку, выбрав МАКСИМУМ 5-7 упражнений из списка ниже. "+
			"СПИСОК (ID: Название):\n%s\n\n"+
			"Ответь СТРОГО в формате JSON:\n"+
			`{"title": "название", "description": "описание", "exercises": [{"id": 1, "sets": 3, "reps": 12}]}`,
		strings.Join(exercisesContext, "\n"),
	)

	payload := map[string]interface{}{
		"model": "GigaChat",
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt},
			{"role": "user", "content": fmt.Sprintf("Цель: %s", userGoal)},
		},
		"temperature": 0.7,
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

	aiContent := chatRes.Choices[0].Message.Content
	aiContent = strings.TrimPrefix(aiContent, "```json")
	aiContent = strings.TrimSuffix(aiContent, "```")
	aiContent = strings.TrimSpace(aiContent)

	// 3. Создаем временную структуру для парсинга, где ID - это int (число)
	var shortRes struct {
		Title       string `json:"title"`
		Description string `json:"description"`
		Exercises   []struct {
			ID   int `json:"id"` // ИИ вернул просто цифру (например, 5)
			Sets int `json:"sets"`
			Reps int `json:"reps"`
		} `json:"exercises"`
	}

	if err := json.Unmarshal([]byte(aiContent), &shortRes); err != nil {
		return nil, fmt.Errorf("ИИ вернул неверный формат: %v", err)
	}

	// 4. ВОЗВРАЩАЕМ UUID НА МЕСТО
	var finalRes AIWorkoutResponse
	finalRes.Title = shortRes.Title
	finalRes.Description = shortRes.Description

	for _, ex := range shortRes.Exercises {
		// Достаем настоящий UUID по короткому номеру
		realUUID, exists := shortToUUID[ex.ID]
		if !exists {
			continue // Если ИИ придумал несуществующий номер, просто пропускаем
		}
		
		finalRes.Exercises = append(finalRes.Exercises, struct {
			ID   uuid.UUID `json:"id"`
			Sets int       `json:"sets"`
			Reps int       `json:"reps"`
		}{
			ID:   realUUID,
			Sets: ex.Sets,
			Reps: ex.Reps,
		})
	}

	return &finalRes, nil
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

func (s *gigaChatService) GeneratePlan(userGoal string, daysPerWeek int, availableExercises map[uuid.UUID]string) (*AIPlanResponse, error) {
	token, err := s.getAccessToken()
	if err != nil {
		return nil, err
	}

	// 1. ОПТИМИЗАЦИЯ: Временный словарь для коротких ID
	shortToUUID := make(map[int]uuid.UUID)
	var exercisesContext []string

	counter := 1
	for id, name := range availableExercises {
		shortToUUID[counter] = id
		exercisesContext = append(exercisesContext, fmt.Sprintf("%d: %s", counter, name))
		counter++
	}

	// 2. Системный промпт просит план и использует короткие ID
	systemPrompt := fmt.Sprintf(
		"Ты фитнес-тренер. Составь план тренировок на %d дня(ей) в неделю. Выбирай МАКСИМУМ по 5-6 упражнений на день ТОЛЬКО из списка:\n%s\n\n"+
			"Ответь СТРОГО в формате JSON:\n"+
			`{"title": "Название плана", "description": "Описание", "workouts": [{"day_number": 1, "title": "День 1", "exercises": [{"id": 1, "sets": 3, "reps": 12}]}]}`,
		daysPerWeek, strings.Join(exercisesContext, "\n"),
	)

	payload := map[string]interface{}{
		"model": "GigaChat",
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt},
			{"role": "user", "content": fmt.Sprintf("Цель плана: %s", userGoal)},
		},
		"temperature": 0.7,
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
		return nil, fmt.Errorf("ошибка парсинга ответа GigaChat")
	}

	aiContent := chatRes.Choices[0].Message.Content
	aiContent = strings.TrimPrefix(aiContent, "```json")
	aiContent = strings.TrimSuffix(aiContent, "```")
	aiContent = strings.TrimSpace(aiContent)

	// 3. Создаем временную структуру, которая зеркалит AIPlanResponse, но ID здесь типа int
	var shortRes struct {
		Title       string `json:"title"`
		Description string `json:"description"`
		Workouts    []struct {
			DayNumber int    `json:"day_number"`
			Title     string `json:"title"`
			Exercises []struct {
				ID   int `json:"id"` // <-- Тут число!
				Sets int `json:"sets"`
				Reps int `json:"reps"`
			} `json:"exercises"`
		} `json:"workouts"`
	}

	if err := json.Unmarshal([]byte(aiContent), &shortRes); err != nil {
		return nil, fmt.Errorf("ИИ вернул неверный формат JSON: %v", err)
	}

	// 4. Собираем финальный ответ правильного типа (AIPlanResponse)
	var finalRes AIPlanResponse
	finalRes.Title = shortRes.Title
	finalRes.Description = shortRes.Description

	// Проходимся по каждой тренировке в плане
	for _, w := range shortRes.Workouts {
		// Подготавливаем массив упражнений для текущей тренировки
		var finalExercises []struct {
			ID   uuid.UUID `json:"id"`
			Sets int       `json:"sets"`
			Reps int       `json:"reps"`
		}

		// Проходимся по упражнениям и меняем int на UUID
		for _, ex := range w.Exercises {
			realUUID, exists := shortToUUID[ex.ID]
			if !exists {
				continue // Пропускаем галлюцинации ИИ
			}
			finalExercises = append(finalExercises, struct {
				ID   uuid.UUID `json:"id"`
				Sets int       `json:"sets"`
				Reps int       `json:"reps"`
			}{
				ID:   realUUID,
				Sets: ex.Sets,
				Reps: ex.Reps,
			})
		}

		// Добавляем тренировку в финальный план
		finalRes.Workouts = append(finalRes.Workouts, struct {
			DayNumber int    `json:"day_number"`
			Title     string `json:"title"`
			Exercises []struct {
				ID   uuid.UUID `json:"id"`
				Sets int       `json:"sets"`
				Reps int       `json:"reps"`
			} `json:"exercises"`
		}{
			DayNumber: w.DayNumber,
			Title:     w.Title,
			Exercises: finalExercises, // Кладем сконвертированные упражнения
		})
	}

	// Теперь всё совпадает, возвращаем указатель на план!
	return &finalRes, nil
}