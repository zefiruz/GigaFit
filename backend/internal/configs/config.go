package configs

import (
	"log"
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	DBDSN          string
	ServerPort     string
	JWTSecret      string
	GigaChatSecret string
}

func getEnv(key string) string {
	val := os.Getenv(key)
	return val
}

// LoadConfig загружает конфигурацию из переменных окружения и возвращает структуру Config.
func LoadConfig() *Config {
	_ = godotenv.Load(".env", "../.env", "../../.env")

	cfg := &Config{
		DBDSN:          getEnv("DB_DSN"),
		ServerPort:     getEnv("SERVER_PORT"),
		JWTSecret:      getEnv("JWT_SECRET"),
		GigaChatSecret: getEnv("GIGACHAT_SECRET"),
	}

	if cfg.DBDSN == "" {
		log.Fatal("Критическая ошибка: DBDSN не установлен")
	}
	if cfg.JWTSecret == "" {
		log.Fatal("Критическая ошибка: JWT_SECRET не установлен")
	}
	if cfg.GigaChatSecret == "" {
		log.Fatal("Критическая ошибка: GIGA_CHAT_SECRET не установлен")
	}

	return cfg
}
