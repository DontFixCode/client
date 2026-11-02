# 버스로 🚌

대전에서의 여유로운 이동을 위한 Flutter 프론트엔드입니다. 예상 이동시간과 환승 여유·성공 가능성을 비교하고, 도보부터 버스·환승·도착 확인까지 하나의 흐름으로 체험할 수 있습니다.

## 실행

```sh
flutter pub get
flutter run
# 웹에서 실행
flutter run -d chrome
```

```sh
flutter analyze
flutter test
```

## 화면 흐름

시작 → 로그인 / 회원가입 / 둘러보기 → 홈 → 출발·도착 장소 검색 → 경로 비교 → 경로 상세 → 도보·대기·탑승 확인 → 하차·환승 → 마지막 도보 → 도착·결과 입력 → 이동 기록

하단 탭은 **이용기록 / 홈 / 내정보** 순서이며, 앱을 시작하면 가운데 홈이 열립니다. 홈에서 출발·도착지 선택과 교환, 경로 검색, 자주 가는 곳, 정류장 미리보기를 이용합니다. 별도 길찾기 탭과 중복 소개 화면은 홈으로 합쳤습니다. 안내 중 화면을 나가도 하단의 **계속하기**로 재개할 수 있습니다. 기존 안내를 유지한 채 다른 경로를 비교하거나 새 안내로 변경할 수도 있습니다.

## 파일 구조

```text
lib/
├── main.dart                         # 앱 실행
├── app.dart                          # 앱 설정·화면 라우팅·모바일 너비
├── config/
│   └── app_routes.dart               # 화면 경로 이름
├── models/
│   ├── place.dart                    # 장소
│   ├── travel_route.dart             # 경로·환승 평가
│   └── journey_record.dart           # 완료 기록·환승 결과
├── data/
│   └── demo_data.dart                # 교체 가능한 체험 장소·경로
├── state/
│   └── app_state.dart                # 앱 실행 중 상태·AppScope
└── ui/
    ├── theme/
    │   └── app_theme.dart            # 팔레트·글꼴·공통 버튼·입력창
    ├── pages/
    │   ├── splash_page.dart          # 시작 화면
    │   ├── main_page.dart            # 탭·안내 재개
    │   ├── auth/
    │   │   ├── login_page.dart
    │   │   ├── signup_page.dart
    │   │   ├── forgot_password_page.dart
    │   │   └── widgets/auth_scaffold.dart
    │   ├── home/home_page.dart
    │   ├── search/
    │   │   └── place_search_page.dart
    │   ├── routes/
    │   │   ├── route_results_page.dart
    │   │   └── route_detail_page.dart
    │   ├── journey/journey_guide_page.dart
    │   ├── history/history_page.dart
    │   └── profile/profile_page.dart
    └── widgets/                      # 화면 사이에서 재사용
        ├── app_card.dart
        ├── app_navigation_bar.dart
        ├── bus_logo.dart
        ├── route_map.dart
        ├── route_card.dart
        ├── route_timeline.dart
        ├── section_header.dart
        ├── status_pill.dart
        ├── empty_state.dart
        └── demo_notice.dart
```

## 디자인 변경

`lib/ui/theme/app_theme.dart` 한 곳에서 `AppColors`의 색상과 `AppTheme.light`의 글꼴·크기·입력창·버튼·탭 스타일을 관리합니다. 올리브 그린·머스터드·블루·버건디와 밝은 회색 배경을 사용합니다. 공통 카드의 둥글기는 `AppTheme.radius`에서, 화면별 여백은 각 화면의 `padding`에서 조절합니다. 화면 파일은 Dart 관례에 맞게 소문자 `ui/pages`로 나눴습니다.

## 현재 구현 범위

- 로그인·회원가입 입력 검증, 비밀번호 보기, 비밀번호 재설정 화면
- 장소 이름·주소 검색, 출발·도착 교환, 즐겨찾기 추가·해제
- 추천순·빠른순·환승 적은순 비교, 환승 확률 확인 불가, 직행 표시
- 지원 지역 밖·동일 장소·검색 결과 없음 안내
- 단계별 이동 안내, 탑승 노선·방향 확인과 수정, 확인 불가 응답
- 대체 경로 비교, 안내 재개·종료, 환승 결과와 기록 조회·삭제
- 버스 구간 사이 환승 여유시간, 성공 가능성 5단계 표시(0–19 매우 낮음 / 20–39 낮음 / 40–59 보통 / 60–79 높음 / 80–100 매우 높음)
- 탑승 중 상단 하차 안내, 남은 정류장 수와 더 빠른 환승 경로 제안 팝업
- 이름 변경, 알림 설정 UI, 로그아웃·체험 계정 삭제

**백엔드·지도 SDK·GPS·실시간 교통 API·이메일·시스템 알림은 연결하지 않았습니다.** 지도는 직접 그린 경로 개념도이고 모든 노선·소요시간·확률은 예시입니다. 실제 이동에 사용할 수 없습니다. 로그인은 입력 형식을 검증한 뒤 로컬 체험 세션을 만들며 실제 인증이나 계정 생성은 하지 않습니다. 비밀번호를 상태나 디스크에 저장하지 않습니다.

즐겨찾기·회원정보·이동 기록·진행 중 안내는 메모리에만 보관하므로 앱 종료·새로고침 시 초기화됩니다. 환승 없는 기록은 환승 평가 대상에서 제외해 표시합니다.

탑승 확인 후 **다음 정류장**을 누르면 예시 정류장 수가 2 → 1 → 0으로 줄어듭니다. 첫 버스에서는 첫 번째 정류장 진행 시 더 빠른 환승 제안 팝업이 한 번 열리고, **새 환승 경로**로 다시 볼 수 있습니다. **유지**는 현재 경로를 유지하고, **601번으로 변경**은 현재 버스·환승 정류장·안내 단계를 유지한 채 연결 버스와 예상 시간을 바꿉니다. 다른 버스나 방향을 입력했거나 탑승을 확인하지 않은 경우 이 예시 안내를 숨깁니다. 시스템 알림 설정과 독립적인 앱 내 UI입니다.

향후 서버 연동은 `demo_data.dart`에서 가져오는 데이터와 `AppState`의 인증·검색·이동 처리 지점부터 연결하면 됩니다. 현재는 추가 패키지 없이 Flutter 기본 기능과 `ChangeNotifier`/`InheritedNotifier`를 사용합니다.
