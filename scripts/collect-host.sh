#!/bin/bash
# Read-only host inventory for the fingerprint browser research repo.
# Public copy. Review the output before publishing.
OUT=/tmp/fp-host-inventory
rm -rf "$OUT"; mkdir -p "$OUT"

{
  echo "### hostnamectl"; hostnamectl 2>&1
  echo; echo "### os-release"; cat /etc/os-release
  echo; echo "### uname"; uname -a
  echo; echo "### uptime"; uptime
  echo; echo "### lxd version"; lxd --version 2>&1; lxc --version 2>&1
  echo; echo "### qemu/kvm"; kvm-ok 2>&1 || true; ls -la /dev/kvm 2>&1
  echo; echo "### cpu"; lscpu 2>&1
  echo; echo "### memory"; free -h
  echo; echo "### disk"; df -hT; lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>&1
  echo; echo "### lspci"; lspci 2>&1 | head -40
  echo; echo "### nvidia"; nvidia-smi 2>&1 | head -20 || true
} > "$OUT/00-host-system.txt" 2>&1

{
  echo "### lxc list"; lxc list 2>&1
  echo; echo "### lxc info"; lxc info 2>&1
  echo; echo "### c4 config"; lxc config show c4-desktop 2>&1
  echo; echo "### c4 devices"; lxc config device show c4-desktop 2>&1
  echo; echo "### profiles"; lxc profile list 2>&1; lxc profile show default 2>&1
  echo; echo "### networks"; lxc network list 2>&1; lxc network show lxdbr0 2>&1
  echo; echo "### storage"; lxc storage list 2>&1; lxc storage show default 2>&1
} > "$OUT/01-host-lxd.txt" 2>&1

{
  echo "### ip addr"; ip addr
  echo; echo "### ip route"; ip route
  echo; echo "### public ip"; curl -s --max-time 10 https://api.ipify.org; echo
  echo; echo "### resolv"; cat /etc/resolv.conf; resolvectl status 2>&1 | head -40
  echo; echo "### listeners"; ss -lntup
  echo; echo "### nft"; nft list ruleset 2>&1 | head -300
  echo; echo "### iptables"; iptables-save 2>&1 | head -200
} > "$OUT/02-host-network.txt" 2>&1

{
  echo "### services"; systemctl list-units --type=service --state=running --no-pager --no-legend 2>&1
  echo; echo "### versions"; for c in docker lxc lxd snap git python3; do printf '%-8s ' "$c"; command -v $c >/dev/null && $c --version 2>&1 | head -1 || echo '-'; done
  echo; echo "### docker"; docker ps -a 2>&1 | head -40; docker --version 2>&1
  echo; echo "### gpu/dri"; ls -la /dev/dri 2>&1
  echo; echo "### cron"; crontab -l 2>&1
} > "$OUT/03-host-services.txt" 2>&1

{
  echo "### port mappings (nft)"; nft list ruleset 2>/dev/null | grep -E 'c4-desktop|1004[0-9]|8088|3389|2204' | head -100
  echo; echo "### lxd proxy devices"; lxc config device show c4-desktop 2>&1 | grep -A6 -E 'p10041|p10042|ph2_10042|p8088|prdp|ssh2204'
  echo; echo "### c4 ip"; lxc list c4-desktop -c n,4,6 2>&1
  echo; echo "### host time"; timedatectl 2>&1
} > "$OUT/04-host-ports.txt" 2>&1

# Best-effort redaction of URL userinfo and UUIDs. Review before publishing.
find "$OUT" -type f -name '*.txt' -print0 | while IFS= read -r -d '' f; do
  sed -i -E \
    -e 's#(https?://)[^@/[:space:]]+@#\1REDACTED@#g' \
    -e 's/\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b/REDACTED-UUID/g' \
    "$f"
done

tar -C /tmp -czf /tmp/fp-host-inventory.tar.gz fp-host-inventory
echo DONE
ls -la /tmp/fp-host-inventory.tar.gz
