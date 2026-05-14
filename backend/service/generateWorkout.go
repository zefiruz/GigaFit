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

	// 1. ОПТИМИЗАЦИЯ: Builder + Короткие ID
	shortToUUID := make(map[int]uuid.UUID)
	var exercisesBuilder strings.Builder

	counter := 1
	for id, name := range availableExercises {
		shortToUUID[counter] = id
		exercisesBuilder.WriteString(fmt.Sprintf("%d: %s\n", counter, name))
		counter++
	}

	// 2. УЛЬТРА-КОРОТКИЙ ПРОМПТ
	systemPrompt := fmt.Sprintf(
		"Ты тренер. Составь тренировку (5-6 упр) из списка:\n%s\n"+
			"ОТВЕЧАЙ СТРОГО ПО ШАБЛОНУ (без лишних слов):\n"+
			"Название: [Крутое название]\n"+
			"Описание: [Коротко о фокусе]\n"+
			"[ID упражнения]|[Подходы]|[Повторения]\n"+
			"[ID]|[Подходы]|[Повторения]",
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

	// 3. ПАРСИНГ МИКРО-ФОРМАТА
	var finalRes AIWorkoutResponse
	lines := strings.Split(aiContent, "\n")

	for _, line := range lines {
		cleanLine := strings.TrimSpace(line)
		if cleanLine == "" {
			continue
		}

		if strings.HasPrefix(cleanLine, "Название:") {
			finalRes.Title = strings.TrimSpace(strings.TrimPrefix(cleanLine, "Название:"))
		} else if strings.HasPrefix(cleanLine, "Описание:") {
			finalRes.Description = strings.TrimSpace(strings.TrimPrefix(cleanLine, "Описание:"))
		} else {
			// Ожидаем строку вида "1|3|12"
			parts := strings.Split(cleanLine, "|")
			if len(parts) == 3 {
				// Конвертируем строки в числа
				id, err1 := strconv.Atoi(strings.TrimSpace(parts[0]))
				sets, err2 := strconv.Atoi(strings.TrimSpace(parts[1]))
				reps, err3 := strconv.Atoi(strings.TrimSpace(parts[2]))

				// Если ИИ ошибся и выдал текст вместо цифр — игнорируем эту строчку
				if err1 != nil || err2 != nil || err3 != nil {
					continue
				}

				// Восстанавливаем UUID
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

	// Базовая проверка, что ИИ выдал хоть что-то адекватное
	if finalRes.Title == "" || len(finalRes.Exercises) == 0 {
		return nil, fmt.Errorf("ИИ вернул пустой или неверный ответ: \n%s", aiContent)
	}

	return &finalRes, nil
}
