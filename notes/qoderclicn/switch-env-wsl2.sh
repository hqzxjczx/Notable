#!/bin/bash
# Windows WSL2 环境一致性切换脚本
# 用途：切换 Claude Code / Codex 所需的 WSL2 环境（时区、语言、DNS、代理）
# 用法：
#   ./switch-env-wsl2.sh us    # 切换到美国环境
#   ./switch-env-wsl2.sh jp    # 切换到日本环境
#   ./switch-env-wsl2.sh cn    # 恢复中国环境
#   ./switch-env-wsl2.sh check # 仅检查当前状态
#
# 注意：
#   1. 需要在 WSL2 内运行
#   2. Windows 宿主机时区需手动同步（脚本会提示）
#   3. 代理软件需开启 TUN 或允许局域网连接

set -e

REGION="${1:-check}"

# ============ 区域配置 ============
declare -A TZ_MAP=(
  ["us"]="America/New_York"
  ["jp"]="Asia/Tokyo"
  ["cn"]="Asia/Shanghai"
  ["uk"]="Europe/London"
  ["sg"]="Asia/Singapore"
)

declare -A LOCALE_MAP=(
  ["us"]="en_US"
  ["jp"]="ja_JP"
  ["cn"]="zh_CN"
  ["uk"]="en_GB"
  ["sg"]="en_SG"
)

# DNS 配置
DNS_PRIMARY="1.1.1.1"
DNS_SECONDARY="1.0.0.1"

# 代理端口（Windows 宿主机上的代理软件端口；SakuraCat 混合端口为 7897）
PROXY_PORT="7897"

# ============ 函数 ============

check_wsl() {
  if ! grep -qi microsoft /proc/version 2>/dev/null; then
    echo "错误: 此脚本需要在 WSL2 环境中运行"
    exit 1
  fi
}

get_win_host() {
  # 新版 WSL2 可用 localhost，旧版用 resolv.conf 中的 nameserver
  if ip route show default 2>/dev/null | grep -q "via"; then
    ip route show default | awk '{print $3}'
  else
    cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{print $2}' | head -1
  fi
}

print_status() {
  echo ""
  echo "===== WSL2 当前环境状态 ====="
  echo "[时区]     ${TZ:-$(cat /etc/timezone 2>/dev/null || echo '未设置')}"
  echo "[时间]     $(date)"
  echo "[Locale]   $(locale | grep LANG)"
  echo "[DNS]      $(cat /etc/resolv.conf 2>/dev/null | grep nameserver)"
  echo "[WSL Host] $(get_win_host)"
  echo "[代理]     https_proxy=${https_proxy:-未设置}"
  echo "[出口IP]   $(curl -s --max-time 5 https://ipinfo.io/country 2>/dev/null || echo '无法获取')"
  echo ""
  echo "--- Windows 宿主机信息 ---"
  echo "[Win时区]  $(powershell.exe -Command 'Get-TimeZone | Select-Object -ExpandProperty Id' 2>/dev/null | tr -d '\r' || echo '无法获取')"
  echo "[Win DNS]  $(powershell.exe -Command 'Get-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses' 2>/dev/null | tr -d '\r' || echo '无法获取')"
  echo "=============================="
  echo ""
}

switch_timezone() {
  local tz="$1"
  echo "[1/6] 切换 WSL2 时区 → $tz"

  # 方法1: 通过 timedatectl（如果 systemd 已启用）
  if command -v timedatectl &>/dev/null && timedatectl status &>/dev/null 2>&1; then
    sudo timedatectl set-timezone "$tz" 2>/dev/null && echo "  timedatectl 设置成功" && return
  fi

  # 方法2: 通过 /etc/wsl.conf + 环境变量
  local BASH_RC="$HOME/.bashrc"
  [[ -f "$HOME/.zshrc" ]] && BASH_RC="$HOME/.zshrc"

  sed -i '/# === ENV-CONSISTENCY-TZ ===/,/# === END-ENV-CONSISTENCY-TZ ===/d' "$BASH_RC" 2>/dev/null || true

  cat >> "$BASH_RC" << EOF
# === ENV-CONSISTENCY-TZ ===
export TZ="$tz"
# === END-ENV-CONSISTENCY-TZ ===
EOF

  # 同时写入 /etc/wsl.conf 的 boot command（需要 WSL 0.67.6+）
  if grep -q "\[boot\]" /etc/wsl.conf 2>/dev/null; then
    sudo sed -i '/^command.*timedatectl/d' /etc/wsl.conf
    sudo sed -i '/\[boot\]/a command = timedatectl set-timezone '"$tz"'' /etc/wsl.conf 2>/dev/null || true
  else
    sudo tee -a /etc/wsl.conf > /dev/null << EOF

[boot]
command = timedatectl set-timezone $tz
EOF
  fi

  export TZ="$tz"
  echo "  TZ=$tz (已写入 $BASH_RC 和 /etc/wsl.conf)"
}

switch_locale() {
  local locale="$1"
  echo "[2/6] 切换 Locale → ${locale}.UTF-8"

  # 确保 locale 已生成
  if ! locale -a 2>/dev/null | grep -qi "${locale}"; then
    echo "  生成 locale: ${locale}.UTF-8"
    sudo sed -i "s/# ${locale}.UTF-8/${locale}.UTF-8/" /etc/locale.gen 2>/dev/null || true
    sudo locale-gen "${locale}.UTF-8" 2>/dev/null || sudo dpkg-reconfigure locales 2>/dev/null || true
  fi

  local BASH_RC="$HOME/.bashrc"
  [[ -f "$HOME/.zshrc" ]] && BASH_RC="$HOME/.zshrc"

  sed -i '/# === ENV-CONSISTENCY-LOCALE ===/,/# === END-ENV-CONSISTENCY-LOCALE ===/d' "$BASH_RC" 2>/dev/null || true

  cat >> "$BASH_RC" << EOF
# === ENV-CONSISTENCY-LOCALE ===
export LANG="${locale}.UTF-8"
export LC_ALL="${locale}.UTF-8"
export LC_CTYPE="${locale}.UTF-8"
export LANGUAGE="${locale%%_*}:${locale%%_*}"
# === END-ENV-CONSISTENCY-LOCALE ===
EOF

  echo "  已写入 $BASH_RC"
}

switch_dns() {
  echo "[3/6] 配置 WSL2 DNS → $DNS_PRIMARY, $DNS_SECONDARY"

  # 禁止 WSL 自动生成 resolv.conf
  if ! grep -q "generateResolvConf" /etc/wsl.conf 2>/dev/null; then
    sudo tee -a /etc/wsl.conf > /dev/null << EOF

[network]
generateResolvConf = false
EOF
  else
    sudo sed -i 's/generateResolvConf.*/generateResolvConf = false/' /etc/wsl.conf
  fi

  # 写入 DNS
  sudo tee /etc/resolv.conf > /dev/null << EOF
nameserver $DNS_PRIMARY
nameserver $DNS_SECONDARY
EOF

  # 防止重启覆盖
  sudo chattr +i /etc/resolv.conf 2>/dev/null || true

  echo "  /etc/resolv.conf → $DNS_PRIMARY, $DNS_SECONDARY"
  echo "  已锁定文件 (chattr +i)"
  echo "  注意: 需要 wsl --shutdown 后重启生效"
}

switch_proxy() {
  local win_host
  win_host=$(get_win_host)
  echo "[4/6] 配置终端代理 → ${win_host}:${PROXY_PORT}"

  local BASH_RC="$HOME/.bashrc"
  [[ -f "$HOME/.zshrc" ]] && BASH_RC="$HOME/.zshrc"

  sed -i '/# === ENV-CONSISTENCY-PROXY ===/,/# === END-ENV-CONSISTENCY-PROXY ===/d' "$BASH_RC" 2>/dev/null || true

  cat >> "$BASH_RC" << EOF
# === ENV-CONSISTENCY-PROXY ===
# WSL2 → Windows 宿主机代理
_WIN_HOST="\$(cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{print \$2}' | head -1)"
[[ -z "\$_WIN_HOST" ]] && _WIN_HOST="$win_host"
export http_proxy="http://\${_WIN_HOST}:$PROXY_PORT"
export https_proxy="http://\${_WIN_HOST}:$PROXY_PORT"
export all_proxy="socks5://\${_WIN_HOST}:$PROXY_PORT"
export no_proxy="localhost,127.0.0.1,::1"
# === END-ENV-CONSISTENCY-PROXY ===
EOF

  echo "  已写入 $BASH_RC"
  echo "  提示: 确保 Windows 代理软件已开启「允许局域网连接」或 TUN 模式"
}

switch_windows_timezone() {
  local tz="$1"
  echo "[5/6] 同步 Windows 宿主机时区 → $tz"

  # 映射 Linux 时区到 Windows 时区 ID
  local win_tz
  case "$tz" in
    "America/New_York") win_tz="Eastern Standard Time" ;;
    "America/Los_Angeles") win_tz="Pacific Standard Time" ;;
    "America/Chicago") win_tz="Central Standard Time" ;;
    "Asia/Tokyo") win_tz="Tokyo Standard Time" ;;
    "Asia/Shanghai") win_tz="China Standard Time" ;;
    "Europe/London") win_tz="GMT Standard Time" ;;
    "Asia/Singapore") win_tz="Singapore Standard Time" ;;
    *) win_tz="" ;;
  esac

  if [[ -n "$win_tz" ]]; then
    powershell.exe -Command "Set-TimeZone -Id '$win_tz'" 2>/dev/null && \
      echo "  Windows 时区 → $win_tz" || \
      echo "  警告: 无法自动设置 Windows 时区，请手动: Settings → Time → $win_tz"
  else
    echo "  警告: 未知时区映射，请手动设置 Windows 时区"
  fi
}

switch_windows_dns() {
  echo "[6/6] 配置 Windows Wi-Fi DNS → $DNS_PRIMARY, $DNS_SECONDARY"

  powershell.exe -Command "Set-DnsClientServerAddress -InterfaceAlias 'Wi-Fi' -ServerAddresses ('$DNS_PRIMARY','$DNS_SECONDARY')" 2>/dev/null && \
    echo "  Windows Wi-Fi DNS → $DNS_PRIMARY, $DNS_SECONDARY" || \
    echo "  警告: 无法自动设置，请手动: 网络适配器 → IPv4 → DNS → $DNS_PRIMARY"

  # 刷新 Windows DNS 缓存
  powershell.exe -Command "Clear-DnsClientCache" 2>/dev/null || true
}

restore_dns() {
  echo "[恢复] WSL2 DNS → 自动"

  # 解锁文件
  sudo chattr -i /etc/resolv.conf 2>/dev/null || true

  # 恢复自动生成
  sudo sed -i 's/generateResolvConf.*/generateResolvConf = true/' /etc/wsl.conf 2>/dev/null || true

  echo "  已恢复 generateResolvConf = true"
  echo "  需要 wsl --shutdown 后重启生效"
}

restore_proxy() {
  echo "[恢复] 移除终端代理配置"

  local BASH_RC="$HOME/.bashrc"
  [[ -f "$HOME/.zshrc" ]] && BASH_RC="$HOME/.zshrc"

  sed -i '/# === ENV-CONSISTENCY-PROXY ===/,/# === END-ENV-CONSISTENCY-PROXY ===/d' "$BASH_RC" 2>/dev/null || true
  echo "  已移除代理配置"
}

# ============ 主逻辑 ============

check_wsl

case "$REGION" in
  check)
    print_status
    exit 0
    ;;
  us|jp|uk|sg)
    echo ">>> 切换到 [$REGION] 环境 (WSL2)..."
    echo ""
    switch_timezone "${TZ_MAP[$REGION]}"
    switch_locale "${LOCALE_MAP[$REGION]}"
    switch_dns
    switch_proxy
    switch_windows_timezone "${TZ_MAP[$REGION]}"
    switch_windows_dns
    echo ""
    echo ">>> 切换完成！请执行以下操作："
    echo "    1. source ~/.bashrc"
    echo "    2. 在 PowerShell 中执行: wsl --shutdown"
    echo "    3. 重新打开 WSL 终端"
    echo "    4. 运行 './switch-env-wsl2.sh check' 验证"
    ;;
  cn)
    echo ">>> 恢复到中国环境 (WSL2)..."
    echo ""
    switch_timezone "${TZ_MAP[cn]}"
    switch_locale "${LOCALE_MAP[cn]}"
    restore_dns
    restore_proxy
    switch_windows_timezone "${TZ_MAP[cn]}"

    # 恢复 Windows DNS 为自动
    echo "[恢复] Windows DNS → 自动"
    powershell.exe -Command "Set-DnsClientServerAddress -InterfaceAlias 'Wi-Fi' -ResetServerAddresses" 2>/dev/null || true

    echo ""
    echo ">>> 恢复完成！请执行:"
    echo "    1. source ~/.bashrc"
    echo "    2. 在 PowerShell 中执行: wsl --shutdown"
    echo "    3. 重新打开 WSL 终端"
    ;;
  *)
    echo "用法: $0 {us|jp|uk|sg|cn|check}"
    echo ""
    echo "  us    - 切换到美国环境"
    echo "  jp    - 切换到日本环境"
    echo "  uk    - 切换到英国环境"
    echo "  sg    - 切换到新加坡环境"
    echo "  cn    - 恢复中国环境"
    echo "  check - 仅查看当前状态"
    echo ""
    echo "前提条件:"
    echo "  - 在 WSL2 终端中运行"
    echo "  - Windows 代理软件已开启 TUN 或允许局域网连接"
    exit 1
    ;;
esac
