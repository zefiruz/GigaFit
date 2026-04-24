package models

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
)

// JSONB — универсальная обертка для работы с jsonb в Postgres через GORM
type JSONB[T any] struct {
	Data T
}

func (j *JSONB[T]) Scan(value interface{}) error {
	bytes, ok := value.([]byte)
	if !ok {
		return errors.New("type assertion to []byte failed")
	}
	return json.Unmarshal(bytes, &j.Data)
}

func (j JSONB[T]) Value() (driver.Value, error) {
	return json.Marshal(j.Data)
}

// Переопределяем MarshalJSON, чтобы на фронт (Flutter) улетала
// чистая структура без лишнего поля "Data"
func (j JSONB[T]) MarshalJSON() ([]byte, error) {
	return json.Marshal(j.Data)
}

func (j *JSONB[T]) UnmarshalJSON(data []byte) error {
	return json.Unmarshal(data, &j.Data)
}
