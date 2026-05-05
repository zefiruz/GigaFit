package repository

import (
	"gigafit/internal/models"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type CommunityRepository interface {
	GetFeed(userID uuid.UUID) ([]models.Workout, error)
	PublishWorkout(workoutID uuid.UUID, userID uuid.UUID) error
	ToggleLike(workoutID uuid.UUID, userID uuid.UUID) (bool, error) // Возвращает true если лайк поставлен
	SaveWorkout(workoutID uuid.UUID, userID uuid.UUID) error
}

type postgresCommunityRepository struct {
	db *gorm.DB
}

func NewCommunityRepository(db *gorm.DB) CommunityRepository {
	return &postgresCommunityRepository{db: db}
}

func (r *postgresCommunityRepository) GetFeed(userID uuid.UUID) ([]models.Workout, error) {
	var workouts []models.Workout
	// Загружаем публичные тренировки других пользователей + подгружаем упражнения
	err := r.db.Where("is_public = ? AND author_id != ?", true, userID).
		Preload("Exercises.Exercise").
		Order("created_at desc").
		Limit(50).
		Find(&workouts).Error
	return workouts, err
}

func (r *postgresCommunityRepository) PublishWorkout(workoutID uuid.UUID, userID uuid.UUID) error {
	return r.db.Model(&models.Workout{}).
		Where("id = ? AND author_id = ?", workoutID, userID).
		Update("is_public", true).Error
}

func (r *postgresCommunityRepository) ToggleLike(workoutID uuid.UUID, userID uuid.UUID) (bool, error) {
	var like models.WorkoutLike
	result := r.db.Where("user_id = ? AND workout_id = ?", userID, workoutID).First(&like)

	if result.Error == gorm.ErrRecordNotFound {
		// Лайка нет — создаем и увеличиваем счетчик в транзакции
		err := r.db.Transaction(func(tx *gorm.DB) error {
			if err := tx.Create(&models.WorkoutLike{UserID: userID, WorkoutID: workoutID}).Error; err != nil {
				return err
			}
			return tx.Model(&models.Workout{}).Where("id = ?", workoutID).
				UpdateColumn("likes_count", gorm.Expr("likes_count + ?", 1)).Error
		})
		return true, err
	}

	// Лайк есть — удаляем и уменьшаем счетчик
	err := r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Delete(&like).Error; err != nil {
			return err
		}
		return tx.Model(&models.Workout{}).Where("id = ?", workoutID).
			UpdateColumn("likes_count", gorm.Expr("likes_count - ?", 1)).Error
	})
	return false, err
}

func (r *postgresCommunityRepository) SaveWorkout(workoutID uuid.UUID, userID uuid.UUID) error {
	return r.db.FirstOrCreate(&models.SavedWorkout{
		UserID:    userID,
		WorkoutID: workoutID,
	}).Error
}