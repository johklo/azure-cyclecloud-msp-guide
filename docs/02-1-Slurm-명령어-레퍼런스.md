# 2-1. Slurm 명령어 레퍼런스 (출력 해석 · 옵션 · 이용내역)

[2장](02-Slurm-개념-및-사용-가이드.md)이 CycleCloud 연동 관점의 운영 흐름을 다룬다면, 이 문서는 Slurm 명령어의 **출력 필드 해석**과 **옵션 표**를 명령어별로 정리한다. 최종 사용자(연구자·개발자)의 작업 제출을 지원하거나 상태를 해석할 때 참고한다. 예시의 노드 이름·파티션 이름은 환경마다 다르므로 형식만 참고한다.

> 📌 이 문서의 파티션·노드 이름(`cpu01`, `gpu01`, `debug`, `edu` 등)은 설명용 예시이다. 실제 값은 `sinfo`로 확인한다.

---

## 2-1.1 작업(Job) 상태

작업은 제출 이후 다음 상태를 거친다. `squeue`의 `ST` 열과 `scontrol show job`의 `JobState`에서 확인한다.

| 상태 | 약어 | 의미 |
|------|------|------|
| PENDING | PD | 자원 할당을 기다리는 대기 상태 |
| RUNNING | R | 자원을 할당받아 실행 중인 상태 |
| COMPLETING | CG | 작업이 종료되며 자원을 정리 중인 상태 |
| COMPLETED | CD | 모든 프로세스가 종료 코드 0으로 정상 종료된 상태 |
| SUSPENDED | S | 작업이 일시 중지되고 자원 할당이 해제된 상태(이전 중지 시점부터 재개 가능) |
| CANCELLED | CA | 사용자 또는 관리자가 취소한 상태 |
| FAILED | F | 0이 아닌 종료 코드 또는 실패 조건으로 종료된 상태 |
| TIMEOUT | TO | 최대 실행 시간에 도달하여 종료된 상태 |
| NODE_FAIL | NF | 할당된 노드 장애로 종료된 상태 |

---

## 2-1.2 기본 용어

| 용어 | 설명 |
|------|------|
| Cluster | 노드·파티션·계정·사용자·작업을 관리하는 자원 풀 |
| Node | 클러스터를 구성하는 개별 컴퓨터 자원 |
| Login Node | 작업 제출·편집만 수행하는 노드(연산 금지) |
| Control Node | 자원 상태 감시·자원 관리·작업 스케줄링을 담당하는 노드(`slurmctld`) |
| Compute Node | 실제 작업이 실행되는 노드(`slurmd`) |
| Job | 사용자가 Slurm에 제출한 실행 단위(프로세스 또는 스크립트) |
| Partition(Queue) | 작업이 실행될 수 있는 노드들의 논리적 그룹 |
| Resource | 작업에 사용하는 자원(CPU, GPU, 메모리 등) |
| Account | 사용자의 자원 사용을 관리·추적·제어하는 단위(우선순위·사용량 집계) |
| User | Slurm에 작업을 제출하는 사용자 |

---

## 2-1.3 sinfo — 파티션·노드 상태

파티션과 노드 상태를 확인한다.

```bash
sinfo                 # 파티션별 요약
sinfo -l              # 전체 파티션 상세
sinfo -p <파티션> -l  # 지정 파티션 상세
sinfo -N -l           # 노드별 상세
sinfo -o "%N %G"      # 노드별 등록된 GRES(gpu:a100:8 등)
```

기본 출력 필드:

| 필드 | 설명 |
|------|------|
| PARTITION | 파티션 이름(`*`는 기본 파티션) |
| AVAIL | 사용 가능 여부(`up`/`down`/`drain`) |
| TIMELIMIT | 최대 사용 제한 시간 |
| NODES | 파티션에 할당된 노드 수 |
| STATE | 노드 상태(아래 표) |
| NODELIST | 파티션을 구성하는 노드 목록 |

노드 상태 값:

| 상태 | 의미 |
|------|------|
| `idle` | 모든 노드가 사용 가능한 상태 |
| `mix` | 일부 자원이 사용 중이며 추가 작업을 수락할 수 있는 상태 |
| `alloc` | 모든 자원이 사용 중이라 추가 작업을 수락할 수 없는 상태 |
| `drain`/`draining` | 실행 중인 작업 완료를 기다리며 새 작업 할당을 막은 상태 |
| `down` | 노드가 비정상이라 사용할 수 없는 상태 |
| `plnd` | 특정 작업을 위해 예약된 상태 |

> CycleCloud Autoscale 환경에서는 상태에 접미 기호가 붙는다(`idle~` 절전, `#` 기동 중 등). 접미 기호 해석은 [2장 §2.5](02-Slurm-개념-및-사용-가이드.md#25-노드큐-상태-확인)를 참고한다.

### 파티션 자원 정책 (Exclusive vs Shared)

| 정책 | 동작 |
|------|------|
| Exclusive(독점) | 하나의 노드에 하나의 작업만 배치. 단일 코어 작업이어도 노드 전체 자원을 점유 |
| Shared(공유) | 여러 작업이 노드의 자원을 나눠 사용 |

작업의 자원 요구에 맞는 파티션을 선택해야 자원 낭비와 과금을 줄일 수 있다.

---

## 2-1.4 squeue — 작업 큐

제출된 작업 내역을 확인한다.

```bash
squeue                # 전체 작업
squeue -u <사용자>    # 지정 사용자 작업
squeue -p <파티션>    # 지정 파티션 작업
squeue --me           # 내 작업
squeue -i <초>        # 지정 간격으로 반복 출력
```

출력 필드:

| 필드 | 설명 |
|------|------|
| JOBID | 작업에 부여된 고유 번호 |
| PARTITION | 작업이 사용하는 파티션 |
| NAME | 작업 이름 |
| USER | 작업을 제출한 사용자 |
| ST | 작업 상태(§2-1.1) |
| TIME | 실행 경과 시간 |
| NODES | 할당된 노드 수 |
| NODELIST(REASON) | 할당된 노드 목록. 대기 중이면 `(REASON)`으로 사유 표시 |

대기 사유(REASON) 해석은 [2장 §2.8](02-Slurm-개념-및-사용-가이드.md#대기-작업의-사유reason-해석)에 정리돼 있다.

---

## 2-1.5 sshare — Fair-Share

계정 또는 사용자의 Fair-Share 값을 확인한다.

```bash
sshare
```

| 필드 | 설명 |
|------|------|
| Account | 계정 이름 |
| User | 사용자 이름 |
| RawShare | 계정에 할당된 자원의 양 |
| NormShares | RawShare를 전체 Share 합계로 나눈 비율 |
| RawUsage | 계정·사용자의 자원 사용량 |
| NormUsage | RawUsage를 전체 사용량 합계로 나눈 비율 |
| EffectvUsage | 계정의 현재 자원 사용 비율 |
| FairShare | 스케줄링 우선순위 결정에 쓰이는 값 |

Fair-Share는 사용량에 따라 우선순위를 조정해 자원을 공평하게 분배하는 정책이다.

- 사용량이 많을수록 우선순위가 낮아지고, `FairShare` 값이 높을수록 자원 할당 우선순위가 높다.
- CPU·GPU 사용량에 영향을 받으며, 누적 사용량(RawUsage)은 일정 주기로 감소해 과거 사용의 영향이 점차 줄어든다.

---

## 2-1.6 srun — 즉시 실행 · 대화형

자원을 할당받아 하나의 명령을 실행하거나 대화형 작업을 수행한다.

```bash
srun -p <파티션> -N 1 -n 1 hostname
srun -p <파티션> -N 1 -n 1 -c 1 --pty bash    # 대화형 셸
```

주요 옵션:

| 단축 | 전체 | 설명 |
|------|------|------|
| `-N` | `--nodes` | 사용할 노드 수 |
| `-n` | `--ntasks` | 사용할 프로세스(태스크) 수 |
| `-c` | `--cpus-per-task` | 태스크당 CPU 코어 수 |
| `-t` | `--time` | 최대 실행 시간 |
| `-p` | `--partition` | 실행할 파티션 |
| `-J` | `--job-name` | 작업 이름 |
| `-x` | `--exclude` | 제외할 노드 |
| `-w` | `--nodelist` | 지정할 노드 |
| `-o` | `--output` | 표준 출력 저장 파일 |
| `-e` | `--error` | 에러 저장 파일 |
| `-v` | `--verbose` | 상세 출력(반복 시 `-vvvv`) |
| | `--mem` | 메모리 사용량(MB) |
| | `--gres` | 일반 리소스 지정(예: `gpu:1`) |
| | `--ntasks-per-node` | 노드당 프로세스 수 |
| | `--pty` | 터미널 연결(대화형) |
| | `--exclusive` | 노드 자원을 독점 |

파일 이름에 `%j`를 쓰면 작업 ID로 치환된다(`out_%j.log`).

---

## 2-1.7 salloc — 자원 예약 후 셸

`srun`과 유사하지만, 자원만 할당받은 상태에서 프롬프트로 명령을 실행한다.

```bash
salloc -p <파티션> -N 1 -n 1
# 할당된 환경에서
hostname
srun -N 1 -n 1 hostname
exit                 # 자원 반납
```

---

## 2-1.8 sbatch — 배치 작업

배치 스크립트의 `#SBATCH` 지시문에 따라 자원을 요청하고, 할당되면 순서대로 실행한다.

```bash
cat << 'EOF' > test.sh
#!/bin/bash
#SBATCH -J my_test
#SBATCH -p <파티션>
#SBATCH -o my_test_%j.out
#SBATCH -e my_test_%j.err
#SBATCH -N 1
#SBATCH -n 1
srun hostname
sleep 100
EOF

sbatch test.sh
```

`#SBATCH` 주요 지시문:

| 지시문 | 전체 | 설명 |
|--------|------|------|
| `-J` | `--job-name` | 작업 이름 |
| `-t` | `--time` | 최대 실행 시간 |
| `-o` | `--output` | 작업 로그 파일 |
| `-e` | `--error` | 에러 파일 |
| `-p` | `--partition` | 파티션 |
| `-w` | `--nodelist` | 작업 수행 노드 지정 |
| `-N` | `--nodes` | 노드 수 |
| `-n` | `--ntasks` | 프로세스 수 |
| `-c` | `--cpus-per-task` | 프로세스당 CPU 코어 수 |
| | `--gres` | 특정 리소스 지정(예: `gpu:1`) |
| | `--cpus-per-gpu` | GPU당 CPU 코어 수 |
| | `--comment` | 작업 주석 |
| | `--exclusive` | 노드 자원 독점 |

> ⚠️ `sbatch` 없이 배치 스크립트를 직접 실행하면 **로그인 노드에서 작업이 실행**되어 전체 클러스터에 영향을 줄 수 있다. 반드시 `sbatch`로 제출한다.

MPI·GPU·Array·의존성 등 확장 패턴은 [2장 §2.4](02-Slurm-개념-및-사용-가이드.md#24-작업-제출)에 정리돼 있다.

---

## 2-1.9 scontrol — 상태 조회·수정

작업·파티션·노드의 상세 정보를 확인하거나 상태를 수정한다.

```bash
scontrol show job <작업ID>          # 작업 상세
scontrol show partition <파티션>    # 파티션 상세
scontrol show node <노드명>         # 노드 상세
```

`scontrol show job` 출력에서 자주 보는 항목:

| 항목 | 의미 |
|------|------|
| `JobState` / `Reason` | 작업 상태와 대기 사유 |
| `RunTime` / `TimeLimit` | 실행 경과·최대 실행 시간 |
| `SubmitTime` / `StartTime` / `EndTime` | 제출·시작·종료 시각 |
| `NodeList` / `BatchHost` | 할당된 노드와 배치 처리 호스트 |
| `NumNodes` / `NumCPUs` / `NumTasks` | 할당된 노드·CPU·태스크 수 |
| `TRES` | 할당된 자원(cpu·mem·node·gpu) |
| `Command` / `WorkDir` | 실행된 명령과 작업 디렉터리 |
| `StdOut` / `StdErr` | 표준 출력·에러 저장 경로 |

`scontrol show node` 출력에서 자주 보는 항목:

| 항목 | 의미 |
|------|------|
| `CPUAlloc` / `CPUTot` | 사용 중 / 전체 CPU 수 |
| `Gres` / `AllocTRES` | 등록된 GPU와 현재 사용 중인 자원 |
| `RealMemory` / `AllocMem` / `FreeMem` | 전체·할당·여유 메모리 |
| `State` | 노드 상태(`IDLE`/`MIXED`/`ALLOCATED`/`DOWN` 등) |
| `Partitions` | 노드가 속한 파티션 |

노드 상태 복구 등 수정 명령은 [2장 §2.6](02-Slurm-개념-및-사용-가이드.md#26-cyclecloud-연동-autoscale--설정-변경)을 참고한다.

---

## 2-1.10 scancel — 작업 취소

실행 중이거나 대기 중인 작업을 종료한다.

```bash
squeue --me           # 취소할 작업 ID 확인
scancel <작업ID>      # 지정 작업 종료
```

취소 시 자원 정리(cgroup 기반) 순서는 [2장 §2.1.1](02-Slurm-개념-및-사용-가이드.md#211-job-라이프사이클과-프로세스-정리-개념-이해용-참고)에 정리돼 있다.

---

## 2-1.11 이용내역 조회

### 작업량 조회 (`sacct`)

완료된 작업의 이력·상태·자원 사용량을 조회한다(slurmdbd 필요).

```bash
sacct -S 2024-06-01 -E 2024-07-01 \
  --format="JobID,JobName,Partition,State,AllocTRES,ElapsedRaw"
sacct -j <작업ID> --format=JobID,JobName,Partition,Elapsed,State,ExitCode,MaxRSS
```

- `-S` / `-E`: 조회 시작·종료 일자
- `--format`: 출력할 필드 지정

### 이용료 조회 (사이트별)

과금·이용료 집계 스크립트는 사이트마다 다르다(예: `billing.pl` 형태의 사내 스크립트). 제공되는 스크립트의 `--help`로 사용법을 확인한다. CycleCloud 자체 비용은 Azure Cost Management에서 확인한다.

---

## 2-1.12 사용 시 안내사항

- 로그인 노드에서 연산 작업을 실행하지 않는다(작업은 `sbatch`/`srun`으로 제출).
- 다른 사용자의 파일에 접근하지 않는다.
- 중요한 파일의 권한은 최소한으로 설정한다(예: `700`).
- 소프트웨어 라이선스 정책을 준수한다.
- 작업이 정상 수행되지 않으면 실행 내용과 메시지·에러 로그를 함께 첨부해 문의한다.

---

## 참고 자료

- [Slurm 공식 문서 (SchedMD)](https://slurm.schedmd.com/)
- [Slurm 명령어 매뉴얼 (man pages)](https://slurm.schedmd.com/man_index.html)
- 각 명령어의 상세 옵션은 `<command> --help` 또는 `man <command>`로 확인한다.

---

다음 단계: [3. 신규 클러스터 생성](03-신규-클러스터-생성.md)
