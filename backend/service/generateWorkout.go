package service

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/google/uuid"
)

type AIWorkoutResponse struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Exercises   []struct {
		ID   uuid.UUID `json:"id"`
		Sets int       `json:"sets"`
		Reps int       `json:"reps"`
	} `json:"exercises"`
}

func (s *gigaChatService) GenerateWorkout(userGoal string, availableExercises map[uuid.UUID]string) (*AIWorkoutResponse, error) {
	token, err := s.getAccessToken()
	if err != nil {
		return nil, fmt.Errorf("ошибка токена: %w", err)
	}

	shortToUUID := make(map[int]uuid.UUID)
	var exercisesBuilder strings.Builder

	counter := 1
	for id, name := range availableExercises {
		shortToUUID[counter] = id
		exercisesBuilder.WriteString(fmt.Sprintf("%d: %s\n", counter, name))
		counter++
	}

	// 1. ПРОМПТ
	systemPrompt := fmt.Sprintf(
		"Ты фитнес-тренер. ВЫБЕРИ РОВНО 5 ИЛИ 6 УПРАЖНЕНИЙ из списка ниже, которые лучше всего подходят под цель пользователя.\nСписок:\n%s\n"+
			"ОТВЕЧАЙ СТРОГО ПО ШАБЛОНУ:\n"+
			"Название: Твое название\n"+
			"Описание: Твое описание\n"+
			"ID|Подходы|Повторения\n\n"+
			"ПРИМЕР ОТВЕТА:\n"+
			"Название: Мощная грудь\n"+
			"Описание: Базовый комплекс для верха тела\n"+
			"1|3|12\n"+
			"4|4|8\n"+
			"7|3|15\n"+
			"9|3|10\n"+
			"2|4|12\n\n"+
			"ПРАВИЛА:\n"+
			"1. ВЫДАЙ СТРОГО ОТ 5 ДО 6 СТРОК С УПРАЖНЕНИЯМИ! Не используй весь список!\n"+
			"2. НИКАКИХ СКОБОК [ ] в ответе!\n"+
			"3. НИКАКИХ ДИАПАЗОНОВ (пиши 12, а не 8-12).\n"+
			"4. НИКАКОГО ТЕКСТА в цифрах (пиши 30, а не 30 сек).\n"+
			"5. Строго 3 числа через черту |",
		strings.TrimSpace(exercisesBuilder.String()),
	)

	payload := map[string]interface{}{
		"model":       "GigaChat",
		"temperature": 0.1,
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt},
			{"role": "user", "content": "Цель: " + userGoal},
		},
	}
	body, _ := json.Marshal(payload)

	req, _ := http.NewRequest("POST", "https://gigachat.devices.sberbank.ru/api/v1/chat/completions", bytes.NewBuffer(body))
	req.Header.Add("Content-Type", "application/json")
	req.Header.Add("Authorization", "Bearer "+token)

	res, err := s.Client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("сетевая ошибка GigaChat: %w", err)
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		errBody, _ := io.ReadAll(res.Body)
		return nil, fmt.Errorf("ошибка GigaChat %d: %s", res.StatusCode, string(errBody))
	}

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
	aiContent = strings.ReplaceAll(aiContent, "```text", "")
	aiContent = strings.ReplaceAll(aiContent, "```", "")

	// Вспомогательная функция, которая вытаскивает ПЕРВОЕ число из строки
	extractFirstNum := func(s string) (int, error) {
		var numStr string
		for _, r := range s {
			if r >= '0' && r <= '9' {
				numStr += string(r)
			} else if len(numStr) > 0 {
				break // Останавливаемся, как только цифры закончились
			}
		}
		if numStr == "" {
			return 0, fmt.Errorf("нет цифр")
		}
		return strconv.Atoi(numStr)
	}

	var finalRes AIWorkoutResponse
	lines := strings.Split(aiContent, "\n")

	for _, line := range lines {
		cleanLine := strings.ReplaceAll(line, "[", "")
		cleanLine = strings.ReplaceAll(cleanLine, "]", "")
		cleanLine = strings.TrimSpace(cleanLine)

		if cleanLine == "" {
			continue
		}

		if strings.HasPrefix(cleanLine, "Название:") {
			finalRes.Title = strings.TrimSpace(strings.TrimPrefix(cleanLine, "Название:"))
		} else if strings.HasPrefix(cleanLine, "Описание:") {
			finalRes.Description = strings.TrimSpace(strings.TrimPrefix(cleanLine, "Описание:"))
		} else {
			parts := strings.Split(cleanLine, "|")
			if len(parts) >= 3 {
				idStr := parts[0]
				setsStr := parts[len(parts)-2]
				repsStr := parts[len(parts)-1]

				id, err1 := extractFirstNum(idStr)
				sets, err2 := extractFirstNum(setsStr)
				reps, err3 := extractFirstNum(repsStr)

				if err1 != nil || err2 != nil || err3 != nil {
					continue
				}

				if realUUID, exists := shortToUUID[id]; exists {
					finalRes.Exercises = append(finalRes.Exercises, struct {
						ID   uuid.UUID `json:"id"`
						Sets int       `json:"sets"`
						Reps int       `json:"reps"`
					}{
						ID:   realUUID,
						Sets: sets,
						Reps: reps,
					})
				}
			}
		}
	}

	if finalRes.Title == "" || len(finalRes.Exercises) == 0 {
		return nil, fmt.Errorf("ИИ вернул пустой или неверный ответ: \n%s", aiContent)
	}

	return &finalRes, nil
}
