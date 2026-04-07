# STM32 Sensor Node

> **스마트 자세 교정 의자** 의 STM32F411CEU6 기반 센서 노드 펌웨어
> 4종 20개 센서를 50 Hz로 동기 폴링하여 129 byte 바이너리 패킷으로 Raspberry Pi 5 에 전송한다.

<p align="center">
  <img alt="MCU" src="https://img.shields.io/badge/MCU-STM32F411CEU6-03234B">
  <img alt="Core" src="https://img.shields.io/badge/Core-ARM%20Cortex--M4-blue">
  <img alt="Clock" src="https://img.shields.io/badge/Clock-100MHz-informational">
  <img alt="UART" src="https://img.shields.io/badge/UART-921600bps-success">
  <img alt="Loop" src="https://img.shields.io/badge/Loop-50Hz%20(9ms)-brightgreen">
  <img alt="IDE" src="https://img.shields.io/badge/IDE-STM32CubeIDE-03234B">
</p>

---

## 목차

1. [개요](#개요)
2. [하드웨어](#하드웨어)
3. [센서 구성](#센서-구성)
4. [폴더 구조](#폴더-구조)
5. [동작 흐름](#동작-흐름)
6. [센서 초기화](#센서-초기화)
7. [50 Hz 측정 루프](#50-hz-측정-루프)
8. [패킷 구조](#패킷-구조)
9. [UART 프로토콜](#uart-프로토콜)
10. [핀 매핑](#핀-매핑)
11. [빌드 / 플래시](#빌드--플래시)
12. [디버깅](#디버깅)

---

## 개요

본 펌웨어는 의자에 설치된 4종 20개 센서를 **20 ms (50 Hz)** 주기로 폴링한 뒤, **128 byte 센서 데이터 + XOR 1 byte 체크섬 = 총 129 byte 바이너리 패킷**으로 패킹하여 921,600 bps UART 로 RPi5 에 전송한다.

### 핵심 설계 목표

| 목표 | 달성 방법 |
|------|----------|
| **정확한 50 Hz 주기 유지** | `HAL_GetTick` 기반 20 ms 주기 동기, 평균 51 Hz 달성 |
| **20 ms 예산 내 4종 센서 폴링** | 센서별 통신 버스 점유 시간을 고려한 최적 순서 (실측 9 ms / 20 ms, 여유 55%) |
| **HX711 저속 대응** | Hybrid Blocking 구조 (110 ms 간격 동기 측정 + 직전값 재사용) |
| **데이터 무결성** | XOR 체크섬 1 byte 부가 (실측 패킷 손실률 < 0.1%) |
| **현장 디버깅** | 921,600 bps 모드에서 시리얼 모니터 사용 불가 시 OLED 상태 표시 |

---

## 하드웨어

| 항목 | 사양 |
|------|------|
| **MCU 모듈** | WeAct STM32F411CEU6 (BlackPill V3.1) |
| **CPU 코어** | ARM Cortex-M4 @ 100 MHz |
| **Flash / RAM** | 512 KB / 128 KB |
| **I2C 멀티플렉서** | TCA9548A (8채널, 0x70) |
| **상태 표시** | SSD1306 OLED 0.96" (128×64) |
| **통신 인터페이스** | USART1 (UART) · I2C1 · SPI1 |
| **개발 환경** | STM32CubeMX + STM32CubeIDE + HAL Driver |

---

## 센서 구성

| 종류 | 모델 | 수량 | 인터페이스 | I2C/SPI 주소 / 채널 |
|------|------|------|-----------|---------------------|
| **압력 ADC** | HX711 (24-bit) | 12 | GPIO Bit-banging | 12 × DOUT (개별 GPIO) + 1 × CLK 공유 |
| **1D ToF** | VL53L0X | 4 | I2C (MUX) | 0x29 / TCA9548A CH2–CH5 |
| **3D ToF** | VL53L8CX | 2 | SPI | 개별 NCS 핀 (SPI 버스 공유) |
| **IMU** | MPU6050 | 2 | I2C (MUX) | 0x68 / TCA9548A CH6–CH7 |
| **OLED** | SSD1306 | 1 | I2C (직접) | 0x3C |

> **합계 — 4종 20개 센서 모듈** (HX711 12 + VL53L0X 4 + VL53L8CX 2 + MPU6050 2)

### 물리 로드셀 배치

| 부위 | 종류 | 수량 | HX711 채널 수 | 비고 |
|------|------|------|----------------|------|
| **좌판** | 3선식 50 kg | 8 | 4 | 풀브리지 페어 (2개 = 1채널) |
| **등판** | 4선식 막대형 20 kg | 8 | 8 | 1:1 매핑 |

---

## 폴더 구조

```text
STM32/
│
├── SmartChair.ioc                  # STM32CubeMX 프로젝트 (재생성 가능)
├── STM32F411CEUX_FLASH.ld          # 링커 스크립트
│
├── Core/
│   ├── Inc/                        # 헤더
│   │   ├── main.h
│   │   ├── stm32f4xx_hal_conf.h    # HAL 모듈 활성화 설정
│   │   ├── stm32f4xx_it.h          # 인터럽트 핸들러 선언
│   │   ├── ssd1306.h               # OLED 드라이버
│   │   ├── ssd1306_conf.h
│   │   └── ssd1306_fonts.h
│   │
│   ├── Src/                        # 구현
│   │   ├── main.c                  # 핵심 로직 (핸드셰이크 / 측정 루프 / 패킷 송신)
│   │   ├── stm32f4xx_it.c          # 인터럽트 핸들러
│   │   ├── stm32f4xx_hal_msp.c     # HAL 페리페럴 초기화
│   │   ├── system_stm32f4xx.c      # 시스템 클럭 / SystemInit
│   │   ├── ssd1306.c               # OLED 드라이버
│   │   ├── ssd1306_fonts.c
│   │   ├── syscalls.c              # 표준 라이브러리 시스템 콜
│   │   └── sysmem.c
│   │
│   ├── Startup/
│   │   └── startup_stm32f411ceux.s # 어셈블리 부팅 코드
│   │
│   ├── VL53L0X_API(1D)/            # ST 1D ToF 라이브러리
│   │   ├── core/inc/                  # 9개 헤더 (api / calibration / ranging / def 등)
│   │   ├── core/src/                  # 5개 구현
│   │   └── platform/                  # I2C 플랫폼 어댑터
│   │
│   └── VL53L8CX_API(3D)/           # ST 3D ToF Ultra Lite Driver
│       ├── Platform/                  # SPI 플랫폼 어댑터
│       └── VL53L8CX_ULD_API/
│           ├── inc/                   # 5개 헤더 (api / buffers / plugins)
│           └── src/                   # 4개 구현
│
└── Drivers/                        # ST 표준 SDK
    ├── CMSIS/                         # ARM Cortex 표준 헤더
    └── STM32F4xx_HAL_Driver/          # HAL Driver SDK
```

---

## 동작 흐름

```text
전원 인가
   │
   ├── 시스템 클럭 / 페리페럴 초기화 (HAL)
   │
   ├── 4종 20개 센서 순차 초기화
   │     ├─ OLED (SSD1306)
   │     ├─ 3D ToF × 2 (VL53L8CX, 4×4 모드)
   │     ├─ 1D ToF × 4 (VL53L0X)
   │     ├─ IMU × 2 (MPU6050)
   │     └─ HX711 × 12 (영점 보정 마지막 수행)
   │
   ├── UART 3-way 핸드셰이크 with RPi5
   │     ├─ STM32 → READY\n
   │     ├─ STM32 ← ACK\n
   │     └─ STM32 → LINK_OK\n
   │
   └── 세션 루프 (반복)
         │
         ├── 착석 대기 (CHK_SIT 수신 → SIT 응답)
         │
         ├── 캘리브레이션 (CAL 수신 시)
         │     ├─ 10초 / 500 프레임 / 50 Hz 수집
         │     ├─ 패킷 헤더 'CAL:' 사용
         │     └─ 100 ms 대기 후 CAL_DONE 송신
         │       (마지막 바이너리 → ASCII 혼입 방지)
         │
         ├── 측정 루프 (GO 수신 시)
         │     ├─ 50 Hz 4종 센서 동기 폴링
         │     ├─ 'DAT:' 헤더 + 129 byte 패킷 송신
         │     └─ 자리 이탈 5초 지속 시 STAND 송신
         │
         └── 종료 (STOP / QUIT) → 착석 대기로 복귀
```

---

## 센서 초기화

전원 인가 시 **OLED → 3D ToF → 1D ToF → MPU6050 → HX711** 순으로 초기화한다. 이 순서는 다음 두 가지 이유로 결정되었다.

1. **버스 독립성** — SPI(3D ToF)와 I2C(1D ToF / IMU)는 독립 버스이므로 한쪽 실패가 다른 쪽 동작에 영향 없음
2. **HX711 최후 초기화** — 앞서 초기화된 ToF 센서가 연속 거리 측정 모드로 안정화된 후 영점 보정을 수행하기 위함

### 센서별 설정

| 센서 | 주요 설정 | 근거 |
|------|-----------|------|
| **VL53L8CX (3D ToF)** | 4×4 (16 zones) 모드, 60 Hz 한계 | 8×8 모드는 15 Hz 한계로 50 Hz 루프에서 사용 불가 |
| **VL53L8CX SPI** | 3.125 MHz (APB2 100 MHz / Prescaler 32) | 데이터시트 최대 3 MHz 제약 준수 |
| **VL53L0X (1D ToF)** | Timing budget 20,000 μs | 20 ms 사이클당 1회 측정 완료 |
| **VL53L0X 주소 충돌** | TCA9548A CH2–CH5 분리 | 4개 센서 모두 동일 주소 0x29 |
| **MPU6050** | ±2 g, DLPF 20 Hz, 50 Hz | 의자 기울기 보정용 |
| **HX711** | 10 SPS 고정 (RATE 핀 GND), 24-bit Bit-banging | 모듈 PCB 제약 |
| **HX711 영점 보정** | 500 ms 안정화 + 5회 더미 + 20회 평균 | 과도 응답 제거 |

### 인터럽트 보호 (HX711)

```c
__disable_irq();
// 24-bit bit-banging 읽기 (12채널 동시)
__enable_irq();
```

비트뱅잉 중 인터럽트로 인한 타이밍 오류를 방지하기 위해 24-bit 읽기 구간을 인터럽트 비활성화로 보호한다.

---

## 50 Hz 측정 루프

매 20 ms 사이클마다 **3D ToF → 1D ToF → MPU6050 → HX711** 순으로 폴링한다.

| 순서 | 센서 | 처리 방법 |
|------|------|----------|
| **1** | 3D ToF × 2 | `check_data_ready` 후 새 데이터만 4×4 zones 읽기 (이전 값 유지로 지연 방지) |
| **2** | 1D ToF × 4 | I2C MUX 채널 전환 → 레지스터 직접 읽기 (인터럽트 0x13 → 결과 0x14 → 클리어 0x0B) |
| **3** | MPU6050 × 2 | I2C MUX 채널 전환 → AccX/AccZ → `atan2` 로 pitch (degree) 계산 |
| **4** | HX711 × 12 | Hybrid Blocking (110 ms 간격으로만 동기 측정, 그 외 직전값 재사용) |

### 1D ToF 측정 유효성 검사

```c
RangeStatus ∈ {6 (Signal Rate Low), 9, 11 (Range Valid)}  → 유효
distance > 1200 mm                                         → 무시
```

### 측정 시간 예산

```text
┌─────────────────────────────────────────────────┐
│ 20 ms 사이클                                     │
│  ┌────────────────────┐                         │
│  │ 4종 센서 폴링 ~9 ms │ HAL_GetTick 대기 ~11 ms  │
│  └────────────────────┘                         │
│   (여유 55%)            정확한 50 Hz 유지         │
└─────────────────────────────────────────────────┘
```

실측 결과 센서 수집 + 패킷 송신 완료까지 **약 9 ms** 소요. 평균 **51 Hz** 달성.

---

## 패킷 구조

### Binary Sensor Stream — 129 byte

```text
┌────────────┬──────────────┬──────────────┬─────────────┬───────────┬─────────────┐
│ Header 4B  │ Loadcell 48B │ Spine ToF 8B │ 3D ToF 64B  │ IMU 4B    │ Checksum 1B │
│ "DAT:/CAL:"│ 12 × int32   │ 4 × uint16   │ 32 × uint16 │ 2 × int16 │ XOR (1B)    │
└────────────┴──────────────┴──────────────┴─────────────┴───────────┴─────────────┘
              4 + 48 + 8 + 64 + 4 + 1 = 129 bytes @ 50 Hz
```

| 필드 | 크기 | 내용 |
|------|------|------|
| Header | 4 B | 측정: `"DAT:"` / 캘리브레이션: `"CAL:"` |
| Loadcell | 48 B | HX711 12채널 × 4 B (int32, 영점 보정 후 raw) |
| Spine ToF | 8 B | VL53L0X 4채널 × 2 B (uint16, mm) |
| 3D ToF | 64 B | VL53L8CX 2개 × 16 zones × 2 B (uint16, mm) |
| IMU | 4 B | MPU6050 2개 × 2 B (int16, pitch ×100) |
| Checksum | 1 B | 128 byte 데이터의 XOR |

### 체크섬 검증

```c
uint8_t checksum = 0;
for (int i = 0; i < 128; i++) checksum ^= data[i];
```

수신측(RPi5)에서 동일하게 계산하여 비교, 손상 패킷 폐기.

---

## UART 프로토콜

### ASCII Control Mode

| 방향 | 메시지 | 의미 |
|------|--------|------|
| STM32 → RPi | `READY\n` | 부팅 완료 |
| RPi → STM32 | `ACK\n` | READY 응답 |
| STM32 → RPi | `LINK_OK\n` | 핸드셰이크 완료 |
| RPi → STM32 | `CHK_SIT\n` | 착석 확인 요청 |
| STM32 → RPi | `SIT\n` | 착석 확인 응답 |
| RPi → STM32 | `CAL\n` | 캘리브레이션 시작 |
| STM32 → RPi | `CAL_DONE\n` | 캘리브레이션 완료 (100 ms 대기 후) |
| RPi → STM32 | `GO\n` | 측정 시작 |
| RPi → STM32 | `STOP\n` | 측정 중단 |
| STM32 → RPi | `STAND\n` | 자리 이탈 5초 지속 |

> **CAL_DONE 100 ms 대기 이유**: 마지막 바이너리 패킷과 ASCII 메시지가 연속 전송될 경우 RPi5 의 바이너리 수신 버퍼에 ASCII 가 혼입되는 것을 방지

---

## 핀 매핑

| 페리페럴 | 핀 | 용도 |
|----------|-----|------|
| **USART1** | PA9 (TX) / PA10 (RX) | RPi5 통신 (921,600 bps) |
| **I2C1** | PB6 (SCL) / PB7 (SDA) | TCA9548A MUX + OLED |
| **SPI1** | PA5 (SCK) / PA6 (MISO) / PA7 (MOSI) | VL53L8CX 3D ToF |
| **GPIO** | 12개 | HX711 DOUT (개별) |
| **GPIO** | 1개 | HX711 SCK (공유) |
| **GPIO** | 2개 | VL53L8CX NCS (개별) |

> 정확한 핀 할당은 `SmartChair.ioc` 를 STM32CubeMX 에서 열어 확인할 수 있다.

---

## 빌드 / 플래시

### 1. STM32CubeIDE 사용

1. **STM32CubeIDE** 실행
2. `File` → `Open Projects from File System...`
3. `sourceCode/STM32/` 폴더 선택
4. 프로젝트 임포트 후 `Project` → `Build All` (Ctrl+B)
5. ST-Link 연결 후 `Run` → `Debug` (F11) 또는 `Run` (F11)

### 2. CubeMX 코드 재생성 시

`SmartChair.ioc` 파일의 페리페럴 설정을 수정한 경우:

1. STM32CubeMX 에서 `.ioc` 열기
2. 설정 변경 후 `Project` → `Generate Code`
3. STM32CubeIDE 에서 다시 빌드

> ⚠️ **주의**: CubeMX 코드 재생성 시 `USER CODE BEGIN` / `USER CODE END` 블록 외부의 사용자 코드는 덮어쓰여질 수 있다.

---

## 디버깅

### 시리얼 모니터 (115,200 bps)

UART 보드 레이트를 일시적으로 **115,200 bps** 로 변경하면 Arduino IDE 시리얼 모니터로 다음을 확인할 수 있다.

- 각 센서 초기화 성공 여부
- 실시간 센서 raw 값
- 4종 센서 폴링 소요 시간

### OLED 디버깅 (921,600 bps 운영 모드)

RPi5 와 통신하는 운영 모드에서는 시리얼 모니터 사용이 불가능하므로 **SSD1306 OLED** 를 통해 다음을 표시한다.

- 센서 초기화 결과 (성공/실패)
- 캘리브레이션 진행률
- 실시간 루프 주파수 (Hz)
- 패킷 송신 소요 시간 (ms)

---

## 관련 문서

| 문서 | 위치 |
|------|------|
| **전체 시스템 개요** | [`../../README.md`](../../README.md) |
| **UART 프로토콜 상세** | [`../RaspberryPi/docs/uart_protocol.md`](../RaspberryPi/docs/uart_protocol.md) |
| **STM32 연동 체크리스트** | [`../RaspberryPi/docs/stm32_integration_checklist.md`](../RaspberryPi/docs/stm32_integration_checklist.md) |
| **센서 인덱스 매핑** | [`../RaspberryPi/docs/sensor_index_mapping.md`](../RaspberryPi/docs/sensor_index_mapping.md) |
| **센서 배치도** | [`../RaspberryPi/docs/sensor_layout.md`](../RaspberryPi/docs/sensor_layout.md) |
