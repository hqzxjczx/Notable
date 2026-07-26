#!/usr/bin/env bash
# macos-privacy.sh — macOS 隐私一键 应用 / 验证 / 查看 / 恢复
#
# 架构: SakuraCat 代理模式(127.0.0.1:7897) 负责流量出口
#      + Cloudflare WARP(1.1.1.1 DNS 模式, 非全隧道) 负责 DNS 加密
#
# 兼容: bash 3.2 (sudo secure_path) / bash 5+ (brew) — 无关联数组、无 bashisms
# 终端: 写入 .zshrc (Ghostty/zsh) + .bashrc (brew bash) + .bash_profile (login bash)
#
# 子命令:
#   sudo  ./macos-privacy.sh apply [区域]   # 应用时区/区域/系统代理/终端代理/IPv6/浏览器语言（默认 us）
#   ./macos-privacy.sh verify              # 验证关键项（无需 sudo）
#   ./macos-privacy.sh check               # 打印当前环境状态（无需 sudo）
#   sudo  ./macos-privacy.sh restore       # 恢复默认
#
# 区域: us(默认) | jp | uk | sg | cn
# 环境变量(可选): INTERFACE=Wi-Fi  PROXY_PORT=7897  SKIP_PROXY=1
#
# 借鉴自 qoderclicn/switch-env-macos.sh 的技术：带标记的 .zshrc 块(幂等增删)、
# 遍历所有网卡关 IPv6、多区域映射、状态打印。数值已适配本方案(7897 + WARP DNS)。

set -euo pipefail

PROXY_HOST="127.0.0.1"
PROXY_PORT="${PROXY_PORT:-7897}"
INTERFACE="${INTERFACE:-Wi-Fi}"
WARP_DNS="1.1.1.1"
SHELL_RCS=("$HOME/.zshrc" "$HOME/.bashrc")
BASH_PROFILE="$HOME/.bash_profile"
MARK_PROXY="# === MACOS-PRIVACY-PROXY ==="
END_PROXY="# === END-MACOS-PRIVACY-PROXY ==="
MARK_LOCALE="# === MACOS-PRIVACY-LOCALE ==="
END_LOCALE="# === END-MACOS-PRIVACY-LOCALE ==="

# 区域映射（与三端一致性规则一致；us 为隐私默认区域）
# 使用 case 函数代替 declare -A（macOS 自带 bash 3.2 不支持关联数组）
get_tz(){
  case "$1" in
    us) echo "America/New_York" ;; jp) echo "Asia/Tokyo" ;;
    uk) echo "Europe/London" ;; sg) echo "Asia/Singapore" ;;
    cn) echo "Asia/Shanghai" ;; *) echo "America/New_York" ;;
  esac
}
get_locale(){
  case "$1" in
    us) echo "en_US" ;; jp) echo "ja_JP" ;; uk) echo "en_GB" ;;
    sg) echo "en_SG" ;; cn) echo "zh_CN" ;; *) echo "en_US" ;;
  esac
}
get_lang(){
  case "$1" in
    us) echo "en-US" ;; jp) echo "ja-JP" ;; uk) echo "en-GB" ;;
    sg) echo "en-SG" ;; cn) echo "zh-Hans-CN" ;; *) echo "en-US" ;;
  esac
}
get_accept_lang(){
  case "$1" in
    us) echo "en-US,en" ;; jp) echo "ja-JP,ja,en-US,en" ;;
    uk) echo "en-GB,en,en-US" ;; sg) echo "en-SG,en,en-US" ;;
    cn) echo "zh-Hans-CN,zh,en-US,en" ;; *) echo "en-US,en" ;;
  esac
}

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

active_services(){
  networksetup -listallnetworkservices 2>/dev/null | grep -v "An asterisk" | grep -v "^$" || true
}

# 幂等移除指定 RC 文件中 [mark, end] 标记块
clear_block(){
  local f="$1" s="$2" e="$3"
  [ -f "$f" ] && sed -i '' "/$s/,/$e/d" "$f" 2>/dev/null || true
}

# 设置 Chrome per-profile Accept-Language（Chrome 有独立语言设置，覆盖系统语言）
set_browser_languages(){
  local accept_lang="$1"
  local chrome_dir="$HOME/Library/Application Support/Google/Chrome"
  [ ! -d "$chrome_dir" ] && { wn "Chrome 未安装：浏览器语言跳过"; return 0; }
  python3 - "$chrome_dir" "$accept_lang" <<'PYEOF'
import json, os, sys, glob
chrome_dir, accept_lang = sys.argv[1], sys.argv[2]
updated = []
# Local State（全局）
ls = os.path.join(chrome_dir, "Local State")
if os.path.exists(ls):
    d = json.load(open(ls))
    d.setdefault("intl", {})["accept_languages"] = accept_lang
    d["intl"]["selected_languages"] = accept_lang
    json.dump(d, open(ls, "w"), indent=2, ensure_ascii=False)
    updated.append("Local State")
# 所有 Profile 的 Preferences（Default + Profile 1/2/...）
for p in sorted(glob.glob(os.path.join(chrome_dir, "Default/Preferences")) + glob.glob(os.path.join(chrome_dir, "Profile */Preferences"))):
    d = json.load(open(p))
    d.setdefault("intl", {})["accept_languages"] = accept_lang
    d["intl"]["selected_languages"] = accept_lang
    json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
    updated.append(os.path.basename(os.path.dirname(p)))
print(", ".join(updated) if updated else "no profiles")
PYEOF
}

# ---------- apply ----------
apply(){
  need_sudo apply
  local region="${1:-us}"
  local tz="$(get_tz "$region")"
  local locale="$(get_locale "$region")"
  local lang="$(get_lang "$region")"
  info "应用 macOS 隐私配置 (区域=$region, 代理 $PROXY_HOST:$PROXY_PORT + WARP DNS)"

  # 1) 时区：关自动时区，设目标（保留网络时间防漂移）
  sudo systemsetup -setusingnetworktime off 2>/dev/null || true
  sudo systemsetup -settimezone "$tz"
  ok "时区 → $tz"

  # 2) 区域 / 语言
  defaults write NSGlobalDomain AppleLanguages -array "$lang"
  defaults write NSGlobalDomain AppleLocale -string "$locale"
  ok "区域 / 语言 → $locale"

  # 2b) 浏览器 Accept-Language（Chrome per-profile 覆盖系统语言）
  local accept_lang="$(get_accept_lang "$region")"
  local updated_profiles; updated_profiles=$(set_browser_languages "$accept_lang")
  ok "浏览器 Accept-Language → $accept_lang (Chrome: $updated_profiles)"

  # 3) IPv6 关闭（所有活跃接口，防绕过 WARP DNS）
  while IFS= read -r svc; do
    [[ -z "$svc" || "$svc" == *Bluetooth* ]] && continue
    networksetup -setv6off "$svc" 2>/dev/null || true
  done <<< "$(active_services)"
  ok "IPv6 → off (所有接口)"

  # 4) 系统代理（SakuraCat 7897）
  if [ "${SKIP_PROXY:-0}" != "1" ]; then
    networksetup -setwebproxy           "$INTERFACE" "$PROXY_HOST" "$PROXY_PORT"
    networksetup -setsecurewebproxy     "$INTERFACE" "$PROXY_HOST" "$PROXY_PORT"
    networksetup -setsocksfirewallproxy "$INTERFACE" "$PROXY_HOST" "$PROXY_PORT"
    networksetup -setwebproxystate           "$INTERFACE" on
    networksetup -setsecurewebproxystate     "$INTERFACE" on
    networksetup -setsocksfirewallproxystate "$INTERFACE" on
    ok "系统代理 → $PROXY_HOST:$PROXY_PORT (HTTP/HTTPS/SOCKS)"
  else
    wn "跳过系统代理设置（SKIP_PROXY=1）"
  fi

  # 5) 终端 locale 块 + (可选) 代理块（写入 .zshrc + .bashrc，幂等）
  for rc in "${SHELL_RCS[@]}"; do
    clear_block "$rc" "$MARK_PROXY" "$END_PROXY"
    clear_block "$rc" "$MARK_LOCALE" "$END_LOCALE"
    {
      if [ "${SKIP_PROXY:-0}" != "1" ]; then
        echo "$MARK_PROXY"
        echo "export http_proxy=\"http://$PROXY_HOST:$PROXY_PORT\""
        echo "export https_proxy=\"http://$PROXY_HOST:$PROXY_PORT\""
        echo "export all_proxy=\"socks5://$PROXY_HOST:$PROXY_PORT\""
        echo "export no_proxy=\"localhost,127.0.0.1,::1\""
        echo "$END_PROXY"
      fi
      echo "$MARK_LOCALE"
      echo "export LANG=\"${locale}.UTF-8\""
      echo "export LC_ALL=\"${locale}.UTF-8\""
      echo "export LC_CTYPE=\"${locale}.UTF-8\""
      echo "export LANGUAGE=\"${locale}:${locale}\""
      echo "$END_LOCALE"
    } >> "$rc"
  done

  # .bash_profile -> source .bashrc (login bash shells don't read .bashrc by default)
  if [ ! -f "$BASH_PROFILE" ]; then
    echo '[ -f ~/.bashrc ] && source ~/.bashrc' > "$BASH_PROFILE"
    ok "已创建 $BASH_PROFILE (source .bashrc for login bash)"
  fi

  if [ "${SKIP_PROXY:-0}" != "1" ]; then
    ok "已写入终端代理/locale 到 .zshrc + .bashrc (请 source 使其生效)"
  else
    ok "已写入终端 locale 到 .zshrc + .bashrc (SKIP_PROXY=1, 未写代理块; 请 source 使其生效)"
  fi

  # 6) 刷新 DNS
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder 2>/dev/null || true

  # 7) WARP 提示（macOS DNS 加密由 WARP 负责，不手设 DNS）
  if command -v warp-cli >/dev/null 2>&1; then
    info "WARP 状态（须为 DNS 模式，非全隧道）:"; warp-cli status 2>/dev/null || true
  else
    wn "未检测到 warp-cli：请装 Cloudflare WARP 并设为 '1.1.1.1' DNS 模式，并关闭 iCloud 私有中继"
  fi

  echo
  wn "仍需手动处理："
  echo "  • Safari/Firefox/Chrome 的 WebRTC 防护（见文档 4.1，代理模式尤其关键）"
  echo "  • 重启浏览器使 Accept-Language 语言变更生效（Chrome 需完全退出后重开）"
  echo "  • 关闭 iCloud 私有中继（系统设置 → Apple ID → iCloud → 私有中继）"
  echo "  • 终端生效: source ~/.zshrc (zsh/Ghostty) / source ~/.bashrc (bash)"
}

# ---------- verify ----------
verify(){
  local region="${1:-us}"
  local tz_exp="$(get_tz "$region")"
  local loc_exp="$(get_locale "$region")"
  info "===== macOS 隐私检测 (区域=$region) ====="
  local fail=0

  local tz; tz=$(sudo systemsetup -gettimezone 2>/dev/null | sed 's/Time Zone: //')
  if [ "$tz" = "$tz_exp" ]; then ok "时区: $tz"; else wn "时区: $tz (期望 $tz_exp)"; fi

  local loc; loc=$(defaults read NSGlobalDomain AppleLocale 2>/dev/null)
  if [ "$loc" = "$loc_exp" ]; then ok "区域: $loc"; else wn "区域: $loc (期望 $loc_exp)"; fi

  # Chrome Accept-Language 检查（Chrome 有独立 per-profile 语言，覆盖系统设置）
  local chrome_prefs="$HOME/Library/Application Support/Google/Chrome/Default/Preferences"
  local lang_exp="$(get_accept_lang "$region")"
  if [ -f "$chrome_prefs" ]; then
    local chrome_lang; chrome_lang=$(python3 -c "
import json; d=json.load(open('$chrome_prefs')); print(d.get('intl',{}).get('accept_languages','NOT SET'))
" 2>/dev/null)
    if [ "$chrome_lang" = "$lang_exp" ]; then ok "Chrome Accept-Language: $chrome_lang"; else wn "Chrome Accept-Language: $chrome_lang (期望 $lang_exp)"; fail=1; fi
  else
    wn "Chrome 未安装：浏览器语言检测跳过"
  fi

  # IPv6 检查所有活跃接口（apply 时全部关闭，故逐接口核对）
  local v6_leak=0
  while IFS= read -r svc; do
    [[ -z "$svc" || "$svc" == *Bluetooth* ]] && continue
    if networksetup -getinfo "$svc" 2>/dev/null | grep -qi 'IPv6: Off'; then
      ok "IPv6: off ($svc)"
    else
      wn "IPv6: 似乎仍启用（$svc），可能绕过 WARP DNS"; v6_leak=1
    fi
  done <<< "$(active_services)"
  [ "$v6_leak" -eq 1 ] && fail=1

  local wp; wp=$(networksetup -getwebproxy "$INTERFACE" 2>/dev/null | awk -F': ' '/Server/{s=$2} /Port/{p=$2} END{print s":"p}')
  if echo "$wp" | grep -q "$PROXY_PORT"; then ok "系统 HTTP 代理: $wp"; else wn "系统 HTTP 代理: $wp (期望 *:$PROXY_PORT)"; fi

  if command -v warp-cli >/dev/null 2>&1; then
    info "WARP 状态:"; warp-cli status 2>/dev/null || true
  else
    wn "warp-cli 未安装：WARP DNS 加密状态无法自动确认"
  fi

  info "DNS 解析链 (应含 $WARP_DNS):"
  scutil --dns 2>/dev/null | grep -A2 'nameserver' | head -10 || true

  echo "----- 出口 IP / 地理位置 -----"
  if command -v curl >/dev/null 2>&1; then
    curl -s "https://1.1.1.1/cdn-cgi/trace" 2>/dev/null | grep -E 'ip=|loc=|colo=' || wn "curl 出口检测失败（确认 SakuraCat 代理/WARP 已运行）"
  fi

  echo
  if [ "$fail" -eq 0 ]; then ok "基础检测通过（WebRTC/DNS 泄露仍需到 browserleaks.com 实测）"; else wn "存在需处理项，见上"; fi
}

# ---------- check ----------
check(){
  echo "===== macOS 当前环境状态 ====="
  echo "[时区]   $(sudo systemsetup -gettimezone 2>/dev/null | sed 's/Time Zone: //')"
  echo "[时间]   $(date)"
  echo "[区域]   $(defaults read NSGlobalDomain AppleLocale 2>/dev/null)"
  echo "[Chrome] $(python3 -c "
import json,os
p=os.path.expanduser('~/Library/Application Support/Google/Chrome/Default/Preferences')
try: print(json.load(open(p)).get('intl',{}).get('accept_languages','NOT SET'))
except: print('Chrome 未安装')
" 2>/dev/null)"
  echo "[Locale] $(locale 2>/dev/null | grep LANG)"
  echo "[DNS]    $(scutil --dns 2>/dev/null | grep -m1 nameserver)"
  echo "[系统代理] $(networksetup -getwebproxy "$INTERFACE" 2>/dev/null | awk -F': ' '/Server/{s=$2}/Port/{p=$2}END{print s":"p}')"
  echo "[终端代理] https_proxy=${https_proxy:-未设置}"
  echo "[IPv6]   $(networksetup -getinfo "$INTERFACE" 2>/dev/null | grep -i IPv6 | head -1)"
  echo "[出口IP] $(curl -s --max-time 5 https://1.1.1.1/cdn-cgi/trace 2>/dev/null | grep -E 'ip=|loc=' || echo 无法获取)"
  echo "================================"
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

  while IFS= read -r svc; do
    [[ -z "$svc" || "$svc" == *Bluetooth* ]] && continue
    networksetup -setv6automatic "$svc" 2>/dev/null || true
  done <<< "$(active_services)"
  ok "IPv6 → automatic (所有接口)"

  defaults write NSGlobalDomain AppleLanguages -array "zh-Hans-CN" "en"
  defaults write NSGlobalDomain AppleLocale -string "zh_CN"
  ok "区域 / 语言 → zh_CN"

  # 恢复 Chrome 浏览器语言
  local updated; updated=$(set_browser_languages "zh-Hans-CN,zh,en-US,en")
  ok "浏览器 Accept-Language → zh-Hans-CN,zh,en-US,en (Chrome: $updated)"

  for rc in "${SHELL_RCS[@]}"; do
    clear_block "$rc" "$MARK_PROXY" "$END_PROXY"
    clear_block "$rc" "$MARK_LOCALE" "$END_LOCALE"
  done
  ok "已移除 .zshrc + .bashrc 代理/locale 块"

  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder 2>/dev/null || true

  if command -v warp-cli >/dev/null 2>&1; then warp-cli disconnect 2>/dev/null || true; fi
  echo; wn "语言/区域需注销或重启完全生效"
}

# ---------- main ----------
case "${1:-}" in
  apply)   apply "${2:-us}" ;;
  verify)  verify "${2:-us}" ;;
  check)   check ;;
  restore) restore ;;
  *)
    echo "用法: sudo $0 {apply|verify|check|restore} [region]"
    echo "  apply [us|jp|uk|sg|cn]   应用时区/区域/代理/IPv6/浏览器语言（默认 us）"
    echo "  verify                   验证关键项（无需 sudo）"
    echo "  check                    打印当前环境状态（无需 sudo）"
    echo "  restore                  恢复默认（需 sudo）"
    exit 1 ;;
esac
