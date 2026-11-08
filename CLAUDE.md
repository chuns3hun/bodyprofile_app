# bodyprofile_app

개인용 운동·체중 기록 웹앱. Flutter Web으로 빌드해서 GitHub Pages(`/docs`)에 배포하고, 아이폰 사파리에서 홈 화면에 추가해서 쓴다. 앱프로그래밍기초 수업 과제와는 별개다.

## 작업 범위

- 이 폴더(`C:\dev\bodyprofile_app`) 밖의 파일은 읽지도 수정하지도 않는다.
- 특히 수업 관련 프로젝트, 다운로드 폴더, `C:\Users\a2738`(실수로 생긴 Flutter 프로젝트)는 절대 건드리지 않는다.
- 패키지 추가는 꼭 필요할 때만 하고, 추가 전에 먼저 물어본다.

## 구조

- `lib/models.dart`: 데이터 클래스 (Exercise, Routine, SetRecord, WorkoutLog, WeightRecord, AppData)
- `lib/storage.dart`: shared_preferences에 JSON 하나로 저장, 백업은 클립보드 복사/붙여넣기. 오늘 운동 입력 임시본은 별도 키 `workout_draft`
- `lib/main.dart`: 앱 테마, 하단 탭, 백업 메뉴
- `lib/workout_page.dart`: 오늘 운동 (루틴 선택, 직전 기록, 세트 입력, 저장)
- `lib/routines_page.dart`: 루틴 목록과 루틴 편집
- `lib/exercises_page.dart`: 종목 추가/수정/삭제
- `lib/dialogs.dart`: 공용 입력·확인 창

## 데이터 주의사항

- 저장 키 `app_data`는 바꾸지 않는다. 바꾸면 휴대폰에 쌓인 기록이 사라진다.
- 모델 구조를 바꾸면 `AppData.currentVersion`을 올리고, 예전 버전 JSON도 읽을 수 있게 처리한다.
- 아이폰 웹앱이라 파일 다운로드/업로드나 네이티브 전용 기능은 쓰지 않는다.

## 확인과 배포

수정 후에는 `flutter analyze`로 확인한다. 배포는 아래 순서로 한다.

```powershell
flutter build web --release --base-href /bodyprofile_app/
Remove-Item -Recurse -Force docs
Copy-Item -Recurse build\web docs
New-Item docs\.nojekyll -ItemType File
```

커밋과 push는 바뀐 내용을 설명하고 내가 확인한 뒤에 한다.

## 코드 스타일

- 주석은 꼭 필요한 곳에만 짧게 단다.
- 불필요한 추상화나 과한 구조는 만들지 않는다.
