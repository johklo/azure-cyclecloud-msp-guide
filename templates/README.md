# 실습용 템플릿 조각 (현재 형상 기준)

이 폴더는 **실행 중인 Slurm 클러스터에 기능을 추가**할 때 바로 붙여넣어 쓸 수 있는 CycleCloud 템플릿(`slurm.txt`) 조각 모음이다. 현재 랩 클러스터(`slurm-first-clusterrmfo`, Slurm 프로젝트 3.0.x, Ubuntu 22.04, `Standard_D2s_v5`) 형상을 기준으로 작성되었다.

각 조각은 **완결된 파일이 아니라 `slurm.txt` 의 특정 위치에 삽입하는 부분**이다. 파일 상단 주석의 "붙여넣는 위치"를 반드시 확인한다.

## 목록

| 파일 | 실습 | 삽입 위치 | 반영 방법 |
|---|---|---|---|
| [`add-nfs-mount.txt`](add-nfs-mount.txt) | NFS 스토리지 계정 마운트 | `[[node nodearraybase]]` → 일반 `[[[configuration]]]` 속성 뒤, 첫 `[[[cluster-init` 앞 | import → **노드 재기동** |
| [`add-disk.txt`](add-disk.txt) | 디스크 생성 + 마운트 (통합) | `[[node nodearraybase]]` 하위, 첫 `[[[cluster-init` 앞 (volume + mount) | import → **노드 재기동** |
| [`add-partition.txt`](add-partition.txt) | 신규 파티션(nodearray) 추가 | nodearray 영역 + parameters 영역 | import → activate → **`azslurm scale`** |

> `add-disk.txt` 는 한 파일에 **[A] 신규 디스크 생성 + 마운트**, **[B] 기존 디스크(VolumeId) attach + 마운트** 두 시나리오가 들어 있다. 둘 중 하나만 선택해 사용한다.

> `nodearraybase` 는 모든 실행(execute) 노드가 상속하므로, 여기에 넣은 volume/mount 는 **hpc·htc·gpu 등 모든 계산 노드에 공통 적용**된다. 특정 nodearray 에만 적용하려면 해당 `[[nodearray ...]]` 블록 안에 넣는다.

> ⚠️ `nodearraybase` 를 상속하는 것은 전부 `[[nodearray ...]]`, 즉 **VMSS** 다. 따라서 볼륨에 `Persistent = true` 를 넣으면 `Scaleset disk '<이름>' cannot be persistent` 로 노드 기동이 실패한다. 영속 볼륨은 `scheduler` 나 `[[node mynode]]` 같은 **단일 노드(`[[node ...]]`)** 에만 지정한다.

## 운영 스크립트

템플릿 조각과 달리 **그대로 실행하는 스크립트**다.

| 파일 | 용도 | 실행 위치 |
|---|---|---|
| [`mount-all-nodes.sh`](mount-all-nodes.sh) | 실행 중인 노드 전체에 NFS 마운트 일괄 적용·조회 | **CycleCloud 서버**에서 `root` |

`cluster-init` 의 마운트 정의는 **노드가 부팅되는 시점에 고정**된다. 프로젝트 버전을 올려도 이미 떠 있는 노드에는 반영되지 않고, `jetpack converge` 로도 갱신되지 않는다. 정상적인 반영 경로는 노드 재생성이지만, **용량 제약으로 재생성이 어려울 때** 이 스크립트로 간극을 메운다.

```bash
# 상단의 CLUSTER / SA / MOUNTS 를 환경에 맞게 수정한 뒤
sudo ./mount-all-nodes.sh list      # 노드별 전체 NFS 마운트 조회 (변경 없음)
sudo ./mount-all-nodes.sh check     # MOUNTS 목록 기준 현황 (기본값, 변경 없음)
sudo ./mount-all-nodes.sh mount     # 마운트
sudo ./mount-all-nodes.sh umount    # 해제
```

- Slurm 을 거치지 않고 CycleCloud 내부 키로 직접 SSH 하므로 **실행 중인 잡을 방해하지 않고 꺼진 노드도 깨우지 않는다.**
- 멱등이라 실패한 노드만 골라 다시 실행해도 안전하다.
- `MOUNTS` 목록은 **cluster-init 스크립트와 동일하게 유지**한다. 어긋나면 "새 노드에는 있는데 기존 노드에는 없는" 상태가 생긴다.
- 스케줄러에는 노드 접속 키도 `cyclecloud` CLI 도 없으므로 동작하지 않는다.

## 공통 적용 절차

모든 조각은 아래 흐름으로 실행 중인 클러스터에 반영한다. (자세한 설명: [docs/06](../docs/06-파티션-관리-및-추가.md), [docs/07](../docs/07-데이터-디스크-마운트.md), [docs/08](../docs/08-스토리지-NFS-마운트.md))

```bash
# 0) CycleCloud VM(ccserver)에 SSH 접속, 공식 저장소에서 배포 버전 템플릿 준비
#    (내장 /opt/cycle_server 템플릿은 root 전용이라 SSH 사용자가 cp 불가)
sudo find /opt/cycle_server -name 'slurm_template_*.txt' 2>/dev/null | head -1   # 버전 확인
sudo yum install -y git
git clone https://github.com/Azure/cyclecloud-slurm.git ~/cyclecloud-slurm
cd ~/cyclecloud-slurm && git checkout 4.0.9   # ← 배포 버전 태그로 교체
cd templates
cp slurm.txt slurm-edit.txt

# 1) 이 폴더의 조각을 slurm-edit.txt 의 지정 위치에 붙여넣기 (vi/vim 등)

# 2) 현재 GUI 파라미터를 먼저 export (미실행 시 커스터마이징이 템플릿 기본값으로 초기화됨)
cyclecloud export_parameters slurm-first-clusterrmfo > params.json

# 3) 갱신 템플릿을 실행 중 클러스터에 덮어쓰기
cyclecloud import_cluster slurm-first-clusterrmfo -c Slurm -f slurm-edit.txt -p params.json --force

# 4) (파티션 추가 시) 새 nodearray 활성화
cyclecloud start_cluster slurm-first-clusterrmfo
```

### 반영 시점(중요)

- **volume / mount (디스크·NFS)**: 템플릿 선언은 **노드가 새로 기동(converge)될 때** attach/format/mount 된다. 이미 실행 중인 노드에는 즉시 적용되지 않으므로, 스케줄러에서 노드를 재기동해야 한다.
  ```bash
  sudo -i
  azslurm suspend --node-list <노드범위>
  azslurm resume  --node-list <노드범위>
  ```
- **파티션(nodearray)**: import + `start_cluster` 후 스케줄러에서 스케일하면 `azure.conf` 에 반영된다.
  ```bash
  sudo -i
  azslurm scale
  sinfo
  ```

> ⚠️ 값(VM SKU·코어수·이미지 등)은 `params.json` 이, 구조(nodearray·volume·parameter)는 템플릿이 담는다. **import 전 반드시 `export_parameters`** 를 실행한다.
