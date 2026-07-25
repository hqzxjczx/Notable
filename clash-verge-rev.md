```yml
# Profile Enhancement Merge Template for Clash Verge

profile:
  store-selected: true
# dns:
#   enable: true
#   ipv6: false
#   enhanced-mode: fake-ip
#   fake-ip-range: 198.18.0.1/16
#   fake-ip-filter:
#     - '+.lan'
#     - localhost
#   nameserver:
#     # 国内加密DoH，直连解析国内网站
#     - https://doh.pub/dns-query
#     - https://dns.alidns.com/dns-query
#   fallback:
#     # 境外加密DoH/DoT，走代理解析海外域名
#     - https://1.1.1.1/dns-query
#     - https://8.8.8.8/dns-query
#     - tls://1.1.1.1:853
#   fallback-filter:
#     geoip: true
#     geoip-code: CN
dns:
  enable: true
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - '+.lan'
    - localhost
  default-nameserver:          # ← 新增：引导解析 DoH 域名
    - 223.6.6.6
    - 8.8.8.8
  proxy-server-nameserver:     # ← 新增：解析代理服务器域名
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  respect-rules: true          # ← 新增：DNS 跟随分流规则
  nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  fallback:
    - https://1.1.1.1/dns-query
    - https://8.8.8.8/dns-query
    - tls://1.1.1.1:853
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:                    # ← 新增：拦截污染 IP
      - 240.0.0.0/4
      - 0.0.0.0/32
    domain:                    # ← 新增：强制走 fallback 的域名
      - '+.google.com'
      - '+.facebook.com'
      - '+.youtube.com'

# 2. 链式代理：美国静态住宅IP
# proxies:
#   - name: "美国静态住宅出口"
#     type: socks5
#     server: 住宅IP
#     port: 端口
#     username: 账号
#     password: 密码
#     udp: true
#     dialer-proxy: "新加坡-01"

# 内网打印机、局域网访问异常：将 enhanced-mode: fake-ip 改为 enhanced-mode: redir-host
# 浏览器打开 https://ip.sb，页面 IP 显示为你的美国静态住宅 IP 即搭建成功
```
