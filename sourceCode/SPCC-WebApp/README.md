# SPCC PWA Simulator

> **스마트 자세 교정 의자** 의 하드웨어 없이 동작하는 웹 시뮬레이터
> React 단일 파일로 작성된 Progressive Web App. RPi5 와 모바일 앱 없이도 시스템 흐름을 체험할 수 있다.

<p align="center">
  <img alt="Type" src="https://img.shields.io/badge/Type-PWA-5A0FC8">
  <img alt="Framework" src="https://img.shields.io/badge/UI-React-61DAFB">
  <img alt="Distribution" src="https://img.shields.io/badge/Deploy-GitHub%20Pages-181717">
  <img alt="Files" src="https://img.shields.io/badge/Files-2-success">
</p>

---

## 목차

1. [개요](#개요)
2. [용도](#용도)
3. [파일 구성](#파일-구성)
4. [GitHub Pages 배포](#github-pages-배포)
5. [모바일 앱처럼 설치 (PWA)](#모바일-앱처럼-설치-pwa)
6. [로컬 실행](#로컬-실행)
7. [관련 모듈](#관련-모듈)

---

## 개요

본 모듈은 **하드웨어와 RPi5 백엔드 없이도** 스마트 자세 교정 의자의 사용자 흐름을 체험할 수 있는 웹 시뮬레이터이다. 단일 HTML 파일에 React, 시뮬레이션 로직, UI 가 모두 포함되어 있어 빌드 과정 없이 바로 배포할 수 있다.

### 특징

| 특징 | 설명 |
|------|------|
| **No Build** | React CDN 기반, 별도 빌드 과정 불필요 |
| **Single File** | `index.html` 한 파일에 전체 시뮬레이터 포함 |
| **PWA 지원** | 홈 화면에 설치 가능, 전체화면 앱처럼 동작 |
| **Offline Capable** | 한 번 로드 후 오프라인 동작 가능 |
| **5분 배포** | GitHub Pages 로 즉시 배포 가능 |

---

## 용도

| 시나리오 | 활용 방법 |
|---------|----------|
| **하드웨어 도착 전 시연** | 데모 / 발표 / 사용자 인터뷰에 활용 |
| **앱 흐름 사전 검증** | 실제 Flutter 앱 개발 전 UX 검증 |
| **공모전 심사위원 체험** | URL 공유만으로 누구나 모바일/PC 에서 체험 가능 |
| **시스템 흐름 학습** | 17개 stage 의 자동 화면 전환 메커니즘 이해 |

---

## 파일 구성

```text
SPCC-WebApp/
├── README.md              # 본 문서
├── index.html             # React 전체 시뮬레이터 (단일 파일)
└── manifest.json          # PWA 매니페스트 (앱 이름 / 아이콘 / 전체화면)
```

### `index.html`

React 시뮬레이터 본체. 다음을 모두 포함한다.

- React 라이브러리 (CDN 로드)
- 가짜 RPi5 백엔드 시뮬레이션 로직 (stage 전이 / 더미 센서 데이터 / 자세 판정)
- 5개 화면 (Splash → Profile → Calibration → Measurement → Report)
- 4탭 측정 대시보드 시각화
- 자리 이탈 다이얼로그
- 로컬 보고서 저장

### `manifest.json`

PWA 매니페스트:

| 필드 | 값 |
|------|----|
| `name` | SPCC Simulator |
| `short_name` | SPCC |
| `display` | `standalone` (브라우저 UI 숨김) |
| `background_color` | `#f8f9fb` |
| `theme_color` | `#2563eb` |
| `icons` | SVG 인라인 아이콘 (브랜드 SC) |

---

## GitHub Pages 배포

### 1. GitHub 저장소 생성

1. [github.com](https://github.com) → **New Repository**
2. 이름: `spcc-simulator` (또는 원하는 이름)
3. **Public** 선택 → **Create**

### 2. 파일 업로드

1. 저장소 페이지에서 **Add file** → **Upload files**
2. `index.html` 과 `manifest.json` 두 파일을 드래그 앤 드롭
3. **Commit changes** 클릭

### 3. GitHub Pages 활성화

1. **Settings** → **Pages**
2. **Source**: `Deploy from a branch`
3. **Branch**: `main`, 폴더: `/ (root)` 선택
4. **Save** 클릭

### 4. 접속

1~2분 후 다음 URL 에서 접속 가능:

```
https://[사용자명].github.io/spcc-simulator/
```

이 URL 을 공유하면 누구나 모바일 / PC 에서 시뮬레이터를 사용할 수 있다.

---

## 모바일 앱처럼 설치 (PWA)

배포된 URL 을 모바일 브라우저로 접속하면 네이티브 앱처럼 홈 화면에 설치할 수 있다.

### Android (Chrome)

1. 배포된 URL 접속
2. 주소창 옆 **설치** 또는 메뉴 → **홈 화면에 추가**
3. 홈 화면에 SPCC 아이콘 생성
4. 아이콘 탭하면 **전체화면 앱**처럼 실행

### iOS (Safari)

1. 배포된 URL 접속
2. **공유 버튼** → **홈 화면에 추가**
3. 앱 아이콘으로 실행

> 한 번 설치 후에는 오프라인 상태에서도 기본 동작이 가능하다.

---

## 로컬 실행

별도 빌드 없이 다음 두 방법 중 하나로 실행할 수 있다.

### 방법 1 — 파일 직접 열기

`index.html` 을 더블클릭 / 브라우저에 드래그하여 실행.

> ⚠️ 일부 브라우저는 보안 정책으로 `file://` 프로토콜에서 일부 기능이 제한될 수 있다.

### 방법 2 — 로컬 HTTP 서버

권장 방법. Python 이 설치되어 있다면:

```bash
cd sourceCode/SPCC-WebApp
python -m http.server 8080
```

브라우저에서 `http://localhost:8080` 접속.

Node.js 의 `http-server` 패키지도 동일하게 사용 가능:

```bash
npx http-server -p 8080
```

---

## 관련 모듈

| 모듈 | 위치 |
|------|------|
| **전체 시스템 개요** | [`../../README.md`](../../README.md) |
| **STM32 펌웨어** | [`../STM32/`](../STM32/) |
| **Raspberry Pi 백엔드** | [`../RaspberryPi/`](../RaspberryPi/) |
| **Flutter 모바일 앱** | [`../flutter_app/`](../flutter_app/) |
| **가짜 RPi 서버 (Python)** | [`../rpisimulator2.py`](../rpisimulator2.py) |

> Flutter 앱과 함께 가짜 RPi5 서버가 필요한 경우, 본 PWA 대신 [`../rpisimulator2.py`](../rpisimulator2.py) 를 사용한다. 본 PWA 는 Flutter 앱 자체를 시뮬레이션하는 독립 실행형이다.
