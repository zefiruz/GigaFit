package repository

import (
	"gigafit/internal/models"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type ChatRepository interface {
	SaveInteraction(interaction *models.AIRequest) error
	GetSessionHistory(userID, sessionID uuid.UUID) ([]models.AIRequest, error)
}

type postgresChatRepository struct {
	db *gorm.DB
}

func NewChatRepository(db *gorm.DB) ChatRepository {
	return &postgresChatRepository{db: db}
}

func (r *postgresChatRepository) SaveInteraction(interaction *models.AIRequest) error {
	return r.db.Create(interaction).Error
}

func (r *postgresChatRepository) GetSessionHistory(userID, sessionID uuid.UUID) ([]models.AIRequest, error) {
	var history []models.AIRequest
	// Сортируем по времени создания, чтобы передать ИИ правильную хронологию
	err := r.db.Where("user_id = ? AND session_id = ?", userID, sessionID).
		Order("created_at asc").
		Find(&history).Error
	return history, err
}