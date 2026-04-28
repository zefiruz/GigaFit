package handler

import (
	"encoding/json"
	"net/http"

	"github.com/google/uuid"
	"github.com/zefiruz/GigaFit/backend/internal/models"
	"github.com/zefiruz/GigaFit/backend/internal/repository"
)

type ExerciseHandler struct {
	Repo repository.ExerciseRepository
}

func NewExerciseHandler(repo repository.ExerciseRepository) *ExerciseHandler {
	return &ExerciseHandler{
		Repo: repo,
	}
}

func (h *ExerciseHandler) CreateExercise(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Name        string `json:"name"`
		Description string `json:"description"`
		PrimaryMuscles   []string `json:"primary_muscles"`  
        SecondaryMuscles []string `json:"secondary_muscles"`
		VideoURL    string `json:"video_url"`
	}

	err := json.NewDecoder(r.Body).Decode(&input)
	if err != nil {
		http.Error(w, "Некорректный JSON", http.StatusBadRequest)
		return
	}

	exerciseID := uuid.New()

	newExercise := models.Exercise{
		ID:           exerciseID,
		Name:         input.Name,
		Status:       "custom", 
		Description:  input.Description,
		MuscleGroups: models.JSONB[models.MuscleData]{
			Data: models.MuscleData{
				Primary:   input.PrimaryMuscles,
				Secondary: input.SecondaryMuscles,
			},
		},
		VideoURL: input.VideoURL,
	}

	err = h.Repo.CreateExercise(&newExercise)
	if err != nil {
		http.Error(w, "Ошибка при сохранении упражнения", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	if err := json.NewEncoder(w).Encode(map[string]string{
		"status":      "success",
		"message":     "Упражнение успешно создано",
		"exercise_id": exerciseID.String(),
	}); err != nil {
		http.Error(w, "Ошибка при кодировании ответа", http.StatusInternalServerError)
	}
}

func (h *ExerciseHandler) GetExerciseByID(w http.ResponseWriter, r *http.Request) {
	idStr := r.PathValue("id")

	id, err := uuid.Parse(idStr)
	if err != nil {
		http.Error(w, "Некорректный UUID формат", http.StatusBadRequest)
		return
	}

	exercise, err := h.Repo.GetExerciseByID(id)
	if err != nil {
		http.Error(w, "Упражнение не найдено", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	err = json.NewEncoder(w).Encode(exercise)
	if err != nil {
		http.Error(w, "Ошибка при кодировании ответа", http.StatusInternalServerError)
	}
}

func (h *ExerciseHandler) GetAllExercises(w http.ResponseWriter, r *http.Request) {
	exercises, err := h.Repo.GetAllExercises()
	if err != nil {
		http.Error(w, "Ошибка при загрузке упражнений", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	err = json.NewEncoder(w).Encode(exercises)
	if err != nil {
		http.Error(w, "Ошибка при кодировании ответа", http.StatusInternalServerError)
	}
}

func (h *ExerciseHandler) UpdateExercise(w http.ResponseWriter, r *http.Request) {
	idStr := r.PathValue("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		http.Error(w, "Некорректный UUID формат", http.StatusBadRequest)
		return
	}

	var input struct {
		Name        string `json:"name"`
		Description string `json:"description"`
		PrimaryMuscles   []string `json:"primary_muscles"`  
        SecondaryMuscles []string `json:"secondary_muscles"`
		VideoURL    string `json:"video_url"`
	}

	err = json.NewDecoder(r.Body).Decode(&input)
	if err != nil {
		http.Error(w, "Некорректный JSON", http.StatusBadRequest)
		return
	}

	exercise, err := h.Repo.GetExerciseByID(id)
	if err != nil {
		http.Error(w, "Упражнение не найдено", http.StatusNotFound)
		return
	}

	exercise.Name = input.Name
	exercise.Description = input.Description
	exercise.MuscleGroups = models.JSONB[models.MuscleData]{
		Data: models.MuscleData{
			Primary:   input.PrimaryMuscles,
			Secondary: input.SecondaryMuscles,
		},
	}
	exercise.VideoURL = input.VideoURL

	err = h.Repo.UpdateExercise(exercise)
	if err != nil {
		http.Error(w, "Ошибка при обновлении упражнения", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	err = json.NewEncoder(w).Encode(exercise)
	if err != nil {
		http.Error(w, "Ошибка при кодировании ответа", http.StatusInternalServerError)
	}
}

func (h *ExerciseHandler) DeleteExercise(w http.ResponseWriter, r *http.Request) {
	currentUserID, ok := r.Context().Value("userID").(uuid.UUID)
    if !ok {
        http.Error(w, "Пользователь не авторизован", http.StatusUnauthorized)
        return
    }

	idStr := r.PathValue("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		http.Error(w, "Некорректный UUID формат", http.StatusBadRequest)
		return
	}

	err = h.Repo.DeleteExercise(id, currentUserID)
    if err != nil {
        http.Error(w, "Упражнение не найдено или доступ запрещен", http.StatusForbidden)
        return
    }

    w.WriteHeader(http.StatusNoContent)
}

func (h *ExerciseHandler) GetExercisesByMuscleGroup(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()

	muscleGroups := query["muscle_group"]
	if len(muscleGroups) == 0 {
        http.Error(w, "Укажите хотя бы одну группу мышц", http.StatusBadRequest)
        return
    }


	exercises, err := h.Repo.GetExercisesByMuscleGroup(muscleGroups)
    if err != nil {
        http.Error(w, "Ошибка базы данных", http.StatusInternalServerError)
        return
    }

    w.Header().Set("Content-Type", "application/json")
    err = json.NewEncoder(w).Encode(exercises)
	if err != nil {
		http.Error(w, "Ошибка при кодировании ответа", http.StatusInternalServerError)
	}
}