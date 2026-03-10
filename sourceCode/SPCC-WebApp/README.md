# SPCC Simulator 배포 가이드

## GitHub Pages 배포 (5분)

### 1. GitHub 저장소 생성
- github.com → New Repository
- 이름: `spcc-simulator` (또는 원하는 이름)
- Public 선택 → Create

### 2. 파일 업로드
- 저장소 페이지에서 "Add file" → "Upload files"
- `index.html`과 `manifest.json` 두 파일을 드래그 앤 드롭
- "Commit changes" 클릭

### 3. GitHub Pages 활성화
- Settings → Pages
- Source: "Deploy from a branch"
- Branch: `main`, 폴더: `/ (root)` 선택
- Save 클릭

### 4. 접속
- 1~2분 후 `https://[사용자명].github.io/spcc-simulator/` 에서 접속 가능
- 이 URL을 공유하면 누구나 모바일/PC에서 시뮬레이터 사용 가능

## 모바일 앱처럼 설치 (PWA)

### Android (Chrome)
1. URL 접속
2. 주소창 옆 "설치" 또는 메뉴 → "홈 화면에 추가"
3. 홈 화면에 SPCC 아이콘 생성 → 전체화면 앱처럼 실행

### iOS (Safari)
1. URL 접속
2. 공유 버튼 → "홈 화면에 추가"
3. 앱 아이콘으로 실행

## 파일 구성
- `index.html` — 시뮬레이터 전체 (React + 로직 + UI 포함)
- `manifest.json` — PWA 설정 (앱 이름, 아이콘, 전체화면)
