#!/bin/bash
# macOS 环境一致性切换脚本
# 用途：切换 Claude Code / Codex 所需的系统环境（时区、语言、DNS、代理）
# 用法：
#   ./switch-env-macos.sh us    # 切换到美国环境
#   ./switch-env-macos.sh jp    # 切换到日本环境
#   ./switch-env-macos.sh cn    # 恢复中国环境
#   ./switch-env-macos.sh check # 仅检查当前状态

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

declare -A LANG_MAP=(
  ["us"]="en-US"
  ["jp"]="ja-JP"
  ["cn"]="zh-Hans-CN"
  ["uk"]="en-GB"
  ["sg"]="en-SG"
)

# DNS 配置（全球 anycast，不暴露地理位置）
DNS_PRIMARY="1.1.1.1"
DNS_SECONDARY="1.0.0.1"

# 代理端口（根据实际代理软件修改）
PROXY_PORT="7890"

# ============ 函数 ============

print_status() {
  echo ""
  echo "===== 当前环境状态 ====="
  echo "[时区]   $(sudo systemsetup -gettimezone 2>/dev/null || echo $TZ)"
  echo "[时间]   $(date)"
  echo "[语言]   $(defaults read -g AppleLanguages 2>/dev/null | head -3)"
  echo "[区域]   $(defaults read -g AppleLocale 2>/dev/null)"
  echo "[Locale] $(locale | grep LANG)"
  echo "[DNS]    Wi-Fi: $(networksetup -getdnsservers Wi-Fi 2>/dev/null)"
  echo "[代理]   https_proxy=${https_proxy:-未设置}"
  echo "[出口IP] $(curl -s --max-time 5 https://ipinfo.io/country 2>/dev/null || echo '无法获取')"
  echo "========================"
  echo ""
}

switch_timezone() {
  local tz="$1"
  echo "[1/5] 切换时区 → $tz"
  sudo systemsetup -settimezone "$tz"
  echo "  当前时区: $(sudo systemsetup -gettimezone 2>/dev/null)"
}

switch_language() {
  local lang="$1"
  local locale="$2"
  echo "[2/5] 切换系统语言 → $lang, 区域 → $locale"
  defaults write -g AppleLanguages -array "$lang"
  defaults write -g AppleLocale -string "$locale"
  killall Finder 2>/dev/null || true
  echo "  语言: $(defaults read -g AppleLanguages 2>/dev/null | head -1)"
  echo "  区域: $(defaults read -g AppleLocale 2>/dev/null)"
}

switch_shell_locale() {
  local locale="$1"
  echo "[3/5] 配置 Shell 环境变量 → ${locale}.UTF-8"

  local SHELL_RC="$HOME/.zshrc"
  [[ -f "$HOME/.bash_profile" && ! -f "$SHELL_RC" ]] && SHELL_RC="$HOME/.bash_profile"

  # 移除旧的 locale 配置块
  sed -i '' '/# === ENV-CONSISTENCY-LOCALE ===/,/# === END-ENV-CONSISTENCY-LOCALE ===/d' "$SHELL_RC" 2>/dev/null || true

  # 写入新配置
  cat >> "$SHELL_RC" << EOF
# === ENV-CONSISTENCY-LOCALE ===
export LANG="${locale}.UTF-8"
export LC_ALL="${locale}.UTF-8"
export LC_CTYPE="${locale}.UTF-8"
export LANGUAGE="${locale%%_*}:${locale%%_*}"
# === END-ENV-CONSISTENCY-LOCALE ===
EOF

  echo "  已写入 $SHELL_RC"
  echo "  请执行: source $SHELL_RC"
}

switch_dns() {
  echo "[4/5] 配置 DNS → $DNS_PRIMARY, $DNS_SECONDARY"

  # 获取所有活跃网络服务
  local services
  services=$(networksetup -listallnetworkservices 2>/dev/null | grep -v "An asterisk" | grep -v "^$")

  while IFS= read -r service; do
    [[ -z "$service" ]] && continue
    [[ "$service" == *"Bluetooth"* ]] && continue
    sudo networksetup -setdnsservers "$service" "$DNS_PRIMARY" "$DNS_SECONDARY" 2>/dev/null && \
      echo "  $service → $DNS_PRIMARY, $DNS_SECONDARY" || true
  done <<< "$services"

  # 刷新 DNS 缓存
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder 2>/dev/null || true
  echo "  DNS 缓存已刷新"
}

switch_proxy() {
  echo "[5/5] 配置终端代理 → 127.0.0.1:$PROXY_PORT"

  local SHELL_RC="$HOME/.zshrc"
  [[ -f "$HOME/.bash_profile" && ! -f "$SHELL_RC" ]] && SHELL_RC="$HOME/.bash_profile"

  # 移除旧的代理配置块
  sed -i '' '/# === ENV-CONSISTENCY-PROXY ===/,/# === END-ENV-CONSISTENCY-PROXY ===/d' "$SHELL_RC" 2>/dev/null || true

  cat >> "$SHELL_RC" << EOF
# === ENV-CONSISTENCY-PROXY ===
export http_proxy="http://127.0.0.1:$PROXY_PORT"
export https_proxy="http://127.0.0.1:$PROXY_PORT"
export all_proxy="socks5://127.0.0.1:$PROXY_PORT"
export no_proxy="localhost,127.0.0.1,::1"
# === END-ENV-CONSISTENCY-PROXY ===
EOF

  echo "  已写入 $SHELL_RC"
  echo "  请执行: source $SHELL_RC"
  echo ""
  echo "  提示: 确保代理软件已开启 TUN 模式或全局代理"
}

restore_dns() {
  echo "[恢复] DNS → 自动 (DHCP)"
  local services
  services=$(networksetup -listallnetworkservices 2>/dev/null | grep -v "An asterisk" | grep -v "^$")

  while IFS= read -r service; do
    [[ -z "$service" ]] && continue
    [[ "$service" == *"Bluetooth"* ]] && continue
    sudo networksetup -setdnsservers "$service" Empty 2>/dev/null && \
      echo "  $service → 自动" || true
  done <<< "$services"

  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder 2>/dev/null || true
}

# ============ 主逻辑 ============

case "$REGION" in
  check)
    print_status
    exit 0
    ;;
  us|jp|uk|sg)
    echo ">>> 切换到 [$REGION] 环境..."
    echo ""
    switch_timezone "${TZ_MAP[$REGION]}"
    switch_language "${LANG_MAP[$REGION]}" "${LOCALE_MAP[$REGION]}"
    switch_shell_locale "${LOCALE_MAP[$REGION]}"
    switch_dns
    switch_proxy
    echo ""
    echo ">>> 切换完成！请执行以下操作："
    echo "    1. source ~/.zshrc"
    echo "    2. 注销并重新登录（使系统语言完全生效）"
    echo "    3. 运行 './switch-env-macos.sh check' 验证"
    ;;
  cn)
    echo ">>> 恢复到中国环境..."
    echo ""
    switch_timezone "${TZ_MAP[cn]}"
    switch_language "${LANG_MAP[cn]}" "${LOCALE_MAP[cn]}"
    switch_shell_locale "${LOCALE_MAP[cn]}"
    restore_dns

    # 移除代理配置
    local SHELL_RC="$HOME/.zshrc"
    sed -i '' '/# === ENV-CONSISTENCY-PROXY ===/,/# === END-ENV-CONSISTENCY-PROXY ===/d' "$SHELL_RC" 2>/dev/null || true
    echo "[5/5] 已移除终端代理配置"
    echo ""
    echo ">>> 恢复完成！请执行: source ~/.zshrc"
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
    exit 1
    ;;
esac
