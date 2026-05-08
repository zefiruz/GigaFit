package service

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
)

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
