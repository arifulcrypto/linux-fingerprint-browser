#!/bin/bash
# Read-only inventory collector for c4-desktop fingerprint browser research.
# Public copy: provider domain replaced; reports are best-effort redacted.
# Review the output before publishing. See docs/en/10-collection-method.md.
# Writes plain-text reports under /tmp/fp-inventory. Does not modify system config.
OUT=/tmp/fp-inventory
rm -rf "$OUT"
mkdir -p "$OUT"

# ---------- 00 system ----------
{
  echo "### hostnamectl"; hostnamectl 2>&1
  echo; echo "### os-release"; cat /etc/os-release
  echo; echo "### uname"; uname -a
  echo; echo "### uptime"; uptime
  echo; echo "### date"; date; date -u
  echo; echo "### timedatectl"; timedatectl 2>&1
  echo; echo "### locale"; locale 2>&1
  echo; echo "### locale -a"; locale -a 2>&1
  echo; echo "### timezone"; cat /etc/timezone 2>&1; readlink -f /etc/localtime
  echo; echo "### systemd-detect-virt"; systemd-detect-virt 2>&1
  echo; echo "### machine-id (sha256)"; sha256sum /etc/machine-id 2>&1
  echo; echo "### boot-id (sha256)"; sha256sum /proc/sys/kernel/random/boot_id 2>&1
  echo; echo "### cmdline"; cat /proc/cmdline
  echo; echo "### cgroup"; cat /proc/1/cgroup
} > "$OUT/00-system.txt" 2>&1

# ---------- 01 hardware ----------
{
  echo "### cpu"; lscpu 2>&1
  echo; echo "### nproc"; nproc
  echo; echo "### meminfo"; cat /proc/meminfo
  echo; echo "### free"; free -h
  echo; echo "### df"; df -hT
  echo; echo "### lsblk"; lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>&1
  echo; echo "### mounts"; cat /proc/mounts
  echo; echo "### dmi"; for f in /sys/class/dmi/id/{sys_vendor,product_name,product_version,board_vendor,board_name,bios_vendor,bios_version}; do [ -r "$f" ] && echo "$f: $(cat $f)"; done
  echo; echo "### devices"; ls -la /dev | head -80
  echo; echo "### dri"; ls -la /dev/dri 2>&1
  echo; echo "### snd"; ls -la /dev/snd 2>&1
  echo; echo "### lspci"; lspci 2>&1 || echo "lspci not installed"
  echo; echo "### lsusb"; lsusb 2>&1 || echo "lsusb not installed"
  echo; echo "### capabilities"; grep -E 'Cap(Inh|Prm|Eff|Bnd|Amb)' /proc/self/status
  echo; echo "### seccomp/status"; grep -E 'Seccomp|NoNewPrivs' /proc/self/status
} > "$OUT/01-hardware.txt" 2>&1

# ---------- 02 desktop / processes ----------
{
  echo "### display env"; echo "DISPLAY=$DISPLAY"; echo "XAUTHORITY=$XAUTHORITY"; echo "DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS"
  echo; echo "### X sockets"; ls -la /tmp/.X11-unix 2>&1
  echo; echo "### desktop processes"; ps -eo user,pid,ppid,comm,args --sort=pid | grep -E 'Xorg|Xvfb|xrdp|xfce|openbox|fluxbox|gnome|kde|dbus|chrome|pulse|pipewire|pcmanfm|wnck' | grep -v grep
  echo; echo "### all processes count"; ps aux | wc -l
  echo; echo "### session"; loginctl list-sessions 2>&1; loginctl show-session $(loginctl list-sessions --no-legend 2>/dev/null | awk 'NR==1{print $1}') 2>&1
  echo; echo "### window manager"; ps -eo comm,args | grep -E 'xfwm|openbox|mutter|kwin|fluxbox' | grep -v grep
  echo; echo "### xrdp version"; xrdp --version 2>&1 | head -5; xrdp-sesman --version 2>&1 | head -5
  echo; echo "### xrdp packages"; dpkg -l | grep -E 'xrdp|xorg|xfce|dbus-x11' | head -80
} > "$OUT/02-desktop.txt" 2>&1

# ---------- 03 display / X11 ----------
{
  export DISPLAY=:10
  export XAUTHORITY=/root/.Xauthority
  echo "### xrandr"; xrandr --verbose 2>&1 | head -120
  echo; echo "### xdpyinfo"; xdpyinfo 2>&1 | head -120
  echo; echo "### xrdb"; xrdb -query 2>&1
  echo; echo "### xset q"; xset q 2>&1
  echo; echo "### xinput"; xinput list 2>&1
  echo; echo "### xprop root"; xprop -root 2>&1 | head -80
  echo; echo "### glxinfo"; glxinfo -B 2>&1 || echo "glxinfo not installed"
  echo; echo "### xorg log files"; ls -la /root/.xorgxrdp.* /var/log/xrdp*.log 2>&1
  echo; echo "### xorg conf"; cat /etc/X11/xrdp/xorg.conf 2>&1
  echo; echo "### xrdp.ini (sanitized)"; sed -E 's/^(password|username)=.*/\1=REDACTED/' /etc/xrdp/xrdp.ini 2>&1
  echo; echo "### sesman.ini"; cat /etc/xrdp/sesman.ini 2>&1
  echo; echo "### startwm"; cat /etc/xrdp/startwm.sh 2>&1
} > "$OUT/03-display.txt" 2>&1

# ---------- 04 fonts / locale ----------
{
  echo "### font count"; fc-list 2>/dev/null | wc -l
  echo; echo "### font families"; fc-list : family 2>/dev/null | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sort -u
  echo; echo "### font files (first 200)"; fc-list 2>/dev/null | head -200
  echo; echo "### fontconfig"; fc-conflist 2>&1 | head -80
  echo; echo "### locale archive"; localedef --list-archive 2>&1 | head -50
  echo; echo "### input methods"; dpkg -l | grep -E 'ibus|fcitx|im-config' 2>&1
  echo; echo "### fonts packages"; dpkg -l | grep -E 'fonts-' | awk '{print $2, $3}' | head -120
} > "$OUT/04-fonts-locale.txt" 2>&1

# ---------- 05 chrome binaries / policies ----------
{
  echo "### chrome binaries"; which google-chrome google-chrome-stable chromium chromium-browser 2>&1
  echo; echo "### chrome version"; google-chrome --version 2>&1; google-chrome-stable --version 2>&1
  echo; echo "### chrome package"; dpkg -l | grep -E 'google-chrome|chromium|chrome' 2>&1
  echo; echo "### chrome path"; ls -la /opt/google/chrome/ 2>&1 | head -40
  echo; echo "### chrome policies dirs"; find /etc/opt/chrome /etc/chromium /etc/opt/edge -maxdepth 4 -type f 2>/dev/null
  echo; echo "### chrome policies"; for f in /etc/opt/chrome/policies/managed/*.json /etc/opt/chrome/policies/recommended/*.json; do [ -f "$f" ] && { echo "--- $f"; cat "$f"; }; done
  echo; echo "### chrome sandbox"; ls -la /opt/google/chrome/chrome-sandbox 2>&1
  echo; echo "### chrome remote debugging"; ss -lntp 2>/dev/null | grep -E '9222|9223|9515' || echo none
  echo; echo "### chromedriver"; which chromedriver 2>&1; chromedriver --version 2>&1 | head -2
  echo; echo "### chrome processes (cmdline only)"; ps -eo pid,args | grep '/opt/google/chrome/chrome ' | grep -v -- '--type=' | grep -v grep
} > "$OUT/05-chrome.txt" 2>&1

# ---------- 06 chrome profiles ----------
{
  echo "### profile dirs"; du -sh /root/.config/google-chrome* /root/.config/chrome-* 2>&1
  echo; echo "### profile tree (depth 1)"; for d in /root/.config/google-chrome* /root/.config/chrome-*; do echo "--- $d"; ls -la "$d" 2>&1 | head -40; done
  echo; echo "### profile sizes"; du -sh /root/.config/google-chrome*/Default 2>&1
  echo; echo "### default profile prefs files"; ls -la /root/.config/google-chrome*/Default/Preferences /root/.config/chrome-*/Default/Preferences 2>&1
  echo; echo "### extensions dirs"; for d in /root/.config/google-chrome* /root/.config/chrome-*; do echo "--- $d"; find "$d" -maxdepth 3 -type d -path '*/Extensions/*' 2>/dev/null | head -40; done
} > "$OUT/06-chrome-profiles.txt" 2>&1

# ---------- 06b chrome profile summaries via python ----------
python3 - <<'PY' > "$OUT/06b-chrome-profile-summary.json" 2>&1
import glob, json, os

def pick(d, *keys):
    for k in keys:
        if isinstance(d, dict) and k in d:
            d = d[k]
        else:
            return None
    return d

out = {}
for base in sorted(glob.glob('/root/.config/google-chrome*') + glob.glob('/root/.config/chrome-*')):
    if not os.path.isdir(base):
        continue
    entry = {"path": base}
    pref_path = os.path.join(base, 'Default', 'Preferences')
    local_state_path = os.path.join(base, 'Local State')
    if os.path.exists(pref_path):
        try:
            p = json.load(open(pref_path, encoding='utf-8'))
            entry["profile"] = {
                "name": pick(p, 'profile', 'name'),
                "avatar_index": pick(p, 'profile', 'avatar_index'),
                "exit_type": pick(p, 'profile', 'exit_type'),
                "default_content_setting_values": pick(p, 'profile', 'default_content_setting_values'),
                "content_settings_exceptions_keys": sorted(list((pick(p, 'profile', 'content_settings', 'exceptions') or {}).keys()))[:50],
            }
            entry["intl"] = {
                "accept_languages": pick(p, 'intl', 'accept_languages'),
                "charset_default": pick(p, 'intl', 'charset_default'),
            }
            entry["browser"] = {
                "last_clear_browsing_data_time": pick(p, 'browser', 'last_clear_browsing_data_time'),
                "has_seen_welcome_page": pick(p, 'browser', 'has_seen_welcome_page'),
            }
            entry["download"] = {"default_directory": pick(p, 'download', 'default_directory')}
            entry["signin"] = {"allowed": pick(p, 'signin', 'allowed'), "allowed_on_next_startup": pick(p, 'signin', 'allowed_on_next_startup')}
            entry["sync"] = {"requested": pick(p, 'sync', 'requested')}
            entry["hardware_acceleration_mode"] = pick(p, 'hardware_acceleration_mode')
            entry["media"] = {"autoplay_policy": pick(p, 'media', 'autoplay_policy')}
            ext = pick(p, 'extensions', 'settings') or {}
            exts = []
            for eid, v in ext.items():
                m = (v or {}).get('manifest', {}) or {}
                exts.append({
                    "id": eid,
                    "name": m.get('name'),
                    "version": m.get('version'),
                    "permissions": m.get('permissions'),
                    "host_permissions": m.get('host_permissions'),
                    "location": (v or {}).get('location'),
                    "state": (v or {}).get('state'),
                })
            entry["extensions"] = sorted(exts, key=lambda x: (x.get('name') or ''))
        except Exception as e:
            entry["preferences_error"] = repr(e)
    if os.path.exists(local_state_path):
        try:
            ls = json.load(open(local_state_path, encoding='utf-8'))
            info = pick(ls, 'profile', 'info_cache') or {}
            entry["local_state"] = {
                "last_used": ls.get('profile', {}).get('last_used'),
                "last_active_profiles": ls.get('profile', {}).get('last_active_profiles'),
                "profiles": {k: {"name": v.get('name'), "avatar_icon": v.get('avatar_icon'), "is_using_default_name": v.get('is_using_default_name')} for k, v in info.items()},
                "variations_country": pick(ls, 'variations_country'),
                "variations_permanent_consistency_country": pick(ls, 'variations_permanent_consistency_country'),
            }
        except Exception as e:
            entry["local_state_error"] = repr(e)
    out[base] = entry

print(json.dumps(out, ensure_ascii=False, indent=2))
PY

# ---------- 07 chrome launchers ----------
{
  echo "### desktop files"; find /root/Desktop /usr/share/applications -maxdepth 1 -type f \( -name '*.desktop' -o -name '*.sh' \) 2>/dev/null | sort
  echo; echo "### launcher contents"; for f in $(find /root/Desktop /usr/share/applications -maxdepth 1 -type f \( -name '*.desktop' -o -name '*.sh' \) 2>/dev/null | sort); do echo "===== $f ====="; cat "$f"; echo; done
  echo; echo "### autostart"; find /etc/xdg/autostart /root/.config/autostart -type f 2>/dev/null | sort | while read f; do echo "===== $f ====="; cat "$f"; echo; done
  echo; echo "### proxy cheat sheet"; cat /root/Desktop/PROXY_CHEAT_SHEET.txt 2>&1
  echo; echo "### shell proxy env"; grep -RInE 'proxy|PROXY' /etc/environment /etc/profile /etc/profile.d /root/.bashrc /root/.profile 2>/dev/null | head -80
} > "$OUT/07-chrome-launchers.txt" 2>&1

# ---------- 08 proxy services ----------
{
  echo "### units"; for u in xray-client-us xray-c4-tr hysteria-server proxy-bridge proxy-bridge-tr; do echo "===== $u ====="; systemctl cat "$u" 2>&1; echo; done
  echo; echo "### unit status"; for u in xray-client-us xray-c4-tr hysteria-server proxy-bridge proxy-bridge-tr; do echo "===== $u ====="; systemctl status "$u" --no-pager -l 2>&1 | head -25; echo; done
  echo; echo "### versions"; /usr/local/bin/xray-26.6.27 version 2>&1; /usr/local/bin/hysteria version 2>&1 | head -8; /usr/local/bin/pproxy --version 2>&1 | head -3
  echo; echo "### pproxy path"; ls -la /usr/local/bin/pproxy 2>&1; head -3 /usr/local/bin/pproxy 2>&1
  echo; echo "### xray config (sanitized)"; python3 - <<'PY'
import json
p='/etc/xray-c4-tr/config.json'
try:
    d=json.load(open(p))
    for ob in d.get('outbounds',[]):
        for s in ob.get('settings',{}).get('servers',[]):
            for u in s.get('users',[]):
                u['user']='REDACTED'; u['pass']='REDACTED'
    for ib in d.get('inbounds',[]):
        for c in ib.get('settings',{}).get('clients',[]):
            c['id']='REDACTED'
        rs=ib.get('streamSettings',{}).get('realitySettings',{})
        if 'privateKey' in rs: rs['privateKey']='REDACTED'
        if 'shortIds' in rs: rs['shortIds']=['REDACTED']
    print(json.dumps(d,indent=2))
except Exception as e:
    print('ERR',e)
PY
  echo; echo "### xray-client-us config (sanitized)"; python3 - <<'PY'
import json
p='/etc/xray-client-us/config.json'
try:
    d=json.load(open(p))
    for ob in d.get('outbounds',[]):
        for v in ob.get('settings',{}).get('vnext',[]):
            for u in v.get('users',[]):
                u['id']='REDACTED'
        rs=ob.get('streamSettings',{}).get('realitySettings',{})
        for k in ('publicKey','shortId','serverName'):
            if k in rs: rs[k]='REDACTED'
    print(json.dumps(d,indent=2))
except Exception as e:
    print('ERR',e)
PY
  echo; echo "### hysteria config (sanitized)"; sed -E 's/(password:).*/\1 REDACTED/; s#(url: http://)[^@]+@#\1REDACTED@#' /etc/hysteria/config.yaml 2>&1
} > "$OUT/08-proxy-services.txt" 2>&1

# ---------- 09 network ----------
{
  echo "### ip addr"; ip addr
  echo; echo "### ip route"; ip route
  echo; echo "### ip -6 route"; ip -6 route
  echo; echo "### resolv.conf"; cat /etc/resolv.conf
  echo; echo "### resolvectl"; resolvectl status 2>&1
  echo; echo "### hosts"; cat /etc/hosts
  echo; echo "### listening sockets"; ss -lntup
  echo; echo "### all sockets summary"; ss -s
  echo; echo "### iptables"; iptables-save 2>&1 | head -200
  echo; echo "### nft"; nft list ruleset 2>&1 | head -200
  echo; echo "### sysctl network"; sysctl -a 2>/dev/null | grep -E 'net.ipv4.(ip_forward|tcp_|conf.all)|net.ipv6.conf.all' | head -80
  echo; echo "### proxy env"; env | grep -iE 'proxy|no_proxy' || echo none
  echo; echo "### DNS test"; getent ahostsv4 proxy.example-provider.net 2>&1 | head -5; getent ahostsv4 www.google.com 2>&1 | head -5
} > "$OUT/09-network.txt" 2>&1

# ---------- 10 container view ----------
{
  echo "### container identity"; hostname; hostname -I; cat /etc/hostname
  echo; echo "### /proc/1"; cat /proc/1/status | head -30
  echo; echo "### cgroup"; cat /proc/1/cgroup
  echo; echo "### mounts (top)"; mount | head -60
  echo; echo "### disk"; df -hT /
  echo; echo "### limits"; cat /sys/fs/cgroup/memory.max 2>&1; cat /sys/fs/cgroup/cpu.max 2>&1; cat /sys/fs/cgroup/pids.max 2>&1
  echo; echo "### lxc env"; env | grep -iE 'container|lxc' || echo none
} > "$OUT/10-container-view.txt" 2>&1

# ---------- 11 software ----------
{
  echo "### dpkg count"; dpkg -l | grep -c '^ii'
  echo; echo "### key packages"; dpkg -l | grep -E 'google-chrome|xrdp|xorg|xfce|dbus|policykit|pulseaudio|pipewire|fonts-|python3|docker|containerd|fail2ban|openssh|nginx|1panel' | awk '{print $2, $3}'
  echo; echo "### all packages"; dpkg -l | awk '/^ii/{print $2, $3}'
  echo; echo "### snap"; snap list 2>&1 || echo "snap not installed"
  echo; echo "### apt sources"; cat /etc/apt/sources.list 2>&1; find /etc/apt/sources.list.d -type f -maxdepth 1 -print -exec cat {} \; 2>&1
  echo; echo "### unattended upgrades"; cat /etc/apt/apt.conf.d/20auto-upgrades 2>&1
} > "$OUT/11-software.txt" 2>&1

# ---------- 12 dev toolchain ----------
{
  echo "### compilers"; for c in gcc g++ clang clang++ cmake ninja make pkg-config; do printf '%-12s ' "$c"; command -v $c >/dev/null && $c --version 2>&1 | head -1 || echo "-"; done
  echo; echo "### languages"; for c in python3 pip3 node npm pnpm yarn rustc cargo go java javac; do printf '%-8s ' "$c"; command -v $c >/dev/null && $c --version 2>&1 | head -1 || echo "-"; done
  echo; echo "### python packages"; python3 -m pip list 2>&1 | head -120
  echo; echo "### node global"; npm ls -g --depth=0 2>&1 | head -40
  echo; echo "### chromium build deps check"; for p in libnss3 libgbm1 libasound2 libatk1.0-0 libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libpango-1.0-0 libcairo2; do printf '%-20s ' "$p"; dpkg -s "$p" 2>/dev/null | awk '/^Version:/{print $2; found=1} END{if(!found)print "MISSING"}'; done
  echo; echo "### disk budget"; df -h /; echo "Chromium build typically needs 100GB+ free and 16GB+ RAM."
} > "$OUT/12-dev-toolchain.txt" 2>&1

# ---------- 13 docker ----------
{
  echo "### docker version"; docker version 2>&1
  echo; echo "### docker info"; docker info 2>&1 | head -80
  echo; echo "### docker ps"; docker ps -a 2>&1
  echo; echo "### docker images"; docker images 2>&1
  echo; echo "### docker networks"; docker network ls 2>&1
  echo; echo "### docker volumes"; docker volume ls 2>&1
  echo; echo "### docker compose projects"; docker compose ls 2>&1
} > "$OUT/13-docker.txt" 2>&1

# ---------- 14 1panel ----------
{
  echo "### 1panel binary"; which 1pctl 1panel 2>&1; ls -la /usr/local/bin/1pctl /opt/1panel 2>&1
  echo; echo "### 1panel version"; 1pctl version 2>&1 | head -5
  echo; echo "### 1panel status"; 1pctl status 2>&1 | head -20
  echo; echo "### 1panel dirs"; du -sh /opt/1panel 2>&1; ls -la /opt/1panel 2>&1 | head -30
  echo; echo "### 1panel ports"; ss -lntp 2>&1 | grep -E '1panel|:8088|:9999|:8443' || true
  echo; echo "### 1panel db (tables only)"; find /opt/1panel -maxdepth 3 -name '*.db' 2>/dev/null | head -10
} > "$OUT/14-1panel.txt" 2>&1

# ---------- 15 autostart / cron / users ----------
{
  echo "### crontab root"; crontab -l 2>&1
  echo; echo "### cron files"; find /etc/cron.d /etc/cron.daily /etc/cron.hourly -type f 2>/dev/null | sort
  echo; echo "### enabled units"; systemctl list-unit-files --state=enabled --no-pager --no-legend 2>&1
  echo; echo "### running units"; systemctl list-units --type=service --state=running --no-pager --no-legend 2>&1
  echo; echo "### users"; awk -F: '$3>=1000 && $3<65534 {print $1, $3, $6, $7}' /etc/passwd
  echo; echo "### sshd config (effective, sanitized)"; sshd -T 2>&1 | grep -vE 'password|key|hostkey' | head -60
  echo; echo "### fail2ban jails"; fail2ban-client status 2>&1
} > "$OUT/15-autostart-cron-users.txt" 2>&1

# ---------- 16 security ----------
{
  echo "### apparmor"; aa-status 2>&1 | head -30
  echo; echo "### ufw"; ufw status verbose 2>&1
  echo; echo "### sysctl hardening"; sysctl kernel.randomize_va_space kernel.kptr_restrict kernel.dmesg_restrict 2>&1
  echo; echo "### open ports"; ss -lntup
  echo; echo "### /etc/shadow root hash algorithm"; awk -F: '$1=="root"{print $2}' /etc/shadow | cut -c1-3
  echo; echo "### sudoers"; grep -vE '^#|^$' /etc/sudoers 2>&1 | head -30
} > "$OUT/16-security.txt" 2>&1

# ---------- 17 fingerprint surface ----------
{
  echo "### screen geometry"; DISPLAY=:10 XAUTHORITY=/root/.Xauthority xrandr 2>&1 | head -20
  echo; echo "### dpi"; DISPLAY=:10 XAUTHORITY=/root/.Xauthority xdpyinfo 2>&1 | grep -E 'dimensions|resolution|depth of root'
  echo; echo "### gpu"; DISPLAY=:10 XAUTHORITY=/root/.Xauthority glxinfo -B 2>&1 | head -30
  echo; echo "### audio"; pactl info 2>&1 | head -20; aplay -l 2>&1 | head -20
  echo; echo "### timezone"; timedatectl 2>&1 | grep -E 'Time zone|Local time'
  echo; echo "### language"; locale 2>&1
  echo; echo "### fonts count"; fc-list 2>/dev/null | wc -l
  echo; echo "### chrome version"; google-chrome --version 2>&1
  echo; echo "### MAC"; cat /sys/class/net/eth0/address 2>&1
  echo; echo "### cpu model"; grep -m1 'model name' /proc/cpuinfo
  echo; echo "### memory GB"; awk '/MemTotal/{printf "%.1f GB\n", $2/1024/1024}' /proc/meminfo
  echo; echo "### cores"; nproc
} > "$OUT/17-fingerprint-surface.txt" 2>&1

# ---------- 18 headless chrome probe ----------
cat > /tmp/fp-probe.html <<'HTML'
<!doctype html><html><body><pre id="o"></pre><script>
const gl = document.createElement('canvas').getContext('webgl');
const dbg = gl && gl.getExtension('WEBGL_debug_renderer_info');
const out = {
  userAgent: navigator.userAgent,
  platform: navigator.platform,
  vendor: navigator.vendor,
  language: navigator.language,
  languages: navigator.languages,
  hardwareConcurrency: navigator.hardwareConcurrency,
  deviceMemory: navigator.deviceMemory,
  maxTouchPoints: navigator.maxTouchPoints,
  webdriver: navigator.webdriver,
  screen: { width: screen.width, height: screen.height, availWidth: screen.availWidth, availHeight: screen.availHeight, colorDepth: screen.colorDepth, pixelDepth: screen.pixelDepth },
  devicePixelRatio: devicePixelRatio,
  timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
  locale: Intl.DateTimeFormat().resolvedOptions().locale,
  webglVendor: dbg ? gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL) : null,
  webglRenderer: dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : null,
  plugins: Array.from(navigator.plugins).map(p => p.name),
  mimeTypes: Array.from(navigator.mimeTypes).map(m => m.type)
};
document.getElementById('o').textContent = JSON.stringify(out, null, 2);
</script></body></html>
HTML
timeout 60 google-chrome --headless=new --no-sandbox --disable-gpu --disable-dev-shm-usage --user-data-dir=/tmp/fp-chrome-profile --dump-dom file:///tmp/fp-probe.html > "$OUT/18-headless-chrome-probe.html" 2> "$OUT/18-headless-chrome-probe.err"
python3 - <<'PY' > "$OUT/18-headless-chrome-probe.json" 2>&1
import re
try:
    s=open('/tmp/fp-inventory/18-headless-chrome-probe.html',encoding='utf-8',errors='replace').read()
    m=re.search(r'<pre id="o">(.*?)</pre>', s, re.S)
    print(m.group(1).replace('&quot;','"').replace('&amp;','&').replace('&lt;','<').replace('&gt;','>') if m else s[:2000])
except Exception as e:
    print('ERR', e)
PY

# ---------- 19 summary ----------
{
  echo "### collection time"; date -u
  echo; echo "### files"; ls -la "$OUT"
  echo; echo "### sizes"; du -sh "$OUT"
} > "$OUT/19-summary.txt" 2>&1

# ---------- 20 best-effort redaction ----------
# Removes URL userinfo and UUIDs from the text reports. This is NOT a substitute
# for reviewing the output: unit files and configs may contain other secrets.
find "$OUT" -type f -name '*.txt' -print0 | while IFS= read -r -d '' f; do
  sed -i -E \
    -e 's#(https?://)[^@/[:space:]]+@#\1REDACTED@#g' \
    -e 's/\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b/REDACTED-UUID/g' \
    -e 's/(session-)[0-9]{4,}/\1REDACTED/g' \
    "$f"
done

tar -C /tmp -czf /tmp/fp-inventory.tar.gz fp-inventory
echo "DONE"
ls -la /tmp/fp-inventory.tar.gz
