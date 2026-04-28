package repository

import (
	"github.com/google/uuid"
	"github.com/lib/pq"
	"github.com/zefiruz/GigaFit/backend/internal/models"
	"gorm.io/gorm"
)

type ExerciseRepository interface {
	CreateExercise(exercise *models.Exercise) error
	GetExerciseByID(id uuid.UUID) (*models.Exercise, error)
	GetAllExercises() ([]models.Exercise, error)

	UpdateExercise(exercise *models.Exercise) error
	DeleteExercise(id uuid.UUID, userID uuid.UUID) error
	GetExercisesByMuscleGroup(muscleGroups []string) ([]models.Exercise, error)
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

func (r *postgresExerciseRepository) GetExerciseByID(id uuid.UUID) (*models.Exercise, error) {
	var exercise models.Exercise

	err := r.db.Where("id = ?", id).First(&exercise).Error
	if err != nil {
		return nil, err
	}
	return &exercise, nil
}

func (r *postgresExerciseRepository) GetAllExercises() ([]models.Exercise, error) {
	var exercises []models.Exercise

	err := r.db.Find(&exercises).Error
	return exercises, err
}

func (r *postgresExerciseRepository) UpdateExercise(exercise *models.Exercise) error {
	return r.db.Save(exercise).Error
}

func (r *postgresExerciseRepository) DeleteExercise(id uuid.UUID, userID uuid.UUID) error {
	return r.db.Where("id = ? AND user_id = ?", id, userID).Delete(&models.Exercise{}).Error
}

func (r *postgresExerciseRepository) GetExercisesByMuscleGroup(muscleGroups []string) ([]models.Exercise, error) {
    var exercises []models.Exercise

    // jsonb_exists_any(jsonb, text[])
    // Аргумент 1: путь к нашему массиву в JSON
    // Аргумент 2: массив строк Postgres
    query := "jsonb_exists_any(muscle_groups->'primary', ?)"

    // pq.Array корректно превратит []string в массив для Postgres
    err := r.db.Where(query, pq.Array(muscleGroups)).Find(&exercises).Error
    
    return exercises, err
}