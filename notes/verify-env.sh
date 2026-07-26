#!/usr/bin/env bash
# verify-env.sh — 验证 WSL2 隐私环境变量（在 WSL 内部直接执行，避免外层 shell 变量展开）

echo "===== WSL2 隐私环境验证 ====="
echo "[实例] $(lsb_release -ds 2>/dev/null || echo Ubuntu)"
echo "[systemd] PID1=$(ps -p 1 -o comm= 2>/dev/null | tr -d ' ')"
echo ""

echo "--- 时区 ---"
if [ "$(ps -p 1 -o comm= 2>/dev/null | tr -d ' ')" = "systemd" ]; then
  timedatectl show -p Timezone --value 2>/dev/null || echo "(timedatectl failed)"
else
  cat /etc/timezone 2>/dev/null || readlink /etc/localtest 2>/dev/null | sed 's|.*/zoneinfo/||' || echo "(unknown)"
fi

echo ""
echo "--- 当前 shell 环境变量 (非交互非登录) ---"
echo "LANG=[${LANG:-}]"
echo "LC_ALL=[${LC_ALL:-}]"
echo "LC_CTYPE=[${LC_CTYPE:-}]"
echo "TZ=[${TZ:-}]"
echo "http_proxy=[${http_proxy:-unset}]"
echo "https_proxy=[${https_proxy:-unset}]"

echo ""
echo "--- .bashrc 是否含 export 块 ---"
if grep -q "WSL2 PRIVACY HARDENING" "$HOME/.bashrc" 2>/dev/null; then
  echo "OK: .bashrc 含 HARDENING 块"
  grep -E "^export (LANG|LC_ALL|LC_CTYPE|TZ)=" "$HOME/.bashrc" | tail -6
else
  echo "MISSING: .bashrc 无 HARDENING 块"
fi

echo ""
echo "--- .profile 是否含 export 块 ---"
if grep -q "WSL2 PRIVACY HARDENING" "$HOME/.profile" 2>/dev/null; then
  echo "OK: .profile 含 HARDENING 块"
else
  echo "MISSING: .profile 无 HARDENING 块"
fi

echo ""
echo "--- /etc/environment (PAM 全局，所有会话都读) ---"
if [ -r /etc/environment ]; then
  cat /etc/environment
else
  echo "(不可读或不存在)"
fi

echo ""
echo "--- 交互式 shell 测试 (bash -ic 模拟真实终端) ---"
INTERACTIVE_OUT=$(bash -ic 'echo "LANG=$LANG"; echo "LC_ALL=$LC_ALL"; echo "TZ=$TZ"' 2>/dev/null)
echo "$INTERACTIVE_OUT"

echo ""
echo "--- 登录 shell 测试 (bash -lc) ---"
LOGIN_OUT=$(bash -lc 'echo "LANG=$LANG"; echo "LC_ALL=$LC_ALL"; echo "TZ=$TZ"' 2>/dev/null)
echo "$LOGIN_OUT"

echo ""
echo "--- /etc/resolv.conf ---"
cat /etc/resolv.conf
echo "--- lsattr ---"
lsattr /etc/resolv.conf 2>/dev/null || echo "(lsattr failed)"

echo ""
echo "--- /etc/wsl.conf ---"
if [ -r /etc/wsl.conf ]; then
  cat /etc/wsl.conf
else
  echo "(mode 600, 需 sudo — WSL 以 root 读取功能正常)"
  sudo -n cat /etc/wsl.conf 2>/dev/null || echo "(sudo 需密码)"
fi

echo ""
echo "--- 出口 IP ---"
curl -s --max-time 10 https://1.1.1.1/cdn-cgi/trace 2>/dev/null | grep -E "^ip=|^loc=|^colo=" || echo "(curl 失败 — 检查 SakuraCat TUN 节点是否连通)"

echo ""
echo "===== 验证结束 ====="

