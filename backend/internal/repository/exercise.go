package repository

import (
	"fmt"

	"gigafit/internal/models"

	"github.com/google/uuid"
	"github.com/lib/pq"
	"gorm.io/gorm"
)

type ExerciseRepository interface {
	CreateExercise(exercise *models.Exercise) error
	GetExerciseByID(id, userID uuid.UUID) (*models.Exercise, error)
	GetAllExercises(userID uuid.UUID) ([]models.Exercise, error)

	UpdateExercise(exercise *models.Exercise, userID uuid.UUID) error
	DeleteExercise(id, userID uuid.UUID) error
	GetExercisesByMuscleGroup(userID uuid.UUID, muscleGroups []string) ([]models.Exercise, error)

	GetUserExercises(userID uuid.UUID) ([]models.Exercise, error)
	GetSystemExercises() ([]models.Exercise, error)
	SearchExercises(userID uuid.UUID, query string) ([]models.Exercise, error)
	ExistsByIDs(ids []uuid.UUID) (map[uuid.UUID]bool, error)
}

type postgresExerciseRepository struct {
	db *gorm.DB
}

func NewExerciseRepository(db *gorm.DB) ExerciseRepository {
	return &postgresExerciseRepository{db: db}
}

func (r *postgresExerciseRepository) CreateExercise(exercise *models.Exercise) error {
	return r.db.Create(exercise).Error
}

func (r *postgresExerciseRepository) GetExerciseByID(id, userID uuid.UUID) (*models.Exercise, error) {
	var exercise models.Exercise

	err := r.db.
		Where("id = ? AND (user_id = ? OR status = ?)", id, userID, "system").
		First(&exercise).Error
	if err != nil {
		return nil, err
	}

	return &exercise, nil
}

func (r *postgresExerciseRepository) GetAllExercises(userID uuid.UUID) ([]models.Exercise, error) {
	var exercises []models.Exercise
	err := r.db.Where("user_id = ? OR status = ?", userID, "system").
		Order("status DESC").
		Find(&exercises).Error
	return exercises, err
}

func (r *postgresExerciseRepository) UpdateExercise(exercise *models.Exercise, userID uuid.UUID) error {
	result := r.db.Model(&models.Exercise{}).
		Where("id = ? AND user_id = ?", exercise.ID, userID).
		Updates(exercise)

	if result.Error != nil {
		return result.Error
	}

	if result.RowsAffected == 0 {
		return fmt.Errorf("нет прав для редактирования или упражнение не найдено")
	}

	return nil
}

func (r *postgresExerciseRepository) DeleteExercise(id uuid.UUID, userID uuid.UUID) error {
	result := r.db.Where("id = ? AND user_id = ?", id, userID).
		Delete(&models.Exercise{})

	if result.Error != nil {
		return result.Error
	}

	if result.RowsAffected == 0 {
		return fmt.Errorf("нет прав или упражнение не найдено")
	}

	return nil
}

func (r *postgresExerciseRepository) GetExercisesByMuscleGroup(userID uuid.UUID, muscleGroups []string) ([]models.Exercise, error) {
	var exercises []models.Exercise

	query := `
		(user_id = ? OR status = ?) AND (
			jsonb_exists_any(muscle_groups->'primary', ?) OR
			jsonb_exists_any(muscle_groups->'secondary', ?)
		)
	`

	err := r.db.
		Where(query, userID, "system", pq.Array(muscleGroups), pq.Array(muscleGroups)).
		Find(&exercises).Error

	return exercises, err
}

func (r *postgresExerciseRepository) GetUserExercises(userID uuid.UUID) ([]models.Exercise, error) {
	var exercises []models.Exercise

	err := r.db.
		Where("user_id = ?", userID).
		Find(&exercises).Error

	return exercises, err
}

func (r *postgresExerciseRepository) GetSystemExercises() ([]models.Exercise, error) {
	var exercises []models.Exercise

	err := r.db.Where("status = ?", "system").Find(&exercises).Error
	return exercises, err
}

func (r *postgresExerciseRepository) SearchExercises(userID uuid.UUID, query string) ([]models.Exercise, error) {
	var exercises []models.Exercise

	err := r.db.
		Where("(user_id = ? OR status = ?) AND name ILIKE ?", userID, "system", "%"+query+"%").
		Find(&exercises).Error

	return exercises, err
}

func (r *postgresExerciseRepository) ExistsByIDs(ids []uuid.UUID) (map[uuid.UUID]bool, error) {
	var exercises []models.Exercise

	err := r.db.Where("id IN ?", ids).Find(&exercises).Error
	if err != nil {
		return nil, err
	}

	result := make(map[uuid.UUID]bool)
	for _, ex := range exercises {
		result[ex.ID] = true
	}

	return result, nil
}
