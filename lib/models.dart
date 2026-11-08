String newId() => DateTime.now().microsecondsSinceEpoch.toString();

String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Exercise {
  final String id;
  String name;

  Exercise({required this.id, required this.name});

  factory Exercise.fromJson(Map<String, dynamic> json) =>
      Exercise(id: json['id'] as String, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class Routine {
  final String id;
  String name;
  List<String> exerciseIds;

  Routine({required this.id, required this.name, List<String>? exerciseIds})
      : exerciseIds = exerciseIds ?? [];

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
        id: json['id'] as String,
        name: json['name'] as String,
        exerciseIds: List<String>.from(json['exerciseIds'] as List? ?? []),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'exerciseIds': exerciseIds};
}

class SetRecord {
  final String exerciseId;
  final double weight;
  final int reps;

  SetRecord({required this.exerciseId, required this.weight, required this.reps});

  factory SetRecord.fromJson(Map<String, dynamic> json) => SetRecord(
        exerciseId: json['exerciseId'] as String,
        weight: (json['weight'] as num).toDouble(),
        reps: (json['reps'] as num).toInt(),
      );

  Map<String, dynamic> toJson() =>
      {'exerciseId': exerciseId, 'weight': weight, 'reps': reps};
}

class WorkoutLog {
  final String id;
  final String date;
  String? routineId;
  List<SetRecord> sets;

  WorkoutLog({
    required this.id,
    required this.date,
    this.routineId,
    List<SetRecord>? sets,
  }) : sets = sets ?? [];

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
        id: json['id'] as String,
        date: json['date'] as String,
        routineId: json['routineId'] as String?,
        sets: (json['sets'] as List? ?? [])
            .map((e) => SetRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'routineId': routineId,
        'sets': sets.map((s) => s.toJson()).toList(),
      };
}

class WeightRecord {
  final String date;
  final double kg;

  WeightRecord({required this.date, required this.kg});

  factory WeightRecord.fromJson(Map<String, dynamic> json) => WeightRecord(
        date: json['date'] as String,
        kg: (json['kg'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'date': date, 'kg': kg};
}

class AppData {
  static const currentVersion = 1;

  List<Exercise> exercises;
  List<Routine> routines;
  List<WorkoutLog> workouts;
  List<WeightRecord> weights;

  AppData({
    List<Exercise>? exercises,
    List<Routine>? routines,
    List<WorkoutLog>? workouts,
    List<WeightRecord>? weights,
  })  : exercises = exercises ?? [],
        routines = routines ?? [],
        workouts = workouts ?? [],
        weights = weights ?? [];

  factory AppData.fromJson(Map<String, dynamic> json) => AppData(
        exercises: _list(json['exercises'], Exercise.fromJson),
        routines: _list(json['routines'], Routine.fromJson),
        workouts: _list(json['workouts'], WorkoutLog.fromJson),
        weights: _list(json['weights'], WeightRecord.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'version': currentVersion,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'routines': routines.map((r) => r.toJson()).toList(),
        'workouts': workouts.map((w) => w.toJson()).toList(),
        'weights': weights.map((w) => w.toJson()).toList(),
      };

  static List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) =>
      (raw as List? ?? [])
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
}
