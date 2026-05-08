package service

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/google/uuid"
)

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
