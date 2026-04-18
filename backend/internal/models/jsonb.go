package models

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
)

type JSONB[T any] struct {
	Data T
}

// Scan реализует интерфейс sql.Scanner (чтение ИЗ базы)
func (j *JSONB[T]) Scan(value any) error {
	if value == nil {
		return nil
	}

	bytes, ok := value.([]byte)
	if !ok {
		return fmt.Errorf("type assertion to []byte failed, got %T", value)
	}

	return json.Unmarshal(bytes, &j.Data)
}

// Value реализует интерфейс driver.Valuer (запись В базу)
func (j JSONB[T]) Value() (driver.Value, error) {
	return json.Marshal(j.Data)
}

// Эти методы делают JSON "плоским" для Flutter/API
func (j JSONB[T]) MarshalJSON() ([]byte, error) {
	return json.Marshal(j.Data)
}

func (j *JSONB[T]) UnmarshalJSON(data []byte) error {
	return json.Unmarshal(data, &j.Data)
}
