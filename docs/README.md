# Azure CycleCloud 운영 교육 가이드 (MSP)

Azure CycleCloud 운영 지침을 정리한 MSP 운영 담당자용 교육 가이드이다.

---

## 🎯 대상 독자
- Azure CycleCloud를 처음 접하는 MSP / 운영 담당자
- HPC(고성능 컴퓨팅) 클러스터를 Azure 상에서 구축, 운영, 엔지니어링하는 담당자
- CycleCloud 운영 및 기술 지원 담당자

---

## 🧩 표기 규칙 (환경 독립 Placeholder)

이 가이드의 명령·템플릿은 **특정 환경에 종속되지 않도록** 아래 플레이스홀더를 사용한다. 실제 수행 시 각자의 환경 값으로 **치환**해 그대로 복사·실행하면 된다(`< >` 포함해 통째로 교체).

| Placeholder | 의미 | 예시 |
|---|---|---|
| `<서버VM>` | CycleCloud 서버 VM 이름 | `cc-server` |
| `<리소스그룹>` | 리소스가 위치한 리소스 그룹 | `rg-cyclecloud` |
| `<서버IP>` | 서버 공인 IP 또는 DNS | `20.10.20.30` |
| `<NSG>` | 서버 NSG 이름 | `cc-nsg` |
| `<클러스터명>` | Slurm 클러스터 이름 | `slurm-first` |
| `<노드명>` | 노드 이름 | `<클러스터명>-hpc-1` |
| `<스토리지계정>` | NFS/Blob 데이터용 스토리지 계정 | `mynfsdata` |
| `<공유명>` | NFS 공유(share)/컨테이너 이름 | `data1` |
| `<Locker스토리지>` | Locker(프로젝트) 스토리지 계정 | `myprojlocker` |
| `<VNet>` / `<컴퓨트서브넷>` | 클러스터 VNet / 컴퓨트 서브넷 | `ccw-vnet` / `ccw-compute-subnet` |
| `<SSH키>` | 노드/서버 접속 SSH 개인키 경로 | `~/.ssh/cyclecloud_rsa` |
| `<리전>` | Azure 리전 | `koreacentral` |

> 💡 각 문서의 명령은 **순서대로 복사·실행**하면 동작하도록 구성돼 있다. `< >` 로 감싼 값만 본인 환경으로 바꾼다.

---

## 📚 교육 커리큘럼 및 실습 목차 (14개 모듈)

### Part 0. 개념 (HPC · Slurm) — 약 35분
1. [01. HPC & CycleCloud 아키텍처 (범용 HPC 개념 포함)](01-HPC-및-CycleCloud-아키텍처.md)
2. [02. Slurm 개념 및 사용 가이드 (노드 유형 · 명령어 · 작업 제출)](02-Slurm-개념-및-사용-가이드.md)
    - [02-1. Slurm 명령어 레퍼런스 (출력 해석 · 옵션 · 이용내역)](02-1-Slurm-명령어-레퍼런스.md)

### Part 1. 클러스터 구축
3. **[03. CycleCloud 신규 생성 및 최초 클러스터 구축 (First-Time Setup)](03-신규-클러스터-생성.md)**
    - [03-1. 싱글 노드 배포 (Single VM)](03-1-싱글-노드-배포.md)
4. [04. Cluster-Init 및 커스텀 스크립트 (cloud-init vs cluster-init)](04-cluster-init-및-커스텀-스크립트.md)

### Part 2. 운영 (노드 · 스토리지 · 사용자)
5. [05. 노드 증/감설, 사이즈 변경 & Scale-in 방지](05-노드-증감설-사이즈변경.md)
6. [06. 파티션 관리 및 추가 (azure.conf)](06-파티션-관리-및-추가.md)
7. [07. 데이터 디스크 마운트](07-데이터-디스크-마운트.md)
8. [08. 스토리지 마운트 (NFS · 공유 파일시스템)](08-스토리지-NFS-마운트.md)
9. [09. 디스크 사이즈 변경 (OS/부팅 디스크)](09-디스크-사이즈-변경.md)
10. [10. 사용자 관리 (Built-in Users & Keypair)](10-사용자-관리.md)
11. [11. Slurm Job Accounting 구축 (MySQL Flexible Server)](11-Job-Accounting-설정.md)

### Part 3. 관측 & 문제해결
12. [12. 모니터링 (상태 확인, 로그, 알림)](12-모니터링.md)
    - [12-1. 모니터링 — Prometheus + Grafana (HPC/GPU 메트릭)](12-1-모니터링-Prometheus-Grafana.md)
13. [13. 기본 트러블슈팅 및 로그 확인 (Triage Matrix)](13-트러블슈팅-로그.md)
14. [14. 버전 정보 확인 (CycleCloud / Slurm)](14-버전-확인.md)


### 🧪 실습 종합 (End-to-End, 환경 구축부터)
- **[Azure CycleCloud 운영 실습 가이드 (Generic)](CycleCloud-운영-실습-가이드.md)** — 사전 조건(VNet·NAT·스토리지·Managed Identity+권한·서버 VM)을 **az CLI 로 직접 구축**하는 절차부터, 클러스터 생성·증감설·사이즈 변경·NFS/디스크 마운트·단일 노드 추가·트러블슈팅까지 **복사-붙여넣기 단계별** 으로 정리한 문서이다. 고객이 자체 환경에서 처음부터 따라 할 수 있는 통합 가이드이다.
