# Azure CycleCloud 운영 가이드 (MSP)

Cloud MSP 운영 담당자를 위한 **Azure CycleCloud** 최초 구축 및 운영법을 정리한 한국어 운영 가이드다.

---

## 📂 디렉터리 구조
```
cyclecloud/
├─ docs/                       # 운영 가이드 (마크다운) & 스크린샷
│  ├─ README.md                # 교육 마스터 목차 (커리큘럼)
│  ├─ 01-HPC-및-CycleCloud-아키텍처.md
│  ├─ 02-Slurm-개념-및-사용-가이드.md
│  ├─ 02-1-Slurm-명령어-레퍼런스.md
│  ├─ 03-신규-클러스터-생성.md
│  ├─ 03-1-싱글-노드-배포.md
│  ├─ 04-cluster-init-및-커스텀-스크립트.md
│  ├─ 05-노드-증감설-사이즈변경.md
│  ├─ 06-파티션-관리-및-추가.md
│  ├─ 07-데이터-디스크-마운트.md
│  ├─ 08-스토리지-NFS-마운트.md
│  ├─ 09-디스크-사이즈-변경.md
│  ├─ 10-사용자-관리.md
│  ├─ 11-Job-Accounting-설정.md
│  ├─ 12-모니터링.md
│  ├─ 12-1-모니터링-Prometheus-Grafana.md
│  ├─ 14-버전-확인.md
│  ├─ videos/                  # 실습 데모 영상 (mp4)
│  └─ images/                  # 실습 스크린샷 모음
└─ templates/                  # 클러스터 템플릿 예시 조각 (txt)
```

---

## 🎬 데모 영상

주요 절차는 영상으로도 제공한다. 화면과 명령·출력은 문서와 실제 실습 환경에서 확인한 값을 그대로 옮겼다.

| 영상 | 길이 | 내용 | 관련 문서 |
|------|------|------|-----------|
| [CycleCloud 서버 구축](docs/videos/03-0-CycleCloud-서버-구축.mp4) | 2:21 | 서브넷·UAMI(locker-mi)·서버 VM·System MI 권한·사이트 초기화·구독 등록 | [03 §3.1~3.2](docs/03-신규-클러스터-생성.md) |
| [신규 클러스터 생성](docs/videos/03-신규-클러스터-생성.mp4) | 2:45 | 클러스터 생성 마법사, Start, CLI 초기화·`srun` 검증·SSH 키 | [03](docs/03-신규-클러스터-생성.md) |
| [싱글 노드 배포 (GUI)](docs/videos/03-1-싱글-노드-배포-GUI.mp4) | 1:20 | Single VM 클러스터 생성과 기동 | [03-1](docs/03-1-싱글-노드-배포.md) |
| [노드 증설](docs/videos/05-1-노드-증설.mp4) | 1:21 | GUI Max 상향 → `azslurm scale` (순서를 어기면 Unknown node name) | [05 §5.2](docs/05-노드-증감설-사이즈변경.md) |
| [노드 감설](docs/videos/05-2-노드-감설.mp4) | 1:30 | 작업 확인 → `azslurm suspend` → `azure.conf` 축소 → GUI Save | [05 §5.2](docs/05-노드-증감설-사이즈변경.md) |
| [Scale-in 방지](docs/videos/05-3-Scale-in-방지.mp4) | 1:43 | RI·GPU 노드 자동 회수 차단 — `SuspendExcParts` + `scontrol reconfigure` | [05 §5.1](docs/05-노드-증감설-사이즈변경.md) |
| [cluster-init 으로 NFS 마운트](docs/videos/08-cluster-init-NFS-마운트.mp4) | 3:41 | 프로젝트 생성부터 마운트 추가(버전 업 → 재지정)까지 | [04](docs/04-cluster-init-및-커스텀-스크립트.md) · [08](docs/08-스토리지-NFS-마운트.md) |

> GitHub 웹에서는 파일을 열면 바로 재생된다. 내려받으려면 파일 페이지의 **Download** 를 사용한다.

---

## 📋 교육 범위 및 요청 사항 매핑

| 요청 사항 | 담당 문서 |
|-----------|-----------|
| **HPC & Slurm 개념** | [01. HPC & CycleCloud 아키텍처](docs/01-HPC-및-CycleCloud-아키텍처.md) · [02. Slurm 개념 및 사용 가이드](docs/02-Slurm-개념-및-사용-가이드.md) · [02-1. Slurm 명령어 레퍼런스](docs/02-1-Slurm-명령어-레퍼런스.md) |
| **최초 클러스터 구축 및 포털 사용** | [03. 신규 클러스터 생성](docs/03-신규-클러스터-생성.md) · [03-1. 싱글 노드 배포](docs/03-1-싱글-노드-배포.md) |
| **Cluster-Init & cloud-init** | [04. cluster-init 및 커스텀 스크립트](docs/04-cluster-init-및-커스텀-스크립트.md) |
| **노드 증/감설, 사이즈 변경** | [05. 노드 증감설 사이즈변경](docs/05-노드-증감설-사이즈변경.md) |
| **파티션 관리** | [06. 파티션 관리 및 추가](docs/06-파티션-관리-및-추가.md) |
| **디스크 · 스토리지 마운트** | [07. 데이터 디스크 마운트](docs/07-데이터-디스크-마운트.md) · [08. 스토리지 NFS 마운트](docs/08-스토리지-NFS-마운트.md) · [09. 디스크 사이즈 변경](docs/09-디스크-사이즈-변경.md) |
| **사용자 관리** | [10. 사용자 관리](docs/10-사용자-관리.md) |
| **Job Accounting** | [11. Job Accounting 설정](docs/11-Job-Accounting-설정.md) |
| **모니터링** | [12. 모니터링](docs/12-모니터링.md) · [12-1. Prometheus + Grafana](docs/12-1-모니터링-Prometheus-Grafana.md) |
| **버전 확인** | [14. 버전 확인](docs/14-버전-확인.md) |

---

## ⚡ 시작하기

- **교육 커리큘럼 / 운영 가이드 목차**: [docs/README.md](docs/README.md)