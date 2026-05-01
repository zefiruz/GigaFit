package repository

import (
	"gigafit/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type WorkoutRepository interface {
	CreateWorkout(workout *models.Workout) error
	GetWorkoutByID(id uuid.UUID) (*models.Workout, error)
	GetAllWorkouts(userID uuid.UUID) ([]models.Workout, error)
	UpdateWorkoutMeta(workoutID uuid.UUID, userID uuid.UUID, updates map[string]interface{}) error
	ReplaceWorkoutExercises(workoutID uuid.UUID, userID uuid.UUID, exercises []models.WorkoutExercise) error
	DeleteWorkout(id uuid.UUID, userID uuid.UUID) error

	IsOwner(workoutID, userID uuid.UUID) (bool, error)
	GetAIWorkouts(userID uuid.UUID) ([]models.Workout, error)
	GetPublicWorkouts() ([]models.Workout, error)
	SearchWorkouts(userID uuid.UUID, query string) ([]models.Workout, error)
}

type postgresWorkoutRepository struct {
	db *gorm.DB
}

func NewWorkoutRepository(db *gorm.DB) WorkoutRepository {
	return &postgresWorkoutRepository{db: db}
}

func (r *postgresWorkoutRepository) CreateWorkout(workout *models.Workout) error {
	return r.db.Create(workout).Error
}

// func (r *postgresWorkoutRepository) GetWorkoutByID(id uuid.UUID) (*models.Workout, error) {
// 	var workout models.Workout
// 	if err := r.db.Where("id = ?", id).First(&workout).Error; err != nil {
// 		return nil, err
// 	}
// 	return &workout, nil
// }

func (r *postgresWorkoutRepository) GetWorkoutByID(id uuid.UUID) (*models.Workout, error) {
	var workout models.Workout

	err := r.db.
		Preload("Exercises").
		Where("id = ?", id).
		First(&workout).Error
	if err != nil {
		return nil, err
	}

	return &workout, nil
}

func (r *postgresWorkoutRepository) GetAllWorkouts(userID uuid.UUID) ([]models.Workout, error) {
	var workouts []models.Workout

	err := r.db.Where("user_id = ? OR is_system = ?", userID, true).
		Order("is_system DESC, created_at DESC").
		Find(&workouts).Error

	return workouts, err
}

func (r *postgresWorkoutRepository) UpdateWorkoutMeta(
	workoutID uuid.UUID,
	userID uuid.UUID,
	updates map[string]interface{},
) error {
	return r.db.Model(&models.Workout{}).
		Where("id = ? AND author_id = ?", workoutID, userID).
		Updates(updates).Error
}

func (r *postgresWorkoutRepository) ReplaceWorkoutExercises(
	workoutID uuid.UUID,
	userID uuid.UUID,
	exercises []models.WorkoutExercise,
) error {
	tx := r.db.Begin()

	// проверка владельца
	var workout models.Workout
	if err := tx.Where("id = ? AND author_id = ?", workoutID, userID).
		First(&workout).Error; err != nil {
		tx.Rollback()
		return err
	}

	// удаляем старые
	if err := tx.Where("workout_id = ?", workoutID).
		Delete(&models.WorkoutExercise{}).Error; err != nil {
		tx.Rollback()
		return err
	}

	// вставляем новые
	for i := range exercises {
		exercises[i].ID = uuid.New()
		exercises[i].WorkoutID = workoutID
		exercises[i].OrderIndex = i
	}

	if len(exercises) > 0 {
		if err := tx.Create(&exercises).Error; err != nil {
			tx.Rollback()
			return err
		}
	}

	return tx.Commit().Error
}

func (r *postgresWorkoutRepository) DeleteWorkout(id uuid.UUID, userID uuid.UUID) error {
	result := r.db.Where("id = ? AND user_id = ?", id, userID).Delete(&models.Workout{})

	if result.Error != nil {
		return result.Error
	}

	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}

	return nil
}

func (r *postgresWorkoutRepository) IsOwner(workoutID, userID uuid.UUID) (bool, error) {
	var count int64

	err := r.db.Model(&models.Workout{}).
		Where("id = ? AND user_id = ?", workoutID, userID).
		Count(&count).Error

	return count > 0, err
}

func (r *postgresWorkoutRepository) GetAIWorkouts(userID uuid.UUID) ([]models.Workout, error) {
	var workouts []models.Workout

	err := r.db.
		Where("user_id = ? AND is_ai_generated = ?", userID, true).
		Find(&workouts).Error

	return workouts, err
}

func (r *postgresWorkoutRepository) GetPublicWorkouts() ([]models.Workout, error) {
	var workouts []models.Workout

	err := r.db.Where("is_public = ?", true).Find(&workouts).Error

	return workouts, err
}

func (r *postgresWorkoutRepository) SearchWorkouts(userID uuid.UUID, query string) ([]models.Workout, error) {
	var workouts []models.Workout

	err := r.db.
		Where("user_id = ? AND title ILIKE ?", userID, "%"+query+"%").
		Find(&workouts).Error

	return workouts, err
}
