package middleware

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
)

type contextKey string

const (
	UserIDKey contextKey = "userID"
)

func AuthMiddleware(jwtSecret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				http.Error(w, "Отсутствует токен", http.StatusUnauthorized)
				return
			}

			// Проверяем, что header начинается с "Bearer "
			if !strings.HasPrefix(authHeader, "Bearer ") {
				http.Error(w, "Неверный формат токена", http.StatusUnauthorized)
				return
			}

			tokenStr := strings.TrimPrefix(authHeader, "Bearer ")

			// Проверяем, не пуст ли сам токен
			if tokenStr == "" {
				http.Error(w, "Токен не может быть пустым", http.StatusUnauthorized)
				return
			}

			token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
				if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, fmt.Errorf("неверный алгоритм подписи: %v", token.Header["alg"])
				}
				return []byte(jwtSecret), nil
			})
			if err != nil {
				log.Printf("Ошибка парсинга токена: %v", err)
				http.Error(w, "Неверный токен", http.StatusUnauthorized)
				return
			}

			if !token.Valid {
				http.Error(w, "Неверный токен", http.StatusUnauthorized)
				return
			}

			claims, ok := token.Claims.(jwt.MapClaims)
			if !ok {
				http.Error(w, "Неверный формат токена", http.StatusUnauthorized)
				return
			}

			// Проверяем наличие и тип userID
			userIDRaw, exists := claims["user_id"]
			if !exists || userIDRaw == nil {
				http.Error(w, "Токен не содержит user_id", http.StatusUnauthorized)
				return
			}

			userID, ok := userIDRaw.(string)
			if !ok {
				http.Error(w, "Неверный формат user_id в токене", http.StatusUnauthorized)
				return
			}

			if userID == "" {
				http.Error(w, "user_id не может быть пустым", http.StatusUnauthorized)
				return
			}

			ctx := context.WithValue(r.Context(), UserIDKey, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
