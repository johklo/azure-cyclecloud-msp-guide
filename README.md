# Azure CycleCloud 운영 가이드 (MSP)

Cloud MSP 운영 담당자를 위한 **Azure CycleCloud** 최초 구축 및 운영법을 정리한 한국어 운영 가이드다.

---

## 📂 디렉터리 구조
```
cyclecloud/
└─ docs/                       # 운영 가이드 (마크다운) & 스크린샷
   ├─ README.md                # 교육 마스터 목차 (커리큘럼)
   ├─ 01-HPC-및-CycleCloud-아키텍처.md
   ├─ 02-Slurm-개념-및-사용-가이드.md
   ├─ 02-1-Slurm-명령어-레퍼런스.md
   ├─ 03-신규-클러스터-생성.md
   ├─ 03-1-싱글-노드-배포.md
   ├─ 04-cluster-init-및-커스텀-스크립트.md
   ├─ 05-노드-증감설-사이즈변경.md
   ├─ 06-파티션-관리-및-추가.md
   ├─ 07-데이터-디스크-마운트.md
   ├─ 08-스토리지-NFS-마운트.md
   ├─ 09-디스크-사이즈-변경.md
   ├─ 10-사용자-관리.md
   ├─ 11-Job-Accounting-설정.md
   ├─ 12-모니터링.md
   ├─ 12-1-모니터링-Prometheus-Grafana.md
   ├─ 13-트러블슈팅-로그.md
   ├─ 14-버전-확인.md
   └─ images/                  # 실습 스크린샷 모음
```

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
| **트러블슈팅 및 로그 확인** | [13. 트러블슈팅 로그](docs/13-트러블슈팅-로그.md) |
| **버전 확인** | [14. 버전 확인](docs/14-버전-확인.md) |

---

## ⚡ 시작하기

- **교육 커리큘럼 / 운영 가이드 목차**: [docs/README.md](docs/README.md)