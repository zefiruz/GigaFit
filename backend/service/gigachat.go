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

	systemPrompt := fmt.Sprintf(
		"Ты тренер. Составь тренировку, выбрав МАКСИМУМ 5-6 упражнений ТОЛЬКО из списка:\n%s\n\n"+
			"ПРАВИЛА:\n"+
			"1. ОТВЕЧАЙ СТРОГО В JSON.\n"+
			"2. БЕЗ markdown-разметки (никаких ```json).\n"+
			"3. Ключи и структура должны БУКВАЛЬНО совпадать с шаблоном.\n\n"+
			"ШАБЛОН ОТВЕТА:\n"+
			`{"title":"Твоя тренировка","description":"Кратко","exercises":[{"id":1,"sets":3,"reps":12}]}`,
		strings.Join(exercisesContext, "\n"),
	)

	payload := map[string]interface{}{
		"model":       "GigaChat",
		"temperature": 0.1,
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt},
			{"role": "user", "content": userGoal},
		},
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

	startIndex := strings.Index(aiContent, "{")
	endIndex := strings.LastIndex(aiContent, "}")
	if startIndex == -1 || endIndex == -1 {
		return nil, fmt.Errorf("ИИ не вернул JSON. Ответ: %s", aiContent)
	}
	cleanJSON := aiContent[startIndex : endIndex+1]

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

	if err := json.Unmarshal([]byte(cleanJSON), &shortRes); err != nil {
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

func (s *gigaChatService) GeneratePlanOrchestrator(userGoal string, daysPerWeek int) (*PlanBlueprint, error) {
	token, err := s.getAccessToken()
	if err != nil {
		return nil, err
	}

	// 1. Просим ИИ вернуть Название, Описание и список дней в виде обычного текста
	systemPrompt := fmt.Sprintf(
		"Ты элитный фитнес-тренер. Клиент хочет: '%s'. Разбей эту цель на %d тренировок.\n"+
			"ОТВЕЧАЙ СТРОГО В ТАКОМ ФОРМАТЕ (каждый пункт с новой строки, без markdown и без JSON):\n"+
			"Название: [Придумай крутое, цепляющее название плану]\n"+
			"Описание: [Напиши 1-2 мотивирующих предложения о плане]\n"+
			"Тренировка: [Фокус 1]\n"+
			"Тренировка: [Фокус 2]",
		userGoal, daysPerWeek,
	)

	payload := map[string]interface{}{
		"model":       "GigaChat",
		"temperature": 0.5, // Немного даем креатива для придумывания названия
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt},
			{"role": "user", "content": "Сгенерируй структуру плана"},
		},
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
		return nil, fmt.Errorf("ошибка ответа GigaChat")
	}

	aiContent := chatRes.Choices[0].Message.Content

	// 2. ПАРСИНГ ОБЫЧНОГО ТЕКСТА
	lines := strings.Split(aiContent, "\n")
	blueprint := &PlanBlueprint{}

	for _, line := range lines {
		cleanLine := strings.TrimSpace(line)
		if cleanLine == "" {
			continue
		}

		// Вытаскиваем Название
		if strings.HasPrefix(cleanLine, "Название:") {
			blueprint.Title = strings.TrimSpace(strings.TrimPrefix(cleanLine, "Название:"))
			continue
		}

		// Вытаскиваем Описание
		if strings.HasPrefix(cleanLine, "Описание:") {
			blueprint.Description = strings.TrimSpace(strings.TrimPrefix(cleanLine, "Описание:"))
			continue
		}

		// Все остальное считаем днями тренировок (чистим от лишних слов в начале)
		cleanGoal := strings.TrimLeft(cleanLine, "1234567890.- ТренировкаДень: ")
		if cleanGoal != "" {
			blueprint.DailyGoals = append(blueprint.DailyGoals, cleanGoal)
		}
	}

	// Страховка (если ИИ почему-то не придумал название)
	if blueprint.Title == "" {
		blueprint.Title = "План: " + userGoal
	}
	if blueprint.Description == "" {
		blueprint.Description = "Сгенерировано умным помощником GigaFit."
	}

	// Обрезаем массив, если ИИ "перестарался" и выдал больше дней
	if len(blueprint.DailyGoals) > daysPerWeek {
		blueprint.DailyGoals = blueprint.DailyGoals[:daysPerWeek]
	}

	return blueprint, nil
}