package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"strings"

	"gigafit/internal/configs"
	"gigafit/internal/handler"
	"gigafit/internal/middleware"
	"gigafit/internal/models"
	"gigafit/internal/repository"
	"gigafit/service"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"github.com/redis/go-redis/v9"
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

		// fmt.Printf("Mux Register: [%s]\n", fullPattern) // Для отладки в консоли
		mux.Handle(fullPattern, finalHandler)
	}
}

func main() {
	cfg := configs.LoadConfig()

	db, err := gorm.Open(postgres.Open(cfg.DBDSN), &gorm.Config{
		// DisableForeignKeyConstraintWhenMigrating: true,
	})
	if err != nil {
		log.Fatal("Ошибка подключения к БД: ", err)
	}
	fmt.Println("Успешное подключение к PostgreSQL")

	err = db.AutoMigrate(
		&models.User{},
		&models.MeasurementLog{},
		&models.Exercise{},
		&models.Workout{},
		&models.WorkoutExercise{},
		&models.TrainingPlan{},
		&models.PlanWorkout{},
		&models.WorkoutLog{},
		&models.AIRequest{},
		&models.SavedWorkout{},
		&models.WorkoutLike{},
	)
	if err != nil {
		log.Fatal("Ошибка миграции таблиц: ", err)
	}

	rdb := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "",
		DB:       0,
	})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		log.Fatal("Ошибка подключения к Redis: ", err)
	}
	fmt.Println("Успешное подключение к Redis!")

	userRepo := repository.NewUserRepository(db)
	exerciseRepo := repository.NewExerciseRepository(db)
	workoutrepo := repository.NewWorkoutRepository(db)
	profileRepo := repository.NewProfileRepository(db)
	planRepo := repository.NewTrainingPlanRepository(db)
	logRepo := repository.NewLogRepository(db)
	communityRepo := repository.NewCommunityRepository(db)
	chatRepo := repository.NewChatRepository(db)

	aiService := service.NewGigaChatService(cfg.GigaChatSecret)

	authHandler := handler.NewAuthHandler(userRepo, cfg.JWTSecret)
	exerciseHandler := handler.NewExerciseHandler(exerciseRepo)
	workoutHandler := handler.NewWorkoutHandler(workoutrepo, exerciseRepo, aiService, *rdb)
	profileHandler := handler.NewProfileHandler(profileRepo, aiService)
	planHandler := handler.NewPlanHandler(planRepo, aiService, exerciseRepo, workoutrepo)
	logHandler := handler.NewLogHandler(logRepo, aiService)
	commHandler := handler.NewCommunityHandler(communityRepo)
	chatHandler := handler.NewChatHandler(chatRepo, profileRepo, aiService)

	mux := http.NewServeMux()

	public := RouteGroup(mux, "/api/v1")

	public("POST /auth/register", authHandler.Register)
	public("POST /auth/login", authHandler.Login)

	profile := RouteGroup(mux, "/api/v1", middleware.AuthMiddleware(cfg.JWTSecret))
	profile("GET /profile", profileHandler.GetProfile)
	profile("PUT /profile", profileHandler.UpdateProfile)
	profile("PUT /profile/anthropometry", profileHandler.UpdateAnthropometry)
	profile("GET /profile/progress", profileHandler.GetProgress)
	profile("GET /profile/stats", profileHandler.GetStats)
	profile("GET /profile/biometric-advice", profileHandler.GetBiometricAdvice)

	exercise := RouteGroup(mux, "/api/v1", middleware.AuthMiddleware(cfg.JWTSecret))

	exercise("GET /exercise/all", exerciseHandler.GetAllExercises)
	exercise("POST /exercise", exerciseHandler.CreateExercise)
	exercise("GET /exercise", exerciseHandler.GetExercisesByMuscleGroup)
	exercise("GET /exercise/{id}", exerciseHandler.GetExerciseByID)
	exercise("PUT /exercise/{id}", exerciseHandler.UpdateExercise)
	exercise("DELETE /exercise/{id}", exerciseHandler.DeleteExercise)

	workout := RouteGroup(mux, "/api/v1", middleware.AuthMiddleware(cfg.JWTSecret))

	workout("GET /workout/all", workoutHandler.GetAllWorkouts)
	workout("GET /workout/system", workoutHandler.GetSystemWorkouts)
	workout("POST /workout", workoutHandler.CreateManualWorkout)
	workout("GET /workout/{id}", workoutHandler.GetWorkoutByID)
	workout("PATCH /workout/{id}", workoutHandler.UpdateWorkoutMeta)
	workout("PUT /workout/{id}/exercises", workoutHandler.UpdateWorkoutExercises)
	workout("DELETE /workout/{id}", workoutHandler.DeleteWorkout)
	workout("POST /workout/ai", workoutHandler.CreateAIWorkout)

	plan := RouteGroup(mux, "/api/v1", middleware.AuthMiddleware(cfg.JWTSecret))

	plan("POST /plan", planHandler.CreateManualPlan)
	plan("POST /plan/ai", planHandler.CreateAIPlan)
	plan("GET /plan/all", planHandler.GetAllPlans)
	plan("GET /plan/system", planHandler.GetAllSystemPlans)
	plan("GET /plan/{id}", planHandler.GetPlanByID)
	plan("PATCH /plan/{id}", planHandler.UpdatePlan)
	plan("DELETE /plan/{id}", planHandler.DeletePlan)

	logs := RouteGroup(mux, "/api/v1", middleware.AuthMiddleware(cfg.JWTSecret))

	logs("POST /log", logHandler.CreateLog)
	logs("GET /log/all", logHandler.GetAllLogs)
	logs("POST /log/ai-advice", logHandler.GetAIAdviceAfterWorkout)

	comm := RouteGroup(mux, "/api/v1", middleware.AuthMiddleware(cfg.JWTSecret))

	comm("GET /community/feed", commHandler.GetFeed)
	comm("POST /community/publish/{id}", commHandler.PublishWorkout)
	comm("POST /community/like/{id}", commHandler.ToggleLike)
	comm("POST /community/save/{id}", commHandler.SaveWorkout)

	chat := RouteGroup(mux, "/api/v1", middleware.AuthMiddleware(cfg.JWTSecret))
	chat("POST /chat/message", chatHandler.SendMessage)
	chat("GET /chat/history", chatHandler.GetHistory)

	fmt.Println("Работает...")

	err = http.ListenAndServe(":8080", mux)
	if err != nil {
		panic(err)
	}
}
