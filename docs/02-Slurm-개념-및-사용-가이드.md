# 2. Slurm 개념 및 사용 가이드 (노드 유형 · 명령어 · 작업 제출)

CycleCloud로 배포한 Slurm 클러스터의 구성 요소와 일상 운영 명령어를 정리한다. 대상은 Slurm을 처음 다루는 운영 담당자이다.

노드 유형(Login/Scheduler/Compute)의 일반 개념은 [1장 §1.2 HPC 클러스터의 노드 유형](01-HPC-및-CycleCloud-아키텍처.md#12-hpc-클러스터의-노드-유형)에서 먼저 확인한다. 이 문서는 그 개념을 Slurm 관점에서 구체화한다.

> 📌 **Cloud MSP 운영 범위 안내**
> — 아래 Slurm 데몬, 작업 제출, 자원 정책은 **지원 문의 대응을 위한 배경 지식**이다.
> - Cloud MSP의 실제 책임은 **인프라 운영/관리**(노드 증감, 스토리지 마운트, 상태/로그 확인 등)이며, `sbatch`/QOS 같은 작업 제출, 튜닝은 주로 **최종 사용자(연구자·개발자)의 영역**이다.
> - 개념 이해용 참고"로 표시된 절은 세부 암기 없이 흐름만 파악하면 충분하다.

---

## 2.1 Slurm 데몬과 노드 구성

Slurm은 SchedMD가 개발한 오픈소스 HPC 작업 스케줄러이다. 클러스터는 다음 데몬으로 동작한다.

| 데몬 | 실행 위치 | 역할 |
|------|-----------|------|
| **slurmctld** | 스케줄러 노드 | 중앙 컨트롤러로, 자원 상태 감시·작업 큐 관리·자원 할당·정책 적용을 담당 |
| **slurmd** | 계산 노드 | 노드별 1개. `slurmstepd`를 기동하고 로컬 자원을 `slurmctld`에 보고 |
| **slurmstepd** | 계산 노드 | 작업 단계(job step)별로 기동되어 사용자 태스크 실행과 I/O·시그널·계정 처리를 담당 |
| **slurmdbd** | 스케줄러 노드(옵션) | Job Accounting DB 데몬으로, 계정 정보 수집과 사용자/그룹 한도·fairshare 관리를 담당 (→ [11장](11-Job-Accounting-설정.md)) |

`slurmctld`가 중단되면 스케줄링 전체가 멈춘다. 스케줄러 노드는 상시 1대 유지되며 Autoscale 대상에서 제외된다.

### 2.1.1 Job 라이프사이클과 프로세스 정리 (개념 이해용 참고)

`sbatch`로 제출된 Job은 **slurmctld(배치 결정) → slurmd(노드 수신) → slurmstepd(격리 실행)** 순으로 처리된다. `slurmd`는 사용자 코드를 직접 실행하지 않고 `slurmstepd`를 fork해 실행 위험을 격리하며, `cgroup`으로 CPU·메모리·GPU 사용 범위를 제한하고 추적한다.

```
slurmd (root, 데몬)
 └─ slurmstepd (root, cgroup 설정)
     └─ bash (사용자 UID/GID로 실행되는 Job 스크립트)
         └─ python train.py → GPU worker / 데이터로더 등
```

**Job 취소·종료 시 정리 순서** (좀비 GPU 프로세스 방지의 핵심):

1. `scancel`로 cgroup 내 프로세스에 **SIGTERM**(정리 요청)을 전달
2. `KillWait`(기본 30초) 유예 대기
3. 유예 후에도 살아 있으면 **SIGKILL**로 강제 종료
4. cgroup에 속한 **모든 하위 PID**까지 추적 정리하고 GPU·임시파일을 해제한 뒤 노드를 깨끗한 상태로 복원

> 이전 Job의 좀비 프로세스가 GPU를 점유해 다음 Job이 실행되지 않는 문제는 이 cgroup 기반 정리로 방지된다(`task/cgroup`, `proctrack/cgroup` 플러그인 설정 시 적용).

---

## 2.2 노드 유형과 파티션

Slurm의 **파티션(Partition)** 은 노드 집합에 대한 작업 큐이다. CycleCloud에서는 파티션이 **NodeArray** 에 대응하며, 하나 이상의 VM Scale Set으로 배포된다.

| 파티션 | 워크로드 | VM 계열 | `slurm.hpc` |
|--------|----------|---------|-------------|
| **hpc** | 긴밀결합(MPI) 다중 노드 작업 | InfiniBand/RDMA(`HB`, `HC`, `ND`) | `true` — 단일 VMSS·근접배치 |
| **htc** | 느슨결합(독립 태스크) 배치 작업 | 범용(`D`, `F`) | `false` |
| **gpu** | GPU 작업 | `NC`, `ND`, `NG` | 용도에 따라 |

- `hpc` 파티션은 단일 VMSS 경계 안에서만 저지연 통신이 보장된다. **Max VMs per Scaleset** 값이 단일 MPI 작업의 최대 노드 규모를 제한한다.
- 신규 파티션 추가는 [06장](06-파티션-관리-및-추가.md)을 참고한다.

---

## 2.3 기본 명령어

명령은 클러스터의 어느 노드에서나 실행할 수 있다. 대부분 단축 옵션(`-p`)과 전체 옵션(`--partition=`)을 지원하며, `-v`를 반복하면 상세 로그가 출력된다(`-vvvv`).

| 명령 | 용도 |
|------|------|
| `sinfo` | 파티션·노드 상태 조회 |
| `squeue` | 작업 큐 조회 |
| `sbatch` | 스크립트를 배치 작업으로 제출 |
| `srun` | 작업 할당 후 job step 실행 (대화형/병렬) |
| `salloc` | 대화형 작업 할당 후 셸 시작 |
| `scancel` | 실행 중/대기 작업 취소 |
| `scontrol` | 스케줄러·노드 상태 조회 및 수정 |
| `sacct` | 완료된 작업의 Accounting 조회 (slurmdbd 필요) |

> 각 명령어의 출력 필드 해석과 전체 옵션 표는 [02-1. Slurm 명령어 레퍼런스](02-1-Slurm-명령어-레퍼런스.md)에 정리돼 있다.

---

## 2.4 작업 제출

### 배치 작업 (`sbatch`)

작업 스크립트를 작성해 제출한다. `#SBATCH` 지시문으로 자원을 요청한다.

```bash
cat << 'EOF' > job.sh
#!/bin/bash
#SBATCH --job-name=test
#SBATCH --partition=htc
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=result-%j.log

hostname
sleep 30
EOF

sbatch job.sh
```

명령을 직접 감싸 제출할 수도 있다.

```bash
sbatch --wrap="/bin/hostname" --partition=htc
```

### 대화형 작업 (`salloc`)

자원을 할당받아 대화형 셸에서 실행한다.

```bash
salloc --partition=htc --nodes=1
```

### MPI 작업 (`srun`)

`hpc` 파티션에서 여러 노드에 태스크를 분산한다.

```bash
sbatch --partition=hpc --nodes=2 --ntasks-per-node=2 --wrap="srun ./mpi_app"
```

Autoscale이 켜져 있으면 작업 제출 시 필요한 계산 노드가 자동으로 기동된다. 최초 기동에는 수 분이 걸린다.

### 대화형 GPU 세션 (`srun --pty`)

GPU 노드에 직접 접속해 디버깅할 때 쓴다. 끝나면 반드시 `exit`으로 자원을 반납하며, `--time`으로 최대 실행 시간을 지정하는 습관을 권장한다.

```bash
srun --partition=gpu --gres=gpu:1 --cpus-per-task=8 --mem=32G --time=01:00:00 --pty bash
```

### GPU 자원 세밀 지정 (GRES)

여러 GPU 타입이 섞인 클러스터에서는 타입을 지정해 할당한다.

```bash
sinfo -o "%N %G"                 # 노드별 등록된 GRES(gpu:a100:8 등) 확인
srun --gres=gpu:h100:1 --pty bash
```

### Job 배열 (Array Job)

하이퍼파라미터 조합처럼 유사 작업 여러 개를 한 번에 제출한다. `$SLURM_ARRAY_TASK_ID`로 각 작업을 분기한다.

```bash
sbatch --array=0-24%10 job.sh    # 총 25개 작업, 동시 실행은 최대 10개
```

### 멀티노드 분산 학습

Slurm이 주입하는 환경변수로 마스터 주소·노드 수를 하드코딩 없이 구성한다.

```bash
#SBATCH --nodes=2
#SBATCH --gres=gpu:8
export MASTER_ADDR=$(scontrol show hostname $SLURM_NODELIST | head -n1)
export MASTER_PORT=$((10000 + SLURM_JOB_ID % 50000))
srun torchrun --nnodes=$SLURM_NNODES --nproc-per-node=8 ... train.py
```

### Job 의존성 체이닝 (파이프라인)

"전처리 → 학습 → 평가"처럼 순차 실행을 자동화한다.

```bash
JOB1=$(sbatch --parsable preprocess.sh)
JOB2=$(sbatch --parsable --dependency=afterok:$JOB1 train.sh)   # 앞 작업 성공 시에만 실행
```

`afterok`(성공 시), `afterany`(성공·실패 무관), `afternotok`(실패 시) 등을 지정할 수 있다.

### 자원 관리 정책 (QOS · Fairshare · Preemption) — 개념 참고

Slurm은 선착순이 아니라 정책으로 자원을 분배한다. 정책 설정은 관리자(`sacctmgr`) 영역이며, MSP 운영자는 개념만 이해하면 된다.

- **QOS(서비스 등급)**: Job 중요도별로 우선순위·최대 GPU·최대 실행시간을 다르게 부여(예: emergency/high/normal/preemptible). `sbatch --qos=<이름>`으로 사용.
- **Fairshare**: 과거 사용량이 많은 사용자·계정의 우선순위를 낮춰 공정하게 분배. slurmdbd(→ [11장](11-Job-Accounting-설정.md))의 사용 이력이 기반.
- **Preemption**: 우선순위 높은 Job이 낮은 Job을 선점(중단·대기)시켜 긴급 작업을 우선 처리.

---

## 2.5 노드·큐 상태 확인

```bash
sinfo                 # 파티션별 노드 상태 요약
sinfo -N -l           # 노드별 상세
squeue                # 전체 작업 큐
squeue -u <사용자>    # 특정 사용자 작업
scontrol show node <노드명>
scontrol show job <작업ID>
```

`sinfo`의 노드 상태 접미 기호:

| 기호 | 의미 |
|------|------|
| `*` | 무응답 상태이며, 지속되면 `DOWN`으로 전환 |
| `~` | 절전(power save) 상태 — 정지된 Autoscale 노드 |
| `#` | 기동/구성 중 |
| `%` | 정지 중 |

`idle~`는 CycleCloud가 회수한 정상 정지 상태이며, 작업 제출 시 자동 기동된다.

---

## 2.6 CycleCloud 연동 (Autoscale · 설정 변경)

### Autoscale 동작

CycleCloud Slurm은 Slurm의 **Elastic Computing(power save)** 기능을 사용한다. Slurm이 필요한 노드를 이름으로 지정해 CycleCloud에 기동/정지를 요청한다. 수동 제어는 다음 명령을 쓴다.

```bash
azslurm resume --node-list <노드명>
azslurm suspend --node-list <노드명>
```

CycleCloud 포털이나 `shutdown`으로 노드를 직접 정지하면 `DOWN` 상태가 되어 Slurm이 다시 기동하지 않는다. 이 경우 수동으로 `idle`로 되돌린다.

```bash
scontrol update nodename=<노드명> state=idle
```

### 설정 변경 반영

클러스터 구성(Autoscale 한도, VM 종류 등)을 바꾸면 스케줄러 노드에서 아래를 실행해 `slurm.conf`를 재생성하고 노드 목록을 갱신해야 한다.

```bash
sudo -i
/opt/cycle/slurm/cyclecloud_slurm.sh apply_changes
```

> ⚠️ MPI(`hpc`) 파티션의 VM 크기·이미지·cloud-init을 바꾸면 실행 중 노드를 **먼저 종료**해야 한다. 그렇지 않으면 신규 노드가 `This node doesn't match existing scaleset attribute` 오류로 기동에 실패한다. `apply_changes`는 노드가 종료됐는지 확인한다.

### 특정 노드·파티션 Autoscale 제외

CycleCloud "KeepAlive" 버튼은 Slurm 클러스터에 적용되지 않는다. 대신 `/sched/slurm.conf`에 다음을 추가하고 `slurmctld`를 재시작한다.

```bash
SuspendExcNodes=hpc-pg0-[1-2]   # 특정 노드 제외
SuspendExcParts=hpc             # 파티션 전체 제외
```

---

## 2.7 설정 파일

설정 파일은 `/sched/`에 위치하며 `/etc/slurm/`으로 심볼릭 링크된다. 스케줄러와 계산 노드에서 동일해야 한다.

| 파일 | 관리 주체 |
|------|-----------|
| `/etc/slurm/slurm.conf` | CycleCloud가 스케줄러 최초 기동 시 생성 |
| `/etc/slurm/cyclecloud.conf` | `cyclecloud_slurm.sh`가 생성·관리하며, 수동 편집은 재실행 시 되돌려질 수 있음 |
| `/etc/slurm/azure.conf` | 파티션·노드 정의 (→ [06장](06-파티션-관리-및-추가.md)) |
| `/etc/slurm/topology.conf` | `cyclecloud_slurm.sh`가 생성·관리 |

검증해야 할 주요 `slurm.conf` 설정:

```ini
SchedulerType        = sched/backfill
SelectType           = select/cons_tres
SlurmctldParameters  = idle_on_node_suspend
JobSubmitPlugins     = job_submit/cyclecloud
PrivateData          = cloud
TreeWidth            = 65533
```

설정 파일을 수정한 뒤에는 즉시 반영한다.

```bash
sudo scontrol reconfigure
```

---

## 2.8 트러블슈팅

### 로그 위치

| 위치 | 파일 |
|------|------|
| 스케줄러 | `/var/log/slurmctld/slurmctld.log` |
| 스케줄러 | `/var/log/slurmctld/resume.log`, `/var/log/slurmctld/suspend.log` |
| 스케줄러 | `/var/log/slurmctld/slurmdbd.log` (Accounting 사용 시) |
| 계산 노드 | `/var/log/slurmd/slurmd.log` |

Autoscale 문제는 `slurmctld.log`에서 `power_save` 항목으로 resume 호출 여부를, `resume.log`에서 기동 결과를 확인한다.

### scontrol 주요 명령

```bash
scontrol reconfig                                  # 설정 재적용
scontrol show node <노드명>                        # 노드 정보
scontrol show job <작업ID>                         # 작업 정보
scontrol update nodename=<노드명> state=idle       # DOWN 노드 복구
```

### 대기 작업의 사유(REASON) 해석

`squeue`의 `NODELIST(REASON)` 열은 작업이 대기하는 이유를 알려준다. 사유를 알면 무작정 기다리는 대신 적절히 조치할 수 있다.

| REASON | 의미 | 대처 |
|--------|------|------|
| `Resources` | 요청 자원이 현재 가용하지 않음 | 대기하거나 요청 자원을 줄여 재제출 |
| `Priority` | 자원은 있으나 더 높은 우선순위 작업이 앞섬 | Fairshare 회복 대기 또는 QOS 검토 |
| `QOSMaxGRESPerUser` | 해당 QOS의 사용자당 GPU 한도 도달 | 기존 작업 종료 대기, 관리자에 한도 조정 요청 |
| `ReqNodeNotAvail` | 요청 노드가 다운·유지보수 중 | 다른 노드 요청 또는 유지보수 종료 대기 |

### 완료 작업 이력 확인 (`sacct`)

종료 상태·exit code·최대 메모리 사용량을 확인해 다음 작업의 자원 요청을 조정할 때 쓴다(slurmdbd 필요).

```bash
sacct -j <작업ID> --format=JobID,JobName,Partition,Elapsed,State,ExitCode,MaxRSS
```

### 자주 겪는 문제

| 증상 | 원인 / 조치 |
|------|-------------|
| Autoscale이 노드를 기동하지 않음 | 노드가 `DOWN` 상태. `scontrol update ... state=idle`로 복구 |
| 변경한 구성이 반영 안 됨 | 스케줄러에서 `cyclecloud_slurm.sh apply_changes` 실행 필요. 실행 중 노드는 종료 후 재기동 |
| 신규 노드가 기동 실패 (`match existing scaleset attribute`) | MPI 파티션 VM 변경 시 기존 노드가 종료되지 않았기 때문이며, 노드 종료 후 재적용 |

---

## 참고 자료

- [CycleCloud Slurm 통합 (Microsoft Learn)](https://learn.microsoft.com/azure/cyclecloud/slurm)
- [cyclecloud-slurm 프로젝트 (GitHub)](https://github.com/Azure/cyclecloud-slurm)
- [Slurm 공식 문서 (SchedMD)](https://slurm.schedmd.com/)

---

다음 단계: [3. 신규 클러스터 생성](03-신규-클러스터-생성.md)
