#!/usr/bin/env bash
# net-test.sh — WSL2 网络连通性测试
echo "===== $(lsb_release -ds 2>/dev/null || echo Ubuntu) 网络测试 ====="
echo ""
echo "--- DNS 解析 ---"
for host in github.com google.com baidu.com; do
  ip=$(getent hosts "$host" 2>/dev/null | awk '{print $1}' | head -1)
  if [ -n "$ip" ]; then echo "  $host -> $ip OK"; else echo "  $host -> FAIL"; fi
done
echo ""
echo "--- HTTPS 连通性 (HTTP 状态码) ---"
for url in "https://1.1.1.1/cdn-cgi/trace" "https://www.google.com/generate_204" "https://github.com" "https://www.baidu.com" "https://pypi.org"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null)
  if [ "$code" = "000" ]; then
    echo "  $url -> TIMEOUT/FAIL"
  else
    echo "  $url -> HTTP $code"
  fi
done
echo ""
echo "--- 出口 IP / 地理位置 ---"
curl -s --max-time 10 https://1.1.1.1/cdn-cgi/trace 2>/dev/null | grep -E "^(ip|loc|colo)=" | sed 's/^/  /'
echo ""
echo "--- apt 源可达性 (Ubuntu 24.04/22.04) ---"
code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://archive.ubuntu.com/ubuntu/dists/$(lsb_release -cs 2>/dev/null)/Release" 2>/dev/null)
echo "  archive.ubuntu.com -> HTTP $code"
echo ""
echo "===== 测试结束 ====="
