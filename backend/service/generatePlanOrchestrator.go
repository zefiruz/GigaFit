package service

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/google/uuid"
)

type AIPlanResponse struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Workouts    []struct {
		DayNumber int    `json:"day_number"` // День недели (например, 1, 3, 5)
		Title     string `json:"title"`      // Название конкретной тренировки (напр., "День ног")
		Exercises []struct {
			ID   uuid.UUID `json:"id"`
			Sets int       `json:"sets"`
			Reps int       `json:"reps"`
		} `json:"exercises"`
	} `json:"workouts"`
}

func (s *gigaChatService) GeneratePlanOrchestrator(userGoal string, daysPerWeek int) (*PlanBlueprint, error) {
	token, err := s.getAccessToken()
	if err != nil {
		return nil, err
	}

	var workoutsList strings.Builder
	for i := 1; i <= daysPerWeek; i++ {
		workoutsList.WriteString(fmt.Sprintf("Тренировка %d: [Фокус %d]\n", i, i))
	}
	// 1. Просим ИИ вернуть Название, Описание и список дней в виде обычного текста
	systemPrompt := fmt.Sprintf(
		"Ты элитный фитнес-тренер. Клиент хочет: '%s'. Разбей эту цель на %d тренировок.\n"+
			"ОТВЕЧАЙ СТРОГО В ТАКОМ ФОРМАТЕ (каждый пункт с новой строки, без markdown и без JSON):\n"+
			"Название: [Придумай крутое, цепляющее название плану]\n"+
			"Описание: [Напиши 1-2 мотивирующих предложения о плане]\n"+
			"%s",
		userGoal, daysPerWeek, strings.TrimSpace(workoutsList.String()),
	)

	payload := map[string]interface{}{
		"model":       "GigaChat",
		"temperature": 0.5,
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
