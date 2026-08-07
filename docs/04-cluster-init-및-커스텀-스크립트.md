# 4. Cluster-Init 및 커스텀 스크립트

CycleCloud에서 노드 기동 시 스크립트를 실행하는 방법은 **cloud-init** 과 **cluster-init** 두 가지가 있다.

- cloud-init을 수정하면 전체 클러스터 재기동이 필요(CycleCloud 8.3 기준)하여 운영 중인 클러스터에 영향을 줄 수 있다.
- 따라서 특별한 이유가 없다면 **cluster-init을 사용한다.**

---

## 목적

CycleCloud 노드 구성 스크립트를 cloud-init 대신 cluster-init 프로젝트로 작성, 버전 관리, 업로드하는 표준 절차이다.
운영 중인 클러스터에 영향을 최소화하면서 패키지 설치, 파일 배포, 수렴 작업을 반복 적용해야 할 때 사용한다. cloud-init 불일치 오류를 피하고 노드 단위 재실행이 가능하도록 구성한다.

## 사전 조건

- CycleCloud 서버와 대상 클러스터가 준비되어 있고 CycleCloud 포털/CLI에 접근할 수 있을 것.
- CycleCloud CLI가 설치되어 있거나 설치 권한이 있을 것.
- 프로젝트를 저장할 Locker가 구성되어 있고 업로드 권한이 있을 것.
- 스크립트를 작성하고 검증할 셸 환경과 Git 또는 파일 버전 관리 절차가 준비되어 있을 것.
- 운영 클러스터에서는 cloud-init을 직접 수정하지 않는다는 운영 규칙을 준수할 것.

## 절차

### 4.1 cloud-init vs cluster-init

| 항목 | cloud-init | cluster-init (권장) |
|------|------------|---------------------|
| **제공 주체** | Azure / VMSS | CycleCloud 전용 |
| **실행 시점** | VM 최초 부팅 시 1회 | CycleCloud가 노드를 구성(converge)할 때마다 |
| **설정 방식** | YAML (user-data) | 셸 스크립트 + spec 디렉터리 구조 |
| **재실행** | 불가 | **스크립트 파일명 단위로** 노드당 1회 실행, 이후 converge 는 건너뜀. 파일명을 바꾸거나 새 스크립트를 추가하면 실행됨 ¹ |
| **버전 관리** | 불가 | CycleCloud 프로젝트 단위로 관리 및 배포 |
| **수정 시 영향** | 전체 클러스터 재기동 필요 | 개별 노드 단위 적용 가능 |

> ¹ 실측(Slurm HPC 노드, CycleCloud 8.9.1): 실행 이력은 노드의 `/mnt/cluster-init/.run/<프로젝트>/<spec>/scripts/<스크립트명>.run` 마커로 **스크립트 파일명 단위**로 추적된다. 마커가 있으면 `jetpack converge` 는 `Script ... has already run successfully, skipping` 을 남기며 건너뛰고, 마커가 없는 **새 파일명**은 실행한다. 어떤 변경이 재생성 없이 반영되고 어떤 변경이 재생성을 요구하는지는 아래 [§4.1.1](#411-실행-중-노드에-반영되는-변경과-반영되지-않는-변경) 을 참고한다.

> **운영 규칙: cloud-init 수정 금지**
> 운영 중인 클러스터에서 노드 구성 스크립트를 작성할 때는 **반드시 cluster-init 프로젝트 방식**을 사용한다.


#### 4.1.1 실행 중 노드에 반영되는 변경과 반영되지 않는 변경

"cluster-init 변경은 무조건 노드 재생성이 필요하다"는 통설은 정확하지 않다. 실측(CycleCloud 8.9.1, Ubuntu 실행 노드) 결과는 다음과 같다.

| 변경 내용 | `jetpack converge` 로 반영 | 근거 |
|-----------|--------------------------|------|
| 이미 연결된 프로젝트에 **새 파일명 스크립트 추가** | **된다 — 재부팅·재생성 불필요** | 새 파일명은 `.run` 마커가 없어 실행됨 |
| 기존 스크립트 **내용만 수정**(파일명 동일) | 안 된다 | 같은 파일명의 `.run` 마커가 이미 존재 |
| **새 프로젝트/spec 을 nodearray 에 연결**(템플릿 수정 + import) | 안 된다 | 노드의 `ClusterInitSpecs` 는 노드 생성 시점에 고정 |

즉 **프로젝트가 이미 연결되어 있기만 하면**, 새 파일명으로 스크립트를 추가하고 업로드한 뒤 converge 하는 것만으로 실행 중 노드에 변경을 적용할 수 있다.

**절차 (실행 중 노드, 재생성 없음)**

```bash
# 1) CycleCloud 서버에서 이미 연결된 프로젝트에 새 파일명 스크립트 추가
cd ~/cluster-init/<프로젝트명>
vi specs/default/cluster-init/scripts/20_mount_nfs.sh
chmod +x specs/default/cluster-init/scripts/20_mount_nfs.sh   # 필수 (아래 주의 참고)

# 2) Locker 업로드
cyclecloud project upload <locker명>

# 3) 대상 노드에서 converge (스케줄러에서 전체 노드 브로드캐스트: §4.1.2)
sudo jetpack converge
```

> ⚠️ **실행 권한이 없으면 조용히 건너뛴다** — 실측상 `chmod +x` 가 빠진 스크립트는 로그에 `Executing cluster-init script: ...` 만 남고 `ran successfully` 가 없이 넘어간다. 그런데도 **`.run` 마커는 생성되므로**, 나중에 권한을 고쳐 재업로드해도 같은 파일명은 다시 실행되지 않는다. 업로드 전에 반드시 `chmod +x` 를 확인한다.

> ⚠️ **`jetpack config <키> <값>` 으로는 설정이 저장되지 않는다** — `jetpack config` 는 값을 **읽는** 명령이고(`Gets a configuration value`), 두 번째 인자는 키가 없을 때 출력할 **기본값(fallback)** 이다. 따라서 `jetpack config cyclecloud.mounts.x.type nfs` 를 실행하면 화면에 `nfs` 가 찍혀 성공한 것처럼 보이지만 `node.json` 에는 아무것도 저장되지 않는다. 노드 속성 설정에는 `jetpack props --set` 을 쓰며, `cyclecloud.mounts.*` 는 이 방식으로 주입할 수 없다.

> 💡 **운영 팁 — 빈 운영용 프로젝트를 미리 연결해 둔다**
> 위 표에서 보듯 재생성 없이 반영하는 경로는 **프로젝트가 이미 연결되어 있을 때만** 열린다. 따라서 클러스터를 **생성하는 시점에** 빈 운영용 프로젝트(예: `ops-hotfix`)를 모든 nodearray 에 미리 연결해 두면, 이후 긴급 변경을 새 파일명 스크립트 추가 + converge 만으로 적용할 수 있다. 미리 연결하지 않으면 노드 재생성 외에는 방법이 없다.

#### 4.1.2 다중 노드에 converge 브로드캐스트

`jetpack converge` 는 자동으로 전파되지 않으므로 **노드마다 실행**해야 한다. Slurm 클러스터에서는 스케줄러에서 `srun` 으로 브로드캐스트하는 것이 가장 확실하다(실측 2노드 동시 반영, 약 2초).

```bash
# 유휴 노드에 대해 (노드를 새로 할당)
srun -N2 --ntasks-per-node=1 -p hpc --label sudo /opt/cycle/jetpack/bin/jetpack converge

# 이미 잡이 돌고 있는 노드에 대해 (기존 할당에 겹쳐 실행)
srun --jobid=<JOBID> --overlap -N2 --ntasks-per-node=1 --label \
  sudo /opt/cycle/jetpack/bin/jetpack converge
```

실측에서 확인한 주의점이다.

- **`jetpack` 절대 경로를 쓴다.** `srun` 은 로그인 셸이 아니라 PATH 에 `/opt/cycle/jetpack/bin` 이 없다. `srun ... sudo jetpack converge` 는 `sudo: jetpack: command not found` 로 실패한다.
- **`--ntasks-per-node=1` 을 붙인다.** 노드당 정확히 1회만 실행되도록 한다.
- **`ssh` 루프나 `pdsh` 는 기본 상태에서 동작하지 않는다.** 실측 클러스터에서 스케줄러에는 컴퓨트 노드로 접속할 **개인키가 없고**(`~/.ssh` 에 `authorized_keys` 만 존재) `pdsh` 도 설치되어 있지 않아 `Permission denied (publickey)` 로 실패했다. 별도 키 배포 없이 바로 쓸 수 있는 것은 `srun` 이다.
- 실행 노드에는 `cyclecloud` 계정의 무암호 sudo 가 설정되어 있어 `sudo` 가 그대로 동작한다.


#### CloudInit 불일치 오류

운영 중인 클러스터에서 cloud-init을 수정한 뒤 노드를 추가하거나 재기동하면, 아래 오류가 발생하며 노드 할당이 실패한다.

```
This node does not match existing scaleset attribute: CloudInit
```

이를 해소하는 명령이 있다. 다만 기동 시 기존 cloud-init이 다시 적용되므로 근본적인 해결이 되지 않을 수 있다.

```bash
cycle_server fix_mismatched_attributes <클러스터명> --extra-attribute CloudInit
```

근본적으로는 cloud-init 대신 cluster-init을 사용하면 이 문제가 발생하지 않는다.

---

### 4.2 Cluster-Init 프로젝트 생성 및 업로드

cluster-init은 버전 관리가 되므로 GitHub에서 관리하거나, CycleCloud 서버에서 직접 작성하는 것을 권장한다.

#### 1) CycleCloud CLI 설치 및 초기화

CLI가 없으면 설치한다. [CycleCloud CLI 설치 가이드](https://learn.microsoft.com/azure/cyclecloud/how-to/install-cyclecloud-cli?view=cyclecloud-8)를 참고한다.

설치 후 서버에 연결한다.

```bash
cyclecloud initialize
```

#### 2) 프로젝트 초기화

CycleCloud Server VM에서 프로젝트를 생성한다.

```bash
mkdir -p ~/cluster-init && cd ~/cluster-init
cyclecloud project init <프로젝트명>
```

![project init 실행 화면](images/cluster-init/1780278765193.png)

생성되는 디렉터리 구조는 다음과 같다.

```
<프로젝트명>/
├── project.ini                     # 프로젝트 이름 및 버전 관리 파일
└── specs/
    └── default/
        └── cluster-init/
            ├── scripts/            # 실행할 셸 스크립트 (파일명 순서대로 실행)
            ├── files/              # 노드로 배포할 파일
            └── tests/              # 테스트 스크립트
```

#### 3) 버전 관리

`project.ini` 파일에서 버전을 관리한다. 기존 프로젝트를 수정할 때는 **버전을 올려서** 배포한다.

```bash
vi <프로젝트명>/project.ini
```

예를 들어 `version = 1.0.0` → `1.0.1` 로 변경한다.

![project.ini 편집 화면](images/cluster-init/1780278838710.png)

#### 4) 스크립트 작성

`specs/default/cluster-init/scripts/` 에 스크립트를 추가한다. 파일명 순서대로 실행되므로 `01-`, `02-` 등의 접두사를 붙이는 것을 권장한다.

```bash
# 예시: specs/default/cluster-init/scripts/01-install-packages.sh
#!/bin/bash
set -e
yum install -y htop tmux jq
```

![스크립트 작성 화면](images/cluster-init/1780278869208.png)

#### 5) 업로드

cluster-init은 **Locker로 지정된 Blob Storage**에 업로드된다.

Locker 이름을 확인한다.

```bash
cyclecloud locker list
# 예: cyclecloud-lab-storage (az://storagecycle/cyclecloud)
```

UI에서도 **Settings → Lockers** 에서 확인할 수 있다.

![Locker 확인 화면](images/cluster-init/1780278718713.png)

프로젝트를 업로드한다.

```bash
cd ~/cluster-init/<프로젝트명>
cyclecloud project upload <locker명>
```

> ⚠️ **업로드가 오래 걸리거나 멈춘 것처럼 보일 때** — `project upload` 는 대화형 확인/진행 표시를 사용할 수 있어, **TTY 가 없는 환경**(예: `az vm run-command`, 일부 CI)에서는 응답을 기다리며 멈춘 것처럼 보일 수 있다. **서버에 SSH 로 직접 접속한 셸**에서 실행한다. Locker 스토리지가 **Private Endpoint/방화벽** 뒤에 있으면 서버에서 도달 가능한지도 함께 확인한다(도달 불가 시 재시도로 지연).

![project upload 실행 화면](images/cluster-init/1780278891029.png)

#### 6) 클러스터에 적용

포털에서 업로드한 프로젝트를 노드 배열에 연결한다.

> **Clusters → Slurm 선택 → Edit → Advanced Settings → 대상 파티션의 Cluster-Init → Browse**

1. 생성한 프로젝트(`<프로젝트명>`)를 선택한다.

2. 업로드한 버전(예: `1.0.1`)을 선택한다.

3. spec으로 `default` 를 선택한 뒤 **Select**를 클릭한다.

4. **Save**를 클릭한다.

![포털에서 cluster-init 선택](images/cluster-init/1780278913991.png)

cluster-init 을 실행 중 노드에 반영할 수 있는지는 변경 종류에 따라 다르다. **이미 연결된 프로젝트에 새 파일명 스크립트를 추가**한 경우에는 `jetpack converge` 만으로 재생성 없이 반영되고, **새 프로젝트/spec 을 여기서 새로 연결**한 경우에는 이미 떠 있는 노드에는 반영되지 않아 노드 재생성(terminate→start)이 필요하다(→ [§4.1.1](#411-실행-중-노드에-반영되는-변경과-반영되지-않는-변경), [8장 §8.1.3](08-스토리지-NFS-마운트.md)).

---

## 검증

- `cyclecloud locker list`로 업로드 대상 Locker가 보이는지 확인한다.
- `cyclecloud project upload <locker명>` 실행 후 포털 Cluster-Init Browse 화면에서 프로젝트명, 버전, spec이 표시되는지 확인한다.
- 대상 노드에서 `sudo jetpack converge`를 실행하고 cluster-init 스테이지가 오류 없이 완료되는지 확인한다. 건너뛰기는 **스크립트 파일명 기준**이므로, 이미 성공한 파일명은 다시 실행되지 않는다. 같은 내용을 다시 실행하려면 **새 파일명으로 추가**하거나 노드를 재생성한다(→ [§4.1.1](#411-실행-중-노드에-반영되는-변경과-반영되지-않는-변경)).
- 로그는 `/opt/cycle/jetpack/logs/jetpack.log` 와 스크립트별 `/opt/cycle/jetpack/logs/cluster-init/<프로젝트>/<spec>/scripts/<스크립트명>.out` 에서 확인한다. 스크립트가 실제로 실행됐다면 `ran successfully` 줄이 남는다.
- 스크립트가 설치한 패키지, 배포 파일, 서비스 상태 등 기대 결과를 노드에서 직접 확인한다.

## 롤백·주의

- 문제가 있으면 `project.ini` 버전을 되돌리거나 정상 버전으로 올려 다시 업로드한 뒤 클러스터 설정에서 해당 버전을 선택한다.
- Cluster-Init 연결을 해제하려면 클러스터 Edit 화면에서 대상 파티션의 Cluster-Init 선택을 제거하고 저장한다.
- 파일명 순서대로 스크립트가 실행되므로 접두사 변경 시 실행 순서가 바뀌지 않도록 주의한다.
- cloud-init을 수정해 발생한 CloudInit mismatch는 임시 해소보다 cluster-init 전환으로 근본 해결하는 것을 우선한다.

## 관련 문서

- [CycleCloud CLI 설치 가이드](https://learn.microsoft.com/azure/cyclecloud/how-to/install-cyclecloud-cli?view=cyclecloud-8)
- [다음 단계: 노드 증설/감설 및 노드 사이즈 변경](05-노드-증감설-사이즈변경.md)

다음 단계: [5. 노드 증설/감설 및 노드 사이즈 변경](05-노드-증감설-사이즈변경.md)
