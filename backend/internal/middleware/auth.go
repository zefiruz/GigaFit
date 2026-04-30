package middleware

import (
	"context"
	"fmt"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type contextKey struct{}

var UserIDKey = contextKey{}

func AuthMiddleware(jwtSecret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {

			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}

			if !strings.HasPrefix(authHeader, "Bearer ") {
				http.Error(w, "invalid token format", http.StatusUnauthorized)
				return
			}

			tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
			if tokenStr == "" {
				http.Error(w, "empty token", http.StatusUnauthorized)
				return
			}

			token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
				if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, fmt.Errorf("invalid signing method")
				}
				return []byte(jwtSecret), nil
			})

			if err != nil || !token.Valid {
				http.Error(w, "invalid token", http.StatusUnauthorized)
				return
			}

			claims, ok := token.Claims.(jwt.MapClaims)
			if !ok {
				http.Error(w, "invalid token claims", http.StatusUnauthorized)
				return
			}

			// ================= user_id =================

			raw, ok := claims["user_id"]
			if !ok || raw == nil {
				http.Error(w, "missing user_id", http.StatusUnauthorized)
				return
			}

			var userID uuid.UUID

			switch v := raw.(type) {

			// если вдруг строка
			case string:
				uid, err := uuid.Parse(v)
				if err != nil {
					http.Error(w, "invalid user_id", http.StatusUnauthorized)
					return
				}
				userID = uid

			// если вдруг uuid.UUID (идеальный кейс)
			case uuid.UUID:
				userID = v

			default:
				http.Error(w, "invalid user_id type", http.StatusUnauthorized)
				return
			}

			if userID == uuid.Nil {
				http.Error(w, "invalid user_id", http.StatusUnauthorized)
				return
			}

			ctx := context.WithValue(r.Context(), UserIDKey, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}