package repository

import (
	"gigafit/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type TrainingPlanRepository interface {
	CreatePlan(plan *models.TrainingPlan) error
	GetTrainingPlanByID(id uuid.UUID, userID uuid.UUID) (*models.TrainingPlan, error)
	GetAllTrainingPlans(userID uuid.UUID) ([]models.TrainingPlan, error)
	
	UpdateTrainingPlan(id uuid.UUID, userID uuid.UUID, updates map[string]interface{}) error
	DeleteTrainingPlan(id uuid.UUID, userID uuid.UUID) error
}

type postgresTrainingPlanRepository struct {
	db *gorm.DB
}

func NewTrainingPlanRepository(db *gorm.DB) TrainingPlanRepository {
	return &postgresTrainingPlanRepository{db: db}
}

func (r *postgresTrainingPlanRepository) CreatePlan(plan *models.TrainingPlan) error {
	return r.db.Create(plan).Error
}

func (r *postgresTrainingPlanRepository) GetTrainingPlanByID(id uuid.UUID, userID uuid.UUID) (*models.TrainingPlan, error) {
	var plan models.TrainingPlan

	err := r.db.
		Where("id = ? AND (user_id = ? OR is_public = ?)", id, userID, true).
		Preload("Workouts").
		Preload("Workouts.Workout").
		Preload("Workouts.Workout.Exercises").
		Preload("Workouts.Workout.Exercises.Exercise").
		First(&plan).Error
	if err != nil {
		return nil, err
	}

	return &plan, nil
}

func (r *postgresTrainingPlanRepository) GetAllTrainingPlans(userID uuid.UUID) ([]models.TrainingPlan, error) {
	var plans []models.TrainingPlan

	err := r.db.
		Where("user_id = ? OR is_public = ?", userID, true).
		Preload("Workouts").
		Preload("Workouts.Workout").
		Preload("Workouts.Workout.Exercises").
		Preload("Workouts.Workout.Exercises.Exercise").
		Find(&plans).Error
	if err != nil {
		return nil, err
	}

	return plans, nil
}

func (r *postgresTrainingPlanRepository) UpdateTrainingPlan(id uuid.UUID, userID uuid.UUID, updates map[string]interface{}) error {
	return r.db.Model(&models.TrainingPlan{}).
		Where("id = ? AND user_id = ?", id, userID).
		Updates(updates).Error
}

func (r *postgresTrainingPlanRepository) DeleteTrainingPlan(id uuid.UUID, userID uuid.UUID) error {
	return r.db.Where("id = ? AND user_id = ?", id, userID).Delete(&models.TrainingPlan{}).Error
}