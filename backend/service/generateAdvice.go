package service

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"

	"gigafit/internal/models"
)

func (s *gigaChatService) GenerateAdviceAfterWorkout(prompt string) (string, error) {
	token, err := s.getAccessToken()
	if err != nil {
		return "", fmt.Errorf("ошибка получения токена: %w", err)
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

	// 1. БЕЗОПАСНЫЙ МАРШАЛИНГ
	body, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("ошибка формирования JSON: %w", err)
	}

	// 2. БЕЗОПАСНОЕ СОЗДАНИЕ ЗАПРОСА
	req, err := http.NewRequest("POST", "https://gigachat.devices.sberbank.ru/api/v1/chat/completions", bytes.NewBuffer(body))
	if err != nil {
		return "", fmt.Errorf("ошибка создания HTTP-запроса: %w", err)
	}

	req.Header.Add("Content-Type", "application/json")
	req.Header.Add("Authorization", "Bearer "+token)

	res, err := s.Client.Do(req)
	if err != nil {
		return "", fmt.Errorf("ошибка отправки запроса в GigaChat: %w", err)
	}
	defer res.Body.Close()

	// 3. ИНФОРМАТИВНАЯ ОБРАБОТКА ОШИБОК API
	if res.StatusCode != http.StatusOK {
		errorBody, _ := io.ReadAll(res.Body)
		return "", fmt.Errorf("gigachat вернул статус %d. Подробности: %s", res.StatusCode, string(errorBody))
	}

	var chatRes struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.NewDecoder(res.Body).Decode(&chatRes); err != nil {
		return "", fmt.Errorf("ошибка парсинга ответа от нейросети: %w", err)
	}

	if len(chatRes.Choices) == 0 {
		return "", fmt.Errorf("нейросеть вернула пустой список ответов")
	}

	advice := strings.TrimSpace(chatRes.Choices[0].Message.Content)

	return advice, nil
}

func (s *gigaChatService) GenerateBiometricAdvice(logs []models.MeasurementLog, goal string) (string, error) {
	token, err := s.getAccessToken()
	if err != nil {
		return "", fmt.Errorf("ошибка получения токена: %w", err)
	}

	if goal == "" {
		goal = "Поддержание формы"
	}

	// 1. ОПТИМИЗАЦИЯ: Сжимаем историю в короткий текст с помощью Builder
	var historyBuilder strings.Builder
	for _, log := range logs {
		// Формат: "02.05.2026: 85.5 кг"
		dateStr := log.CreatedAt.Format("02.01.2006")
		historyBuilder.WriteString(fmt.Sprintf("%s: %.1f кг\n", dateStr, log.Weight))
	}

	// 2. Умный промпт, который заставляет ИИ анализировать тренд
	systemPrompt := "Ты элитный фитнес-тренер. Я дам тебе историю изменения моего веса и мою цель. " +
		"Проанализируй тренд. Если я молодец — похвали. Если вес стоит на месте (плато) — дай короткий жесткий совет по питанию. " +
		"ОТВЕЧАЙ КРАТКО: максимум 3 предложения. Без воды."

	userPrompt := fmt.Sprintf("Моя цель: %s.\nМоя история взвешиваний:\n%s\nКакой дашь совет?",
		goal,
		strings.TrimSpace(historyBuilder.String()),
	)

	payload := map[string]interface{}{
		"model":       "GigaChat",
		"temperature": 0.7, // Даем ИИ креативность для разнообразия советов
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt},
			{"role": "user", "content": userPrompt},
		},
	}

	body, _ := json.Marshal(payload)
	req, _ := http.NewRequest("POST", "https://gigachat.devices.sberbank.ru/api/v1/chat/completions", bytes.NewBuffer(body))
	req.Header.Add("Content-Type", "application/json")
	req.Header.Add("Authorization", "Bearer "+token)

	res, err := s.Client.Do(req)
	if err != nil {
		return "", fmt.Errorf("ошибка сети GigaChat: %w", err)
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		errorBody, _ := io.ReadAll(res.Body)
		return "", fmt.Errorf("gigachat вернул статус %d: %s", res.StatusCode, string(errorBody))
	}

	var chatRes struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.NewDecoder(res.Body).Decode(&chatRes); err != nil || len(chatRes.Choices) == 0 {
		return "", fmt.Errorf("ошибка парсинга ответа GigaChat: %w", err)
	}

	return strings.TrimSpace(chatRes.Choices[0].Message.Content), nil
}
