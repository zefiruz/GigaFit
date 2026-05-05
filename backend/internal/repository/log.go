package repository

import (
	"gigafit/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type LogRepository interface {
	CreateLog(log *models.WorkoutLog) error
	GetAllLogs(userID uuid.UUID) ([]models.WorkoutLog, error)
}

type postgresLogRepository struct {
	db *gorm.DB
}

func NewLogRepository(db *gorm.DB) LogRepository {
	return &postgresLogRepository{db: db}
}

func (r *postgresLogRepository) CreateLog(log *models.WorkoutLog) error {
	return r.db.Create(log).Error
}

func (r *postgresLogRepository) GetAllLogs(userID uuid.UUID) ([]models.WorkoutLog, error) {
	var logs []models.WorkoutLog
	// Достаем от новых к старым
	err := r.db.Where("user_id = ?", userID).Order("created_at desc").Find(&logs).Error
	return logs, err
}