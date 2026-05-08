package repository

import (
	"time"

	"gigafit/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type ProfileRepository interface {
	GetProfileByID(id uuid.UUID) (*models.User, error)
	UpdateProfile(userID uuid.UUID, username string, avatarURL string) error
	UpdateAnthropometry(userID uuid.UUID, height, weight float64, goal string) error
	GetProgress(userID uuid.UUID) ([]models.MeasurementLog, error)
	GetStats(userID uuid.UUID) (*models.UserStats, error)
}

type postgresProfileRepository struct {
	db *gorm.DB
}

func NewProfileRepository(db *gorm.DB) ProfileRepository {
	return &postgresProfileRepository{db: db}
}

func (r *postgresProfileRepository) GetProfileByID(id uuid.UUID) (*models.User, error) {
	var user models.User

	err := r.db.Where("id = ?", id).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *postgresProfileRepository) UpdateProfile(userID uuid.UUID, username string, avatarURL string) error {
    return r.db.Model(&models.User{}).Where("id = ?", userID).Updates(map[string]interface{}{
        "username":   username,
        "avatar_url": avatarURL,
    }).Error
}

func (r *postgresProfileRepository) UpdateAnthropometry(userID uuid.UUID, height, weight float64, goal string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		var user models.User
		if err := tx.Where("id = ?", userID).First(&user).Error; err != nil {
			return err
		}

		updates := map[string]interface{}{
			"goal": goal,
		}

		if user.InitialWeight == 0 {
			updates["initial_weight"] = weight
			updates["initial_height"] = height
		}

		if err := tx.Model(&user).Updates(updates).Error; err != nil {
			return err
		}

		log := models.MeasurementLog{
			ID:        uuid.New(),
			UserID:    userID,
			Weight:    weight,
			Height:    height,
			CreatedAt: time.Now(),
		}

		return tx.Create(&log).Error
	})
}

func (r *postgresProfileRepository) GetProgress(userID uuid.UUID) ([]models.MeasurementLog, error) {
	var logs []models.MeasurementLog
	err := r.db.Where("user_id = ?", userID).Order("created_at asc").Find(&logs).Error
	return logs, err
}

func (r *postgresProfileRepository) GetStats(userID uuid.UUID) (*models.UserStats, error) {
	var user models.User

	err := r.db.Select("cached_stats").Where("id = ?", userID).First(&user).Error
	if err != nil {
		return nil, err
	}

	return &user.CachedStats.Data, nil
}
