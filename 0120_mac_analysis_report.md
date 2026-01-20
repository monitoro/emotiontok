# EmotionTok 소스코드 분석 보고서

## 1. 프로젝트 개요
**EmotionTok (감정쓰레기통)**은 사용자가 감정을 털어놓고(Venting), "태워버리는" 경험을 제공하는 Flutter 애플리케이션입니다.

- **앱 이름:** BURN IT: 감정쓰레기통
- **플랫폼:** Flutter (Android, iOS, Web 등 지원 가능)
- **주요 기능:** 감정 배설, AI 위로, 익명 광장(커뮤니티), 감정 기록

## 2. 아키텍처 및 구조
**MVVM (Model-View-ViewModel)** 패턴을 따르고 있으며, `Provider`를 사용하여 상태 관리를 하고 있습니다.

- **[lib/main.dart](file:///Users/mango/00_Develop/emotiontok/lib/main.dart)**: 앱의 진입점. 테마 설정(Dark Mode) 및 `MultiProvider`를 통한 ViewModel 주입.
- **`lib/views/`**: UI 패키지. IA(정보구조)에 기술된 화면들이 구현되어 있음.
    - `home_screen.dart`: 메인 화면. 텍스트/낙서 입력, 화남(Anger) 수치 조절, 태우기 효과.
    - `square_screen.dart`: 익명 광장.
    - `onboarding_screen.dart`: 닉네임/PIN 설정.
- **`lib/viewmodels/`**: 비즈니스 로직 및 상태 관리.
    - `venting_viewmodel.dart`: 핵심 로직. 게시글 CRUD, 광장 데이터 관리, 필터링.
    - `user_viewmodel.dart`: 사용자 설정(닉네임, 페르소나, BGM 등) 관리.
- **`lib/services/`**: 외부 서비스 연동.
    - `ai_service.dart`: AI 응답 생성 (현재 Mockup).

## 3. 주요 기능 구현 상태

### ✅ 구현됨 (Implemented)
1.  **온보딩 및 사용자 설정**
    - 닉네임, PIN 번호(4자리) 설정.
    - AI 페르소나(전투형, 공감형, 팩폭형, 유머형) 선택.
    - `shared_preferences`를 이용한 설정 값 영구 저장 (앱 재시작 시 유지됨).
2.  **감정 배설 (Venting)**
    - **텍스트 모드:** 글 작성.
    - **낙서 모드:** `signature` 패키지를 이용한 드로잉.
    - **태우기 인터랙션:** 버튼을 길게 눌러(Long Press) '화남 수치'를 채우고, 80% 이상 시 애니메이션과 함께 소각.
    - **효과음:** 배경음(BGM) 및 효과음(SFX) 재생 (`audioplayers`).
3.  **UI/UX**
    - 다크 모드 기반의 세련된 디자인.
    - 감정 상태에 따른 시각적 피드백 (Pulse 애니메이션).

### ⚠️ 미구현 / Mockup (To-Do)
1.  **AI 연동 (Gemini)**
    - `google_generative_ai` 패키지가 추가되어 있으나, 현재 `AIService`는 2초 딜레이 후 **랜덤한 고정 문구**를 반환하는 Mock 상태입니다. 실제 API 연동이 필요합니다.
2.  **데이터 저장 (Persistence)**
    - 작성한 감정 일기(Private History)와 광장 게시글(Public Posts)이 **메모리(RAM)**에만 저장됩니다. 앱을 껐다 켜면 기록이 사라집니다. 로컬 DB(Sqflite/Drift) 또는 클라우드 DB(Firebase) 도입이 필요합니다.
3.  **음성 모드 (Voice Mode)**
    - `VentingMode.voice` 열거형은 존재하지만, 실제 녹음 및 데시벨 측정 UI는 구현되어 있지 않습니다.
4.  **광장 (Community)**
    - 서버 통신 없이 로컬의 더미 데이터(`_publicPosts`)만 보여줍니다. 다른 사용자와의 실제 공유는 불가능한 상태입니다.

## 4. 제언 (Next Steps)
1.  **Gemini API 실제 연동:** `AIService`를 수정하여 실제 생성형 AI가 사용자의 텍스트를 분석하고 위로하도록 구현.
2.  **데이터 영속성 확보:** 사용자의 감정 기록이 사라지지 않도록 로컬 데이터베이스 연동.
3.  **음성 기능 구현:** 마이크 권한 획득 및 소리 지르기 기능 추가.
