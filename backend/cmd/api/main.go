package main

import (
	"fmt"
	"log"
	"net/http"
	"strings"

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
        for i := len(middlewares) - 1; i >= 0; i-- {
            finalHandler = middlewares[i](finalHandler)
        }

        // Чистим паттерн от лишних пробелов по краям
        pattern = strings.TrimSpace(pattern)
        parts := strings.SplitN(pattern, " ", 2)
        
        var fullPattern string
        if len(parts) == 2 {
            method := parts[0]
            // Убираем возможные лишние пробелы внутри пути
            path := strings.TrimSpace(parts[1]) 
            fullPattern = fmt.Sprintf("%s %s%s", method, prefix, path)
        } else {
            fullPattern = prefix + pattern
        }

        fmt.Printf("Mux Register: [%s]\n", fullPattern) // Для отладки в консоли
        mux.Handle(fullPattern, finalHandler)
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
	exerciseRepo := repository.NewExerciseRepository(db)

	authHandler := handler.NewAuthHandler(userRepo, cfg.JWTSecret)
	exerciseHandler := handler.NewExerciseHandler(exerciseRepo)

	mux := http.NewServeMux()

	public := RouteGroup(mux, "/api/v1")

	public("POST /auth/register", authHandler.Register)
	public("POST /auth/login", authHandler.Login)

	exercise := RouteGroup(mux, "/api/v1", middleware.AuthMiddleware(cfg.JWTSecret))

	exercise("GET /exercise/all", exerciseHandler.GetAllExercises)
	exercise("POST /exercise", exerciseHandler.CreateExercise)
	exercise("GET /exercise", exerciseHandler.GetExercisesByMuscleGroup)
	exercise("GET /exercise/{id}", exerciseHandler.GetExerciseByID)
	exercise("PUT /exercise/{id}", exerciseHandler.UpdateExercise)
	exercise("DELETE /exercise/{id}", exerciseHandler.DeleteExercise)

	fmt.Println("Работает...")

	err = http.ListenAndServe(":8080", mux)
	if err != nil {
		panic(err)
	}
}
