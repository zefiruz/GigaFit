# 1. Берем официальный образ Go
FROM golang:1.25.3-alpine

# 2. Создаем главную папку на сервере
WORKDIR /app

# 3. Копируем твою папку backend внутрь сервера
COPY backend/ ./backend/

# 4. ПЕРЕХОДИМ в папку бэкенда (где лежит go.mod)
WORKDIR /app/backend

# 5. Скачиваем зависимости
RUN go mod download

# 6. Собираем приложение
RUN go build -o gigafit-app ./cmd/api/main.go

# 7. Открываем порт
EXPOSE 8080

# 8. Запускаем!
CMD ["./gigafit-app"]