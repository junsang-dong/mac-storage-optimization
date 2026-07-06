# Mac mini 스토리지 최적화

스토리지 용량이 부족한 맥 유저를 위한 스토리지 관리 가이드입니다. 
실제 제가 아끼는 Mac mini에 탑재된 245 GB 디스크의 **시스템 데이터(System Data)가 95 GB**까지 부풀어 있던 문제를 진단하고, 불필요한 캐시·개발 도구·AI 모델 등을 정리한 작업 기록입니다.
이런 작업에는 Claude가 늘 유용한 조언을 해주었지만, 이번엔 저의 주요 바이브코딩 도구인 Cursor를 이용했고 만족스러운 스토리지 최적화 결과를 얻었습니다. 

## 결과 요약

| 항목 | 최적화 전 | 최적화 후 |
|------|-----------|-----------|
| 사용 중 | 221 GB | **172 GB** |
| 여유 공간 | 24 GB | **72 GB** |
| 시스템 데이터 | 95.73 GB | **64 GB** |
| 문서 | 50.78 GB | 45 GB |
| 응용 프로그램 | 26 GB | 14.6 GB |

**약 41~49 GB**의 디스크 공간을 회수했습니다.

---

## 시스템 데이터란?

macOS **시스템 설정 → 일반 → 저장 공간**에서 "시스템 데이터"로 표시되는 항목은, Apple이 문서·앱·개발자 등으로 분류하지 못한 데이터의 **잡동사니(catch-all) 카테고리**입니다.

실제로는 아래가 섞여 있습니다.

- `~/Library` (앱 캐시, Application Support)
- 숨김 폴더 (`~/.android`, `~/.lmstudio` 등)
- VM 스왑 볼륨 (~4 GB)
- OS 업데이트 APFS 스냅샷
- `/Library/Updates` 잔여 파일
- Docker 가상 디스크 등

이번 작업 전 **95 GB** 중 상당 부분은 "시스템"처럼 보였지만, 실제로는 **삭제해도 되는 앱 데이터·개발 캐시·AI 모델**이었습니다.

---

## 용량을 가장 많이 차지하던 불필요 요소 (Top 5)

진단(`du`, APFS 분석) 기준, **삭제 승인 후 제거한 항목**입니다.

| 순위 | 대상 | 경로 | 용량 | 설명 |
|------|------|------|------|------|
| 1 | **AI 모델** | `~/Applications/NovaGerbil Story`, `~/Applications/Gerbil` | **~17 GB** | FLUX/GGUF 로컬 AI 모델. 재다운로드 가능 |
| 2 | **Android SDK + 에뮬레이터** | `~/Library/Android`, `~/.android` | **~8 GB** | SDK, system-images, AVD 스냅샷 |
| 3 | **Filmora 캐시/미디어** | `~/Library/Application Support/Wondershare Filmora*` | **~7.7 GB** | 구버전(9, 10) + Mac 버전 편집 캐시·1 GB+ 영상 |
| 4 | **iOS Simulator (사용자)** | `~/Library/Developer/CoreSimulator` | **~3.3 GB** | 시뮬레이터 기기 데이터 |
| 5 | **DataScienceStudio** | `~/Library/DataScienceStudio` | **~3.7 GB** | DSS/KNIME kits 및 런타임 |

그 외 정리한 항목:

| 대상 | 경로 | 용량 |
|------|------|------|
| LM Studio | `~/.lmstudio` | ~1.3 GB |
| Docker | `~/Library/Containers/com.docker.docker`, `~/.docker` | ~189 MB |

---

## 보존한 항목

사용자 요청에 따라 **삭제하지 않음**:

| 대상 | 경로 | 용량 | 이유 |
|------|------|------|------|
| Cursor | `~/Library/Application Support/Cursor` | ~3.6 GB | 채팅 기록·설정 (`state.vscdb` 1.5 GB×2) |
| Python 패키지 | `~/Library/Python` | ~2 GB | pip 재설치 부담 방지 |

---

## 수행한 작업 (Phase별)

### Phase 0 — 사전 준비
- Filmora, Docker, Android Studio, LM Studio, Simulator 등 관련 앱 실행 여부 확인
- 정리 대상 경로 용량 기록

### Phase 1 — 앱 데이터 (~30 GB)
- Wondershare Filmora 전 버전 데이터 삭제
- `~/Applications` AI 모델(NovaGerbil Story, Gerbil) 삭제
- DataScienceStudio, LM Studio 삭제

### Phase 2 — 개발 도구 (~8 GB+)
- Android SDK, `.android` 에뮬레이터 데이터 삭제
- `xcrun simctl delete unavailable` / `erase all`로 iOS Simulator 초기화
- Docker 컨테이너 데이터 삭제

### Phase 3 — 시스템 레벨 (부분 실패)
- `/Library/Updates` (~1.8 GB), `/Library/Developer/CoreSimulator` (~3.5 GB), OS 업데이트 APFS 스냅샷 3개
- **macOS SIP(시스템 무결성 보호)** 로 자동 삭제 불가 → 재부팅 후 macOS가 정리하거나 수동 시도 필요

### Phase 4 — 검증
- `df -h /` 기준 여유 공간 **23 GB → 64 GB** 확인
- 시스템 설정 UI: 시스템 데이터 **95 GB → 64 GB** (갱신에 시간 소요 가능)

---

## 자동화 스크립트

```bash
# 삭제 대상 미리보기 (실제 삭제 없음)
./scripts/cleanup-mac-storage.sh --dry-run --all

# Phase별 실행
./scripts/cleanup-mac-storage.sh --phase 1
./scripts/cleanup-mac-storage.sh --phase 2

# sudo 필요 항목 (SIP 제한 있음)
./scripts/phase3-sudo.sh
```

| 스크립트 | 설명 |
|----------|------|
| `scripts/cleanup-mac-storage.sh` | `--dry-run`, `--phase 1\|2\|3`, `--all`, `--verify` |
| `scripts/phase3-sudo.sh` | `/Library/Updates`, CoreSimulator 캐시, OS 스냅샷 (관리자 비밀번호 필요) |

---

## 아직 남아 있는 큰 항목 (추가 정리 후보)

시스템 데이터가 **64 GB**로 줄었지만, 여전히 용량을 쓰는 항목입니다.

| 항목 | 예상 용량 | 비고 |
|------|-----------|------|
| `~/Library/Application Support/Cursor` | ~3.6 GB | 보존 선택. VACUUM으로 DB 축소 가능 |
| `~/Library/Python` | ~2 GB | 보존 선택 |
| Adobe / Google Chrome 캐시 | ~4 GB | Creative Cloud·Chrome 캐시 정리 |
| `Documents/0NXP` | ~25 GB | **문서** 카테고리 — 외장/클라우드 아카이브 검토 |
| `node_modules` (58개 프로젝트) | ~7.4 GB | `npx npkill` 등 |
| `/Library/Updates` | ~1.8 GB | SIP 보호, 재부팅 후 자동 정리 대기 |
| `/Library/Developer/CoreSimulator` | ~3.5 GB | SIP 보호, Xcode 재설치 시 재생성 |
| Preboot 볼륨 | ~17 GB | macOS 관리 영역, 직접 삭제 불가 |

---

## 참고 사항

- **시스템 설정의 수치**는 정리 후 **수 분~24시간** 뒤에야 정확히 반영될 수 있습니다.
- Android/iOS 개발, Filmora, LM Studio, Docker를 다시 쓰려면 **SDK·앱·모델을 재설치**해야 합니다.
- `Docker.raw`는 논리적 최대 228 GB로 보일 수 있으나, sparse file이라 실제 사용량은 훨씬 작습니다.

---

## 작업 환경

- **기기:** Mac mini (JunMacMini)
- **디스크:** 245 GB APFS (FileVault)
- **작업일:** 2026-07-05
