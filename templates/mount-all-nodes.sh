#!/bin/bash
# mount-all-nodes.sh - 실행 중인 노드 전체에 NFS 마운트를 일괄 적용/조회한다.
#
# 용도
#   용량 제약 등으로 노드를 재생성할 수 없을 때, cluster-init 과 동일한 마운트를
#   이미 떠 있는 노드에 즉시 적용하는 보완 수단이다.
#   새로 뜨는 노드는 cluster-init 이 처리하므로 이 스크립트는 임시 조치용이다.
#
#   cluster-init 의 마운트 정의는 노드가 부팅되는 시점에 고정된다. 따라서 프로젝트
#   버전을 올려도 이미 떠 있는 노드에는 반영되지 않는다. 노드를 재생성할 수 없는
#   상황에서 이 스크립트로 간극을 메운다.
#
# 실행 위치
#   CycleCloud 서버에서 root 로 실행한다.
#   노드 접속 키(/opt/cycle_server/.ssh/cyclecloud.pem)와 cyclecloud CLI 가
#   서버에만 있으므로 스케줄러에서는 동작하지 않는다.
#
#   sudo ./mount-all-nodes.sh list      노드별 전체 NFS 마운트 조회 (변경 없음)
#   sudo ./mount-all-nodes.sh check     MOUNTS 목록 기준 현황 (변경 없음, 기본값)
#   sudo ./mount-all-nodes.sh mount     마운트
#   sudo ./mount-all-nodes.sh umount    해제
#
# 특성
#   - Slurm 을 거치지 않으므로 실행 중인 잡을 방해하지 않고, 꺼진 노드도 깨우지 않는다.
#   - 멱등이다. 실패한 노드만 골라 다시 실행해도 안전하다.
#   - 꺼진 노드(idle~)는 PrivateIp 가 없어 자동으로 제외된다.

set -uo pipefail

# ===== 환경에 맞게 수정 =====
CLUSTER="<클러스터명>"
SA="<스토리지계정>"
OPTS=sec=sys,vers=3,nolock,proto=tcp,nofail,_netdev   # Blob NFS 3.0
# Azure Files NFS 4.1 이면: vers=4,minorversion=1,sec=sys,nofail,_netdev

# 대상 노드 이름 필터(grep -E). 전체 컴퓨트면 'hpc|htc|gpu'
NODE_FILTER='hpc'

# ---- 마운트 목록: cluster-init 스크립트와 동일하게 유지한다 ----
#      형식: "<컨테이너 또는 공유명> <마운트포인트>"
MOUNTS="
<공유명1> /mnt/<공유명1>
<공유명2> /mnt/<공유명2>
"
# ===========================

KEY=/opt/cycle_server/.ssh/cyclecloud.pem
CLI=/usr/local/bin/cyclecloud
CCUSER=$(ls /home | head -1)
ACTION=${1:-check}

# 오토스케일로 IP 가 재사용되며 호스트 키가 바뀌므로 known_hosts 검사는 제외한다.
SSHOPT="-i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes -o ConnectTimeout=8"

[ "$(id -u)" -eq 0 ] || { echo "root 로 실행하라:  sudo $0 $*"; exit 1; }
[ -r "$KEY" ]        || { echo "노드 접속 키가 없다: $KEY  (CycleCloud 서버에서 실행하라)"; exit 1; }
[ -x "$CLI" ]        || { echo "CycleCloud CLI 없음: $CLI"; exit 1; }

# 켜져 있는 노드의 이름/사설IP. 꺼진 노드는 PrivateIp 가 없어 자동으로 빠진다.
get_nodes() {
    su - "$CCUSER" -c "$CLI show_nodes -c $CLUSTER" 2>/dev/null | awk '
        /^Name = / { n=$3; gsub(/"/,"",n) }
        /PrivateIp="/ {
            if (match($0, /PrivateIp="[^"]*"/)) {
                ip = substr($0, RSTART+11, RLENGTH-12)
                if (n != "" && ip != "") print n "\t" ip
                n=""
            }
        }'
}

# [list] 노드의 모든 NFS 마운트를 있는 그대로 (MOUNTS 목록과 무관)
#        실제 마운트와 fstab 을 나란히 보여준다.
#        실제에만 있으면 재부팅 시 사라지고, fstab 에만 있으면 마운트가 실패한 상태다.
build_list() {
cat <<'REMOTE'
set -uo pipefail
echo "  [실제 마운트]"
if findmnt -t nfs,nfs4 -no TARGET 2>/dev/null | grep -q .; then
    findmnt -t nfs,nfs4 -no TARGET,SOURCE 2>/dev/null | awk '{printf "    %-16s %s\n", $1, $2}'
else
    echo "    (없음)"
fi
echo "  [fstab 등록]"
if grep -qE '[[:space:]]nfs4?[[:space:]]' /etc/fstab 2>/dev/null; then
    grep -E '[[:space:]]nfs4?[[:space:]]' /etc/fstab | awk '{printf "    %-16s %s\n", $2, $1}'
else
    echo "    (없음)"
fi
REMOTE
}

# [check/mount/umount] MOUNTS 목록 기준
build_remote() {
    echo 'set -uo pipefail'
    while read -r C M; do
        [ -z "$C" ] && continue
        SRC="$SA.blob.core.windows.net:/$SA/$C"
        case "$ACTION" in
            mount)
                echo "mkdir -p '$M'"
                # 앞뒤 공백까지 비교한다 (/mnt/a 가 /mnt/ab 에 오탐되는 것 방지)
                echo "grep -qs ' $M ' /etc/fstab || echo '$SRC $M nfs $OPTS 0 0' >> /etc/fstab"
                echo "mountpoint -q '$M' || mount '$M'"
                ;;
            umount)
                echo "umount '$M' 2>/dev/null"
                echo "sed -i '\\| $M |d' /etc/fstab"
                ;;
        esac
        echo "printf '    %-16s %s\\n' '$M' \"\$(findmnt -no SOURCE '$M' 2>/dev/null || echo '마운트 없음')\""
    done <<< "$MOUNTS"
}

NODES=$(get_nodes | grep -E "$NODE_FILTER" | grep -v scheduler)
[ -z "$NODES" ] && { echo "대상 노드 없음 (필터: $NODE_FILTER). 켜져 있는 노드만 대상이다."; exit 1; }

echo "대상 $(echo "$NODES" | wc -l) 대 / 동작: $ACTION"
echo "$NODES" | sed 's/^/  - /'
echo "---"

if [ "$ACTION" = "list" ]; then
    REMOTE=$(build_list)
else
    REMOTE=$(build_remote)
fi

while IFS=$'\t' read -r NAME IP; do
    [ -z "$IP" ] && continue
    (
        OUT=$(echo "$REMOTE" | timeout 90 ssh $SSHOPT cyclecloud@"$IP" 'sudo bash -s' 2>&1)
        printf '[%s] %s\n%s\n' "$NAME" "$IP" "$OUT"
    ) &
done <<< "$NODES"
wait

echo "---"
echo "완료."
