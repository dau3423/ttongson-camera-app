# 실행 루프 (Loop Engineering)

이 프로젝트는 `docs/superpowers/plans/2026-07-02-ttongson-camera-phase0-1.md`의 13개 태스크를
**태스크 단위 subagent-driven 루프**로 완성한다.

## 태스크 사이클 (태스크 N마다 반복)

```
1. 준비    plan에서 Task N의 Files/Interfaces/Steps를 읽는다.
2. 실행    새 서브에이전트를 띄워 Task N만 수행:
             - 계산부(analysis 순수함수): 실패 테스트 → 최소 구현 → 통과
             - 카메라/오버레이/플러그인: 구현 + (기기 필요 시) 수동 검증 지시
3. 게이트   tool/verify.sh 실행 → 통과해야 다음 단계.
             (플러그인/UI 태스크는 flutter analyze까지만 자동, 실기기 검증은 사람 확인)
4. 검토    diff를 검토한다: 규약 준수? 타입 일관성? plan 벗어남 없음?
5. 커밋    Conventional Commit으로 커밋. 체크박스 [x] 표시.
6. 다음    Task N+1로. 실패하면 systematic-debugging으로 고친 뒤 재게이트.
```

## 게이트 규칙

- **계산부 태스크(3,4,5,6,7,10):** `tool/verify.sh` 완전 통과가 하드 게이트.
- **세팅/플러그인/UI 태스크(1,2,8,9,11,12,13):** `flutter analyze` 통과 + 필요 시 실기기 `flutter run` 수동 확인.
- 완료 주장 전 항상 게이트를 **실제로 실행**하고 출력으로 증명한다(증거 우선).

## 자동화 (하네스)

- **포맷 훅:** Dart 파일을 Write/Edit하면 `.claude/settings.json`의 PostToolUse 훅이 `dart format`을 자동 적용.
- **권한:** flutter/dart/git 명령은 `.claude/settings.json`에서 사전 허용 → 루프 중 권한 프롬프트로 끊기지 않음.

## 실행 방식 선택

- **Subagent-Driven (권장):** 태스크당 새 서브에이전트 + 태스크 사이 검토. `superpowers:subagent-driven-development` 사용.
- **Inline:** 이 세션에서 순차 실행 + 체크포인트. `superpowers:executing-plans` 사용.

## 진행 현황

- Phase 0+1: Task 1~13 **완료** (master 병합, `tool/verify.sh` 통과, 33/33 tests).
  - 최종 전체 리뷰(opus) 통합 이슈 수정 완료(포트레이트 고정, init 에러 UX, activeHints 테스트, **크롭=얼굴박스 판정**).
  - **Android 빌드 성공** (`flutter build apk --debug` ✓): gallery_saver→gallery_saver_plus, 모듈형 google_mlkit_face_detection, compileSdk 36(앱+플러그인 강제).
  - **남은 기기(실물) 검증:**
    - 90/270° 회전 시 detector 정규화, 오버레이-프리뷰 종횡비 정렬.
    - 런타임 동작: 카메라 프리뷰/권한 프롬프트, ML Kit 얼굴 모델 최초 다운로드, 촬영→갤러리 저장.
- Phase 2 (클라우드 AI 구도 추천): **완료** (master 병합, 12 tasks, 앱 41/41 + 백엔드 8/8, 최종 리뷰 READY).
  - Firebase Functions `advise`(sonnet-4-6 vision + structured output + App Check + deviceId 레이트리밋) + 앱 `CloudAdvisor`/동의/오버레이/2초 정지 자동 트리거 + 온디바이스 폴백.
  - **배포 전 사용자 후속(코드 아님):**
    - Firebase Blaze 업그레이드 → `firebase functions:secrets:set ANTHROPIC_API_KEY` → `firebase deploy --only functions`.
    - Firestore `rate_limits`에 TTL 정책 + 클라이언트 접근 차단 보안 규칙(Admin SDK는 우회).
    - App Check debug provider → Play Integrity/DeviceCheck 교체(배포 시).
    - 클라이언트 콜러블 타임아웃(현재 5초) 튜닝 검토(비전 응답이 더 걸릴 수 있음).
    - 실기기 스모크 테스트(동의→수동 추천→2초 자동 트리거→카드 렌더).
  - 후속 개선(minor): 임시 JPEG 정리, StillnessDetector.reset() 사용/테스트, 자동+수동 동시 트리거 동기 가드.
