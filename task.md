# APK 빌드 작업

Flutter 프로젝트 `emotiontok`를 APK 파일로 빌드합니다.

## 작업 단계
- [x] 개발 환경 프로젝트 확인
- [x] `flutter build apk` 명령어를 사용하여 APK 빌드
- [x] 빌드 결과물 경로 확인 및 사용자에게 안내

## 빌드 결과
- **APK 경로**: `build\app\outputs\flutter-apk\app-release.apk`
- **파일 크기**: 약 59.5MB
- **참고**: 현재 키스토어(Keystore) 설정이 되어 있지 않아 디버그 서명 또는 미서명 상태로 빌드되었습니다. 실제 스토어 업로드 시에는 `RELEASE_ROADMAP.md`를 참고하여 서명 키 설정을 완료해야 합니다.
