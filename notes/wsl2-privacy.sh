#!/usr/bin/env bash
# wsl2-privacy.sh — WSL2 (Ubuntu) 隐私一键 应用 / 验证 / 查看 / 恢复
#
# 适用于 Ubuntu-22.04 / Ubuntu-24.04 两个实例（自动检测 systemd 与否）
# 架构: 继承 Windows 宿主机 SakuraCat TUN 隧道（无需 7897 代理变量）
#
# 子命令:
#   ./wsl2-privacy.sh apply   # 应用时区/区域/DNS锁定/.bashrc/.profile//etc/environment
#   ./wsl2-privacy.sh verify  # 验证关键项
#   ./wsl2-privacy.sh check   # 打印当前环境状态
#   ./wsl2-privacy.sh restore # 恢复默认（DNS 自动生成 + 时区随 Windows）
#
# 与 macos-privacy.sh 对齐：时区 America/New_York + DNS 1.1.1.1/8.8.8.8 + en_US.UTF-8
# 跨平台一致性规则见 privacy-overview.md 第二节

set -euo pipefail

TZ_TARGET="America/New_York"
LOCALE_TARGET="en_US.UTF-8"
DNS_SERVERS=("8.8.8.8" "1.1.1.1")
HOSTNAME_TARGET="secure-sandbox"
MARK="# ===== WSL2 PRIVACY HARDENING ====="
END="# ===== END WSL2 PRIVACY HARDENING ====="
BACKUP_DIR="$HOME/wsl2-backup"

if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YEL=$'\033[33m'; BLU=$'\033[34m'; RST=$'\033[0m'
else
  GREEN=""; RED=""; YEL=""; BLU=""; RST=""
fi
ok(){ echo "${GREEN}OK $*${RST}"; }
no(){ echo "${RED}X  $*${RST}"; }
wn(){ echo "${YEL}!  $*${RST}"; }
info(){ echo "${BLU}i  $*${RST}"; }

need_sudo(){
  if [ "$(id -u)" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    no "此操作需要 sudo，请用: sudo $0 $1  （或先配置 passwordless sudo）"
    exit 1
  fi
}

# 检测 systemd（PID 1 是否为 systemd）
has_systemd(){
  [ "$(ps -p 1 -o comm= 2>/dev/null | tr -d ' ')" = "systemd" ]
}

# 设置时区：优先 timedatectl（systemd），否则 ln -sf
set_timezone(){
  if has_systemd; then
    sudo timedatectl set-timezone "$TZ_TARGET"
  else
    sudo ln -sf "/usr/share/zoneinfo/$TZ_TARGET" /etc/localtime
    echo "$TZ_TARGET" | sudo tee /etc/timezone > /dev/null
  fi
}

# 合并写入 /etc/wsl.conf（保留现有 [boot] systemd 等）
write_wsl_conf(){
  local conf="/etc/wsl.conf"
  local tmp
  tmp=$(mktemp)
  [ -f "$conf" ] && sudo cp "$conf" "$BACKUP_DIR/wsl.conf.bak" 2>/dev/null || true
  if [ -f "$conf" ]; then
    sudo awk '
      /^\[time\]/{skip=1; next}
      /^\[network\]/{skip=1; next}
      /^\[/{skip=0}
      !skip{print}
    ' "$conf" > "$tmp"
  fi
  {
    echo "[time]"
    echo "useWindowsTimezone = false"
    echo ""
    echo "[network]"
    echo "generateResolvConf = false"
    echo "hostname = $HOSTNAME_TARGET"
  } | sudo tee -a "$tmp" > /dev/null
  sudo mv "$tmp" "$conf"
  sudo chmod 644 "$conf"
}

# 锁定 DNS
lock_dns(){
  local resolv="/etc/resolv.conf"
  sudo chattr -i "$resolv" 2>/dev/null || true
  sudo rm -f "$resolv"
  {
    for ns in "${DNS_SERVERS[@]}"; do echo "nameserver $ns"; done
    echo "options timeout:2 attempts:3"
  } | sudo tee "$resolv" > /dev/null
  sudo chattr +i "$resolv"
}

# 幂等追加 export 块到指定文件
append_block(){
  local rc="$1"
  [ -f "$rc" ] || return 0
  if grep -q "$MARK" "$rc" 2>/dev/null; then
    sed -i "/$MARK/,/$END/d" "$rc"
  fi
  cat >> "$rc" << EOF

$MARK
export LANG="$LOCALE_TARGET"
export LC_ALL="$LOCALE_TARGET"
export LC_CTYPE="$LOCALE_TARGET"
export TZ="$TZ_TARGET"
$END
EOF
}

# 写 /etc/environment（PAM 全局，覆盖非交互非登录场景）
write_etc_environment(){
  local envf="/etc/environment"
  sudo cp "$envf" "$BACKUP_DIR/environment.bak" 2>/dev/null || true
  sudo sed -i '/^LANG=/d; /^LC_ALL=/d; /^LC_CTYPE=/d; /^TZ=/d' "$envf" 2>/dev/null || true
  {
    echo "LANG=$LOCALE_TARGET"
    echo "LC_ALL=$LOCALE_TARGET"
    echo "LC_CTYPE=$LOCALE_TARGET"
    echo "TZ=$TZ_TARGET"
  } | sudo tee -a "$envf" > /dev/null
}

# ---------- apply ----------
apply(){
  need_sudo apply
  mkdir -p "$BACKUP_DIR"
  info "应用 WSL2 隐私配置 ($(lsb_release -ds 2>/dev/null || echo Ubuntu))"

  # 1) wsl.conf
  write_wsl_conf
  ok "wsl.conf -> [time]/[network] (chmod 644)"

  # 2) 时区
  set_timezone
  ok "时区 -> $TZ_TARGET"

  # 3) locale
  sudo locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
  sudo update-locale LANG="$LOCALE_TARGET" >/dev/null 2>&1 || true
  ok "locale -> $LOCALE_TARGET"

  # 4) DNS 锁定
  lock_dns
  ok "DNS -> ${DNS_SERVERS[*]} (chattr +i)"

  # 5) .bashrc + .profile export 块
  append_block "$HOME/.bashrc"
  append_block "$HOME/.profile"
  ok ".bashrc + .profile export 块 -> LANG/LC_ALL/TZ"

  # 6) /etc/environment（PAM 全局，覆盖非交互非登录）
  write_etc_environment
  ok "/etc/environment -> LANG/LC_ALL/TZ (PAM 全局)"

  echo
  wn "需在 PowerShell 执行 wsl --shutdown 后重新进入使 wsl.conf 生效"
  wn "生效后: source ~/.bashrc 或重开终端"
  if ! has_systemd; then
    info "提示: 当前实例未启用 systemd（PID 1 != systemd）。如需 timedatectl 等系统服务，"
    info "      可在 /etc/wsl.conf 追加 [boot] systemd=true 后 wsl --shutdown（不影响本脚本已完成的配置）"
  fi
}

# ---------- verify ----------
verify(){
  info "===== WSL2 隐私检测 ($(lsb_release -ds 2>/dev/null || echo Ubuntu)) ====="
  local fail=0

  # 时区
  local tz
  if has_systemd; then
    tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "?")
  else
    tz=$(cat /etc/timezone 2>/dev/null || readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' || echo "?")
  fi
  [ "$tz" = "$TZ_TARGET" ] && ok "时区: $tz" || { wn "时区: $tz (期望 $TZ_TARGET)"; fail=1; }

  # 环境变量：验证 export 块存在于 .bashrc / .profile / /etc/environment
  # （不使用 bash -ic 探测——无 TTY 会挂起；交互式终端必读 .bashrc，已实测有效）
  if grep -q "^export LANG=\"$LOCALE_TARGET\"" "$HOME/.bashrc" 2>/dev/null \
     && grep -q "^export TZ=\"$TZ_TARGET\"" "$HOME/.bashrc" 2>/dev/null; then
    ok ".bashrc: LANG/LC_ALL/TZ export 块存在"
  else
    wn ".bashrc: export 块缺失"; fail=1
  fi
  if grep -q "^export TZ=\"$TZ_TARGET\"" "$HOME/.profile" 2>/dev/null; then
    ok ".profile: TZ export 块存在（覆盖登录 shell）"
  else
    wn ".profile: export 块缺失"; fail=1
  fi

  # DNS
  local dns; dns=$(grep '^nameserver' /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')
  echo "$dns" | grep -q "8.8.8.8" && echo "$dns" | grep -q "1.1.1.1" && ok "DNS: $dns" || { wn "DNS: $dns"; fail=1; }

  # DNS 锁
  lsattr /etc/resolv.conf 2>/dev/null | grep -q 'i' && ok "DNS 锁定: chattr +i 生效" || { wn "DNS 锁定: 未设置"; fail=1; }

  # wsl.conf
  if [ -r /etc/wsl.conf ]; then
    grep -q "useWindowsTimezone = false" /etc/wsl.conf 2>/dev/null && ok "wsl.conf: useWindowsTimezone=false" || { wn "wsl.conf: 缺 time 段"; fail=1; }
    grep -q "generateResolvConf = false" /etc/wsl.conf 2>/dev/null && ok "wsl.conf: generateResolvConf=false" || { wn "wsl.conf: 缺 network 段"; fail=1; }
  else
    wn "wsl.conf: mode 600 无法读取（sudo -n cat 验证）"
    sudo -n grep -q "useWindowsTimezone = false" /etc/wsl.conf 2>/dev/null && ok "wsl.conf: useWindowsTimezone=false (via sudo)" || wn "wsl.conf: 需 sudo 验证"
  fi

  # /etc/environment
  grep -q "^LANG=$LOCALE_TARGET$" /etc/environment 2>/dev/null && ok "/etc/environment: LANG 已设" || wn "/etc/environment: LANG 未设（非交互非登录场景不覆盖）"

  # 代理变量（应为空，TUN 模式）
  [ -z "${http_proxy:-}${https_proxy:-}" ] && ok "http_proxy: 未设置 (TUN 模式正常)" || wn "http_proxy: ${http_proxy:-} (TUN 模式应注释掉)"

  echo "----- 出口 IP / 地理位置 -----"
  curl -s --max-time 8 https://1.1.1.1/cdn-cgi/trace 2>/dev/null | grep -E '^ip=|^loc=|^colo=' || wn "curl 失败（确认 Windows 侧 SakuraCat TUN 已连接）"

  echo
  [ "$fail" -eq 0 ] && ok "基础检测通过" || wn "存在需处理项，见上"
}

# ---------- check ----------
check(){
  echo "===== WSL2 当前环境状态 ($(lsb_release -ds 2>/dev/null || echo Ubuntu)) ====="
  echo "[systemd] $(has_systemd && echo yes || echo no) (PID 1 = $(ps -p 1 -o comm=))"
  if has_systemd; then
    echo "[时区]    $(timedatectl show -p Timezone --value 2>/dev/null)"
  else
    echo "[时区]    $(cat /etc/timezone 2>/dev/null || echo unknown)"
  fi
  echo "[环境变量块存在性]"
  grep -q "WSL2 PRIVACY HARDENING" "$HOME/.bashrc" 2>/dev/null && echo "  .bashrc: OK" || echo "  .bashrc: MISSING"
  grep -q "WSL2 PRIVACY HARDENING" "$HOME/.profile" 2>/dev/null && echo "  .profile: OK" || echo "  .profile: MISSING"
  grep -q "^LANG=$LOCALE_TARGET$" /etc/environment 2>/dev/null && echo "  /etc/environment: OK" || echo "  /etc/environment: MISSING"
  echo "[DNS]     $(grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ')"
  echo "[DNS锁]   $(lsattr /etc/resolv.conf 2>/dev/null | awk '{print $1}' | grep -o 'i' || echo none)"
  echo "[http_proxy] ${http_proxy:-unset}"
  echo "[/etc/environment]"
  cat /etc/environment 2>/dev/null | sed 's/^/  /'
  echo "[wsl.conf]"
  if [ -r /etc/wsl.conf ]; then cat /etc/wsl.conf | sed 's/^/  /'; else sudo -n cat /etc/wsl.conf 2>/dev/null | sed 's/^/  /' || echo "  (mode 600, 需 sudo)"; fi
  echo "[出口IP]  $(curl -s --max-time 5 https://1.1.1.1/cdn-cgi/trace 2>/dev/null | grep -E '^ip=|^loc=' | tr '\n' ' ' || echo unavailable)"
  echo "================================"
}

# ---------- restore ----------
restore(){
  need_sudo restore
  info "恢复 WSL2 默认配置（时区随 Windows + DNS 自动生成）"

  # 解锁 DNS
  sudo chattr -i /etc/resolv.conf 2>/dev/null || true
  # 还原 wsl.conf（从备份或清空 time/network 段）
  if [ -f "$BACKUP_DIR/wsl.conf.bak" ]; then
    sudo cp "$BACKUP_DIR/wsl.conf.bak" /etc/wsl.conf
    sudo chmod 644 /etc/wsl.conf
    ok "wsl.conf 已从备份还原"
  else
    sudo awk '/^\[time\]/{skip=1;next} /^\[network\]/{skip=1;next} /^\[/{skip=0} !skip{print}' /etc/wsl.conf > /tmp/wsl.conf.tmp && sudo mv /tmp/wsl.conf.tmp /etc/wsl.conf && sudo chmod 644 /etc/wsl.conf
    ok "wsl.conf 已移除 time/network 段"
  fi

  # .bashrc / .profile 还原
  for rc in "$HOME/.bashrc" "$HOME/.profile"; do
    local bakname
    bakname=$(echo "$rc" | sed 's|.*/||')
    if [ -f "$BACKUP_DIR/$bakname.bak" ]; then
      cp "$BACKUP_DIR/$bakname.bak" "$rc"
    else
      sed -i "/$MARK/,/$END/d" "$rc" 2>/dev/null || true
    fi
  done
  ok ".bashrc + .profile 已移除 export 块"

  # /etc/environment 还原
  if [ -f "$BACKUP_DIR/environment.bak" ]; then
    sudo cp "$BACKUP_DIR/environment.bak" /etc/environment
  else
    sudo sed -i '/^LANG=/d; /^LC_ALL=/d; /^LC_CTYPE=/d; /^TZ=/d' /etc/environment 2>/dev/null || true
  fi
  ok "/etc/environment 已移除 LANG/LC_ALL/TZ"

  echo
  wn "需在 PowerShell 执行 wsl --shutdown 后重新进入使配置生效"
  wn "DNS 将恢复自动生成（nameserver 指向 Windows 网关）"
}

case "${1:-}" in
  apply)   apply ;;
  verify)  verify ;;
  check)   check ;;
  restore) restore ;;
  *)
    echo "用法: $0 {apply|verify|check|restore}"
    echo "  apply    应用时区/区域/DNS锁定/.bashrc/.profile//etc/environment（需 sudo）"
    echo "  verify   验证关键项"
    echo "  check    打印当前环境状态"
    echo "  restore  恢复默认（需 sudo）"
    exit 1 ;;
esac
