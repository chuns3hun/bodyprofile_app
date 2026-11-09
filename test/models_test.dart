import 'package:flutter_test/flutter_test.dart';

import 'package:bodyprofile_app/history_page.dart';
import 'package:bodyprofile_app/models.dart';
import 'package:bodyprofile_app/storage.dart';

void main() {
  test('버전 1 데이터를 읽으면 부위·기구·회사·메모가 기본값', () {
    final data = Storage.decode(
      '{"version":1,"exercises":[{"id":"a","name":"핵스쿼트"}],'
      '"routines":[],"workouts":[{"id":"w","date":"2026-11-01",'
      '"routineId":null,"sets":[{"exerciseId":"a","weight":100,"reps":8}]}],'
      '"weights":[]}',
    );
    final e = data.exercises.single;
    expect(e.bodyPart, isNull);
    expect(e.equipment, isNull);
    expect(e.brand, '');
    expect(e.memo, '');
    expect(data.workouts.single.sets.single.weight, 100);
    expect(Storage.encode(data), contains('"version":2'));
  });

  test('최고 기록: 보통은 가장 무겁게, 어시스트는 가장 가볍게', () {
    final sessions = [
      Session('2026-11-02', [
        SetRecord(exerciseId: 'a', weight: 30, reps: 8),
        SetRecord(exerciseId: 'a', weight: 30, reps: 10),
      ]),
      Session('2026-11-01', [SetRecord(exerciseId: 'a', weight: 20, reps: 6)]),
    ];
    expect(bestSet(sessions, false)!.set.reps, 10);
    expect(bestSet(sessions, true)!.set.weight, 20);
  });
}
