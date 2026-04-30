package handler

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"net/mail"
	"strings"
	"time"

	"gigafit/internal/models"
	"gigafit/internal/repository"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// ================= HANDLER =================

type AuthHandler struct {
	Repo          repository.UserRepository
	JWTSecret     string
	TokenTTLHours int
}

func NewAuthHandler(repo repository.UserRepository, jwtSecret string) *AuthHandler {
	return &AuthHandler{
		Repo:          repo,
		JWTSecret:     jwtSecret,
		TokenTTLHours: 24,
	}
}

// ================= HELPERS =================

func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

func normalizeUsername(username string) string {
	return strings.TrimSpace(username)
}

func getError(err error) string {
	if err == nil {
		return ""
	}
	return err.Error()
}

// ================= VALIDATION =================

func validateEmail(email string) error {
	email = strings.TrimSpace(email)
	if email == "" {
		return errors.New("email не может быть пустым")
	}

	if _, err := mail.ParseAddress(email); err != nil {
		return errors.New("некорректный email")
	}

	if len(email) > 254 {
		return errors.New("email слишком длинный")
	}

	return nil
}

func validatePassword(password string) error {
	if len(password) < 8 {
		return errors.New("пароль минимум 8 символов")
	}

	var hasLetter, hasNumber bool

	for _, c := range password {
		switch {
		case (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'):
			hasLetter = true
		case c >= '0' && c <= '9':
			hasNumber = true
		}
	}

	if !hasLetter || !hasNumber {
		return errors.New("пароль должен содержать буквы и цифры")
	}

	return nil
}

func validateUsername(username string) error {
	username = strings.TrimSpace(username)

	if username == "" {
		return errors.New("username обязателен")
	}

	if len(username) < 3 {
		return errors.New("минимум 3 символа")
	}

	if len(username) > 50 {
		return errors.New("слишком длинный username")
	}

	return nil
}

// ================= JWT =================

func (h *AuthHandler) generateToken(userID uuid.UUID) (string, error) {
	if h.JWTSecret == "" {
		return "", errors.New("JWT secret не установлен")
	}

	claims := jwt.MapClaims{
		"user_id": userID,
		"exp":     time.Now().Add(time.Hour * time.Duration(h.TokenTTLHours)).Unix(),
		"iat":     time.Now().Unix(),
		"iss":     "gigafit",
		"aud":     "gigafit-client",
		"role":    "user",
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(h.JWTSecret))
}

// ================= REGISTER =================

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Username string `json:"username"`
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{
			Status:  "error",
			Message: "invalid json",
		})
		return
	}

	input.Username = normalizeUsername(input.Username)
	input.Email = normalizeEmail(input.Email)

	if err := validateUsername(input.Username); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: err.Error()})
		return
	}

	if err := validateEmail(input.Email); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: err.Error()})
		return
	}

	if err := validatePassword(input.Password); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: err.Error()})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost+1)
	if err != nil {
		log.Println("bcrypt error:", err)
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "server error"})
		return
	}

	user := models.User{
		ID:           uuid.New(),
		Username:     input.Username,
		Email:        input.Email,
		PasswordHash: string(hash),
	}

	if err := h.Repo.CreateUser(&user); err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			writeJSON(w, http.StatusConflict, Response{
				Status:  "error",
				Message: "email or username already exists",
			})
			return
		}

		log.Println("create user error:", err)
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "server error"})
		return
	}

	writeJSON(w, http.StatusCreated, Response{
		Status:  "success",
		Message: "user created",
		Data: map[string]string{
			"user_id": user.ID.String(),
		},
	})
}

// ================= LOGIN =================

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Status: "error", Message: "invalid json"})
		return
	}

	input.Email = normalizeEmail(input.Email)

	if err := validateEmail(input.Email); err != nil {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "invalid credentials"})
		return
	}

	if input.Password == "" {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "invalid credentials"})
		return
	}

	user, err := h.Repo.GetUserByEmail(input.Email)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "invalid credentials"})
			return
		}

		log.Println("db error:", err)
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "server error"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(input.Password)); err != nil {
		writeJSON(w, http.StatusUnauthorized, Response{Status: "error", Message: "invalid credentials"})
		return
	}

	token, err := h.generateToken(user.ID)
	if err != nil {
		log.Println("token error:", err)
		writeJSON(w, http.StatusInternalServerError, Response{Status: "error", Message: "server error"})
		return
	}

	writeJSON(w, http.StatusOK, Response{
		Status: "success",
		Data: map[string]interface{}{
			"token": token,
			"user": map[string]string{
				"id":    user.ID.String(),
				"email": user.Email,
			},
		},
	})
}
