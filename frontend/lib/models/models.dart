class User {
  final String id;
  final String username;
  final String email;

  User({required this.id, required this.username, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
    );
  }
}

class Exercise {
  final String id;
  final String name;
  final String description;
  final List<String> primaryMuscles;
  final String? videoUrl;

  Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.primaryMuscles,
    this.videoUrl,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    var muscleData = json['muscle_groups']?['data'];
    List<String> primary = [];
    if (muscleData != null && muscleData['primary'] != null) {
      primary = List<String>.from(muscleData['primary']);
    }

    return Exercise(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      primaryMuscles: primary,
      videoUrl: json['video_url'],
    );
  }
}

class Workout {
  final String id;
  final String title;
  final String description;
  final int durationEst;
  final List<WorkoutExercise> exercises;

  Workout({
    required this.id,
    required this.title,
    required this.description,
    required this.durationEst,
    required this.exercises,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    var exerciseList = json['exercises'] as List? ?? [];
    return Workout(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      durationEst: json['total_duration_est'] ?? 0,
      exercises: exerciseList.map((e) => WorkoutExercise.fromJson(e)).toList(),
    );
  }
}

class WorkoutExercise {
  final String id;
  final Exercise exercise;
  final int sets;
  final int reps;

  WorkoutExercise({
    required this.id,
    required this.exercise,
    required this.sets,
    required this.reps,
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      id: json['id'],
      exercise: Exercise.fromJson(json['exercise_info']),
      sets: json['sets'] ?? 0,
      reps: json['reps'] ?? 0,
    );
  }
}
