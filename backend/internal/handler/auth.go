package handler

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"net/mail"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/zefiruz/GigaFit/backend/internal/models"
	"github.com/zefiruz/GigaFit/backend/internal/repository"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type AuthHandler struct {
	Repo          repository.UserRepository
	JWTSecret     string
	TokenTTLHours int // Время жизни токена в часах (по умолчанию 24)
}

func NewAuthHandler(repo repository.UserRepository, jwtSecret string) *AuthHandler {
	return &AuthHandler{
		Repo:          repo,
		JWTSecret:     jwtSecret,
		TokenTTLHours: 24,
	}
}

// validateEmail проверяет корректность email-адреса
func validateEmail(email string) error {
	email = strings.TrimSpace(email)
	if email == "" {
		return errors.New("email не может быть пустым")
	}

	_, err := mail.ParseAddress(email)
	if err != nil {
		return errors.New("некорректный формат email")
	}

	if len(email) > 254 {
		return errors.New("email слишком длинный")
	}

	return nil
}

// validatePassword проверяет требования к паролю
func validatePassword(password string) error {
	if len(password) < 6 {
		return errors.New("пароль должен быть минимум 6 символов")
	}

	if len(password) > 128 {
		return errors.New("пароль слишком длинный")
	}

	return nil
}

// validateUsername проверяет требования к имени пользователя
func validateUsername(username string) error {
	username = strings.TrimSpace(username)
	if username == "" {
		return errors.New("имя пользователя не может быть пустым")
	}

	if len(username) < 3 {
		return errors.New("имя пользователя должно быть минимум 3 символа")
	}

	if len(username) > 50 {
		return errors.New("имя пользователя слишком длинное")
	}

	return nil
}

func (h *AuthHandler) generateToken(userID string) (string, error) {
	if h.JWTSecret == "" {
		return "", errors.New("JWT secret не установлен")
	}

	claims := jwt.MapClaims{
		"user_id": userID,
		"exp":     time.Now().Add(time.Hour * time.Duration(h.TokenTTLHours)).Unix(),
		"iat":     time.Now().Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

	return token.SignedString([]byte(h.JWTSecret))
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Username string `json:"username"`
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		http.Error(w, "Некорректный JSON", http.StatusBadRequest)
		return
	}

	// Валидация username
	if err := validateUsername(input.Username); err != nil {
		http.Error(w, "Ошибка имени пользователя: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Валидация email
	if err := validateEmail(input.Email); err != nil {
		http.Error(w, "Ошибка email: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Валидация пароля
	if err := validatePassword(input.Password); err != nil {
		http.Error(w, "Ошибка пароля: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Нормализуем email (приводим к нижнему регистру)
	input.Email = strings.ToLower(strings.TrimSpace(input.Email))

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("Ошибка при хешировании пароля: %v", err)
		http.Error(w, "Ошибка при обработке пароля", http.StatusInternalServerError)
		return
	}

	userID := uuid.New()

	newUser := models.User{
		ID:           userID,
		Username:     strings.TrimSpace(input.Username),
		Email:        input.Email,
		PasswordHash: string(hashedPassword),
	}

	err = h.Repo.CreateUser(&newUser)
	if err != nil {
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "UNIQUE") {
			http.Error(w, "Email или имя пользователя уже занято", http.StatusConflict)
			return
		}
		log.Printf("Ошибка при создании пользователя: %v", err)
		http.Error(w, "Ошибка регистрации", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	if err := json.NewEncoder(w).Encode(map[string]string{
		"status":  "success",
		"message": "Пользователь успешно зарегистрирован",
		"user_id": userID.String(),
	}); err != nil {
		log.Printf("Ошибка при кодировании ответа: %v", err)
	}
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		http.Error(w, "Некорректный JSON", http.StatusBadRequest)
		return
	}

	// Валидация email
	if err := validateEmail(input.Email); err != nil {
		http.Error(w, "Неверный email или пароль", http.StatusUnauthorized)
		return
	}

	if input.Password == "" {
		http.Error(w, "Неверный email или пароль", http.StatusUnauthorized)
		return
	}

	// Нормализуем email
	email := strings.ToLower(strings.TrimSpace(input.Email))

	user, err := h.Repo.GetUserByEmail(email)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			// Не раскрываем, что email не найден (для безопасности)
			http.Error(w, "Неверный email или пароль", http.StatusUnauthorized)
			return
		}

		log.Printf("Ошибка БД при логине: %v", err)
		http.Error(w, "Ошибка сервера", http.StatusInternalServerError)
		return
	}

	err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(input.Password))
	if err != nil {
		http.Error(w, "Неверный email или пароль", http.StatusUnauthorized)
		return
	}

	token, err := h.generateToken(user.ID.String())
	if err != nil {
		log.Printf("Ошибка при генерации токена: %v", err)
		http.Error(w, "Ошибка токена", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(map[string]interface{}{
		"token": token,
		"user": map[string]string{
			"id":    user.ID.String(),
			"email": user.Email,
		},
	}); err != nil {
		log.Printf("Ошибка при кодировании ответа логина: %v", err)
	}
}
