#!/usr/bin/env bash
# macos-privacy.sh — macOS 隐私一键 应用 / 验证 / 恢复
#
# 架构: SakuraCat 代理模式(127.0.0.1:7897) 负责流量出口
#      + Cloudflare WARP(1.1.1.1 DNS 模式, 非全隧道) 负责 DNS 加密
#
# 用法:
#   sudo  ./macos-privacy.sh apply     # 应用时区 / 区域 / 系统代理 / IPv6 / 提示 WebRTC
#   ./macos-privacy.sh verify          # 验证现状（无需 sudo）
#   sudo  ./macos-privacy.sh restore   # 恢复默认
#
# 环境变量(可选):
#   INTERFACE=Wi-Fi       联网接口名（网线改为 Ethernet）
#   PROXY_PORT=7897       SakuraCat 混合端口
#   SKIP_PROXY=1          apply 时不设置系统代理（仅配时区/区域/IPv6）

set -euo pipefail

PROXY_HOST="127.0.0.1"
PROXY_PORT="${PROXY_PORT:-7897}"
INTERFACE="${INTERFACE:-Wi-Fi}"
TZ="America/New_York"
WARP_DNS="1.1.1.1"

# 颜色（仅终端）
if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YEL=$'\033[33m'; BLU=$'\033[34m'; RST=$'\033[0m'
else
  GREEN=""; RED=""; YEL=""; BLU=""; RST=""
fi
ok(){ echo "${GREEN}✅ $*${RST}"; }
no(){ echo "${RED}❌ $*${RST}"; }
wn(){ echo "${YEL}⚠️  $*${RST}"; }
info(){ echo "${BLU}ℹ️  $*${RST}"; }

need_sudo(){
  if [ "$(id -u)" -ne 0 ]; then
    no "此操作需要 sudo，请用: sudo $0 $1"
    exit 1
  fi
}

# ---------- apply ----------
apply(){
  need_sudo apply
  info "应用 macOS 隐私配置（代理 ${PROXY_HOST}:${PROXY_PORT} + WARP DNS）"

  # 1) 时区：关自动时区，设美东（保留网络时间防漂移）
  sudo systemsetup -setusingnetworktime off 2>/dev/null || true
  sudo systemsetup -settimezone "$TZ"
  ok "时区 → $TZ"

  # 2) 区域 / 语言
  defaults write NSGlobalDomain AppleLanguages -array "en"
  defaults write NSGlobalDomain AppleLocale -string "en_US"
  defaults write NSGlobalDomain AppleMeasurementUnits -string "Inches"
  defaults write NSGlobalDomain AppleMetricUnits -bool false
  ok "区域 / 语言 → en_US"

  # 3) IPv6 关闭（防绕过 WARP）
  networksetup -setv6off "$INTERFACE" 2>/dev/null || wn "关闭 IPv6 失败（接口 $INTERFACE 可能不存在）"
  ok "IPv6 → off ($INTERFACE)"

  # 4) 系统代理（SakuraCat 7897）
  if [ "${SKIP_PROXY:-0}" != "1" ]; then
    networksetup -setwebproxy          "$INTERFACE" "$PROXY_HOST" "$PROXY_PORT"
    networksetup -setsecurewebproxy    "$INTERFACE" "$PROXY_HOST" "$PROXY_PORT"
    networksetup -setsocksfirewallproxy "$INTERFACE" "$PROXY_HOST" "$PROXY_PORT"
    networksetup -setwebproxystate          "$INTERFACE" on
    networksetup -setsecurewebproxystate    "$INTERFACE" on
    networksetup -setsocksfirewallproxystate "$INTERFACE" on
    ok "系统代理 → $PROXY_HOST:$PROXY_PORT (HTTP/HTTPS/SOCKS)"
  else
    wn "跳过系统代理设置（SKIP_PROXY=1）"
  fi

  # 5) 刷新 DNS
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder 2>/dev/null || true

  # 6) WARP 提示
  if command -v warp-cli >/dev/null 2>&1; then
    info "检测到 warp-cli，请确认其处于 DNS-only 模式（非全隧道）："
    warp-cli status 2>/dev/null || true
  else
    wn "未检测到 warp-cli：请手动安装 Cloudflare WARP 并设为 '1.1.1.1' DNS 模式，同时关闭 iCloud 私有中继"
  fi

  echo
  wn "仍需手动处理："
  echo "  • Safari/Firefox/Chrome 的 WebRTC 防护（见文档 4.1，macOS 代理模式下尤其关键）"
  echo "  • 关闭 iCloud 私有中继（系统设置 → Apple ID → iCloud → 私有中继）"
  echo "  • 终端/CLI 需 export http_proxy=http://$PROXY_HOST:$PROXY_PORT"
}

# ---------- verify ----------
verify(){
  info "===== macOS 隐私检测 ====="
  local fail=0

  # 时区
  local tz; tz=$(sudo systemsetup -gettimezone 2>/dev/null | sed 's/Time Zone: //')
  if [ "$tz" = "$TZ" ]; then ok "时区: $tz"; else no "时区: $tz (期望 $TZ)"; fail=1; fi

  # 区域
  local loc; loc=$(defaults read NSGlobalDomain AppleLocale 2>/dev/null)
  if [ "$loc" = "en_US" ]; then ok "区域: $loc"; else wn "区域: $loc (期望 en_US)"; fi

  # IPv6
  if networksetup -getinfo "$INTERFACE" 2>/dev/null | grep -qi 'IPv6: Off'; then
    ok "IPv6: off ($INTERFACE)"
  else
    wn "IPv6: 似乎仍启用（$INTERFACE），可能绕过 WARP DNS"; fail=1
  fi

  # 系统代理
  local wp; wp=$(networksetup -getwebproxy "$INTERFACE" 2>/dev/null | awk -F': ' '/Server/{s=$2} /Port/{p=$2} END{print s":"p}')
  if echo "$wp" | grep -q "$PROXY_PORT"; then ok "系统 HTTP 代理: $wp"; else wn "系统 HTTP 代理: $wp (期望 *:$PROXY_PORT)"; fi

  # WARP 模式
  if command -v warp-cli >/dev/null 2>&1; then
    info "WARP 状态:"; warp-cli status 2>/dev/null || true
  else
    wn "warp-cli 未安装：WARP DNS 加密状态无法自动确认"
  fi

  # DNS 解析链
  info "DNS 解析链 (应含 $WARP_DNS):"
  scutil --dns 2>/dev/null | grep -A2 'nameserver' | head -10 || true

  # 出口 IP
  echo "----- 出口 IP / 地理位置 -----"
  if command -v curl >/dev/null 2>&1; then
    curl -s "https://1.1.1.1/cdn-cgi/trace" 2>/dev/null | grep -E 'ip=|loc=|colo=' || wn "curl 出口检测失败（确认 SakuraCat 代理/WARP 已运行）"
  fi

  echo
  if [ "$fail" -eq 0 ]; then ok "基础检测通过（WebRTC/DNS 泄露仍需到 browserleaks.com 实测）"; else wn "存在需处理项，见上"; fi
}

# ---------- restore ----------
restore(){
  need_sudo restore
  info "恢复 macOS 默认隐私配置"

  sudo systemsetup -setusingnetworktime on 2>/dev/null || true
  sudo systemsetup -settimezone Asia/Shanghai
  ok "时区 → Asia/Shanghai（自动时区已开启）"

  networksetup -setwebproxystate           "$INTERFACE" off
  networksetup -setsecurewebproxystate     "$INTERFACE" off
  networksetup -setsocksfirewallproxystate "$INTERFACE" off
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder 2>/dev/null || true
  ok "系统代理已关闭 ($INTERFACE)"

  networksetup -setv6automatic "$INTERFACE" 2>/dev/null || wn "恢复 IPv6 自动失败"
  ok "IPv6 → automatic ($INTERFACE)"

  defaults write NSGlobalDomain AppleLanguages -array "zh-Hans-CN" "en"
  defaults write NSGlobalDomain AppleLocale -string "zh_CN"
  ok "区域 / 语言 → zh_CN"

  if command -v warp-cli >/dev/null 2>&1; then
    warp-cli disconnect 2>/dev/null || true
    info "已尝试断开 WARP（如需彻底卸载请用 GUI）"
  fi
  echo; wn "语言/区域需注销或重启完全生效"
}

# ---------- main ----------
case "${1:-}" in
  apply)   apply ;;
  verify)  verify ;;
  restore) restore ;;
  *)
    echo "用法: sudo $0 {apply|verify|restore}"
    echo "  apply   应用时区/区域/代理/IPv6（需 sudo）"
    echo "  verify  验证现状（无需 sudo）"
    echo "  restore 恢复默认（需 sudo）"
    exit 1 ;;
esac
