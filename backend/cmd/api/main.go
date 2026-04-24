package main

import (
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/zefiruz/GigaFit/backend/internal/configs"
	"github.com/zefiruz/GigaFit/backend/internal/handler"
	"github.com/zefiruz/GigaFit/backend/internal/middleware"
	"github.com/zefiruz/GigaFit/backend/internal/models"
	"github.com/zefiruz/GigaFit/backend/internal/repository"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func RouteGroup(mux *http.ServeMux, prefix string, middlewares ...func(http.Handler) http.Handler) func(string, http.HandlerFunc) {
	return func(pattern string, handler http.HandlerFunc) {
		var finalHandler http.Handler = handler
		// Накладываем middleware в обратном порядке
		for i := len(middlewares) - 1; i >= 0; i-- {
			finalHandler = middlewares[i](finalHandler)
		}
		mux.Handle(prefix+pattern, finalHandler)
	}
}

func main() {
	cfg := configs.LoadConfig()

	db, err := gorm.Open(postgres.Open(cfg.DBDSN), &gorm.Config{
		DisableForeignKeyConstraintWhenMigrating: true,
	})
	if err != nil {
		log.Fatal("Ошибка подключения к БД: ", err)
	}
	fmt.Println("Успешное подключение к PostgreSQL")

	err = db.AutoMigrate(
		&models.User{},
		&models.Exercise{},
		&models.Workout{},
		&models.WorkoutExercise{},
		&models.TrainingPlan{},
		&models.PlanWorkout{},
		&models.WorkoutLog{},
		&models.AIRequest{},
	)
	if err != nil {
		log.Fatal("Ошибка миграции таблиц: ", err)
	}

	userRepo := repository.NewUserRepository(db)

	authHandler := handler.NewAuthHandler(userRepo, cfg.JWTSecret)

	mux := http.NewServeMux()

	mux.HandleFunc("POST /api/v1/auth/register", authHandler.Register)
	mux.HandleFunc("POST /api/v1/auth/login", authHandler.Login)

	_ = RouteGroup(mux, "/api/v1", middleware.AuthMiddleware(cfg.JWTSecret))

	mux.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, "pong")
	})

	fmt.Println("Работает...")

	err = http.ListenAndServe(":8080", mux)
	if err != nil {
		panic(err)
	}
}
