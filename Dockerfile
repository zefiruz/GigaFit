FROM golang:1.22-alpine

WORKDIR /app

COPY backend/ ./

RUN go mod download

RUN go build -o gigafit-app ./cmd/api/main.go

EXPOSE 8080

CMD ["./gigafit-app"]