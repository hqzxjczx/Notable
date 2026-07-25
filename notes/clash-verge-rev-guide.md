# Clash Verge Rev macOS 完全指南

## 目录

- [快速入门](#快速入门)
- [DNS 与 DoH 配置](#dns-与-doh-配置)
- [链式代理（前置代理）](#链式代理前置代理)
- [常见问题](#常见问题)

---

## 快速入门

### 1. 下载与安装

1. 前往 [GitHub Releases](https://github.com/clash-verge-rev/clash-verge-rev/releases) 下载 macOS 版本（`.dmg`）
2. 拖入 Applications 文件夹
3. 首次打开如遇"无法验证开发者"，前往 **系统设置 → 隐私与安全性** 点击"仍要打开"

### 2. 导入订阅

**远程导入（推荐）：**

1. 打开 Clash Verge → 左侧点击「订阅」/「Profiles」
2. 在顶部输入框粘贴机场订阅链接
3. 点击「Import / 导入」按钮
4. 等待下载完成，配置文件出现在列表中

**本地导入：**

- 将 `.yaml` 配置文件直接拖入窗口（v1.6.2+）
- 或点击「New」手动创建

> 导入成功后，点击该配置卡片使其高亮（表示当前激活）。

### 3. 选择节点和模式

点击左侧「代理」/「Proxies」页面。

**三种工作模式：**

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| 规则（Rule） | 按配置文件中的规则分流，国内直连、国外走代理 | 日常使用（推荐） |
| 全局（Global） | 所有流量走代理 | 需要全部翻墙时 |
| 直连（Direct） | 所有流量直连，等于关闭代理 | 调试/不需要代理时 |

**选择节点：**

- 在 Proxies 页面展开代理组，点击选择具体节点
- 可点击测速按钮测试延迟，选延迟低的

### 4. 开启代理

**方式一：系统代理（适合浏览器等常规应用）**

- 点击主界面「系统代理」开关（或托盘图标右键开启）
- 原理：设置 macOS 系统代理，浏览器和遵循系统代理的应用会走 Clash
- 大部分场景够用

**方式二：TUN 模式（适合不走系统代理的程序）**

- 点击「Tun 模式」开关
- 原理：创建虚拟网卡，在系统层面接管所有流量
- 适用：游戏、终端命令行、不遵循系统代理的应用
- 首次开启可能需要授权（输入密码）

> **TUN 模式的泄漏防护优势**：TUN 在系统层接管所有流量（含 UDP），可同时修复两类泄漏：
> - **DNS 泄漏**：TUN 的 `dns-hijack: [any:53]` 会拦截所有 DNS 查询，无需依赖系统 DNS 覆写。
> - **WebRTC 泄漏**：WebRTC 的 STUN/UDP 流量也被 TUN 接管，不会绕过代理暴露真实 IP。
>
> 不开 TUN 时：DNS 泄漏靠 DNS 覆写（设置系统 DNS 指向 127.0.0.1），WebRTC 泄漏靠浏览器设置（扩展/about:config）。
> 开 TUN 后：两者都由 TUN 兜底，是最省心的方案。

> 一般建议：系统代理 + TUN 模式同时开启，确保无遗漏。

### 5. 规则配置

右键点击订阅配置 → 「编辑规则」。

**支持的规则类型：**

- `DOMAIN` / `DOMAIN-SUFFIX` — 按域名匹配
- `IP-CIDR` / `IP-CIDR6` — 按 IP 段匹配
- `GEOIP` — 按地理位置（如 `GEOIP,CN,DIRECT`）
- `PROCESS-NAME` — 按进程名匹配
- `MATCH` — 兜底规则（放最后）

**前置规则：**

- 编辑「前置规则」可以插入优先级最高的自定义规则
- 例如让某个域名强制走代理或直连，不受订阅配置影响

**规则示例：**

```yaml
rules:
  - DOMAIN-SUFFIX,google.com,Proxy
  - DOMAIN-SUFFIX,baidu.com,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,Proxy
```

### 6. 托盘图标快捷操作

菜单栏托盘图标右键可以快速：

- 切换模式（规则/全局/直连）
- 开关系统代理 / TUN
- 切换配置
- 退出程序

---

## DNS 与 DoH 配置

### 为什么需要 DNS 覆写？

不开启时，DNS 查询仍走运营商默认 DNS（明文），会导致：

- **DNS 泄漏** — 即使流量走了代理，DNS 请求暴露了你访问的域名
- **DNS 污染** — 某些域名被劫持返回错误 IP，导致连不上

开启 DNS 覆写后，Clash 接管所有 DNS 解析，配合 DoH 加密查询，防止泄漏。

### 推荐配置

在 **设置 → DNS** 面板中：

```yaml
dns:
  enable: true            # 开启 DNS 覆写
  enhanced-mode: fake-ip  # 推荐 fake-ip 模式（响应快、防泄漏）
  fake-ip-range: 198.18.0.1/16
  nameserver:             # 国内域名用国内 DoH
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  fallback:               # 国外域名用国外 DoH（防污染）
    - https://dns.google/dns-query
    - https://cloudflare-dns.com/dns-query
  fallback-filter:
    geoip: true
    geoip-code: CN
```

### 是否需要开启？

| 场景 | 建议 |
|------|------|
| 开启 TUN 模式 | 强烈建议开启 DNS 覆写 + DoH |
| 仅用系统代理 + 订阅已内置 DNS 配置 | 可不额外开启 |
| 订阅只有 `nameserver: 8.8.8.8` 明文 | 建议开启覆写 |

**判断方法：** 打开订阅配置文件，搜索 `dns:` 段，查看是否已有完善的 DoH 配置。

---

## 链式代理（前置代理）

### 什么是链式代理？

流量路径变为多跳：

```
你的设备 → 入口代理(A) → 出口代理(B) → 目标网站
```

**常见用途：**

- 机场节点（入口）+ 住宅 IP 代理（出口），降低被封风险
- 经过中转节点隐藏真实出口 IP
- 多层加密，增强隐私

### 方法一：GUI 配置（v2.45+）

1. 打开 **代理（Proxies）** 页面
2. 找到目标节点，点击 **编辑**
3. 添加前置代理 URI，格式：
   ```
   http://user:pass@ip:port
   socks5://user:pass@ip:port
   ```
4. 可添加多个，按顺序排列（流量依次经过）
5. 保存后该节点即走链式路径

### 方法二：YAML 配置（dialer-proxy）

```yaml
proxies:
  # 入口节点（比如机场节点）
  - name: "机场节点"
    type: ss
    server: airport.example.com
    port: 443
    cipher: aes-256-gcm
    password: "xxx"

  # 出口节点（比如住宅IP代理）
  - name: "住宅代理"
    type: socks5
    server: residential.example.com
    port: 1080
    username: "user"
    password: "pass"
    dialer-proxy: "机场节点"   # 关键：指定前置代理

proxy-groups:
  - name: "链式出口"
    type: select
    proxies:
      - "住宅代理"    # 选这个 = 流量走 机场→住宅→目标
```

核心字段：`dialer-proxy` — 指定该节点连接时先经过哪个代理。

### 方法三：脚本覆写（Merge/Script）

右键订阅 → 「编辑文件」→ 选 Merge 或 Script。

**Merge 方式（追加配置）：**

```yaml
prepend-proxies:
  - name: "住宅代理"
    type: socks5
    server: 1.2.3.4
    port: 1080
    username: "user"
    password: "pass"
    dialer-proxy: "你的机场节点名"
```

**Script 方式（JS 修改配置）：**

```javascript
function main(config) {
  config.proxies.push({
    name: "链式节点",
    type: "socks5",
    server: "1.2.3.4",
    port: 1080,
    username: "user",
    password: "pass",
    "dialer-proxy": "机场节点名"
  });
  return config;
}
```

### 验证是否生效

1. 开启代理后访问 `ipinfo.io` 或 `ip.sb`
2. 在 Clash Verge 的 **连接（Connections）** 面板查看链路
3. 确认出口 IP 是出口代理的 IP，而非入口节点的 IP

### 注意事项

| 项目 | 说明 |
|------|------|
| 延迟叠加 | 每多一跳延迟增加，链越长越慢 |
| 协议支持 | `dialer-proxy` 支持 ss、vmess、trojan、socks5、http 等 |
| 不能循环 | A 的 dialer-proxy 指向 B，B 不能再指回 A |
| 版本要求 | Mihomo 内核（Clash Meta）才支持，原版 Clash 不支持 |

---

## 常见问题

| 问题 | 解决 |
|------|------|
| 开了代理但浏览器不生效 | 确认「系统代理」开关已打开 |
| 终端/命令行不走代理 | 开启 TUN 模式，或手动 `export https_proxy=http://127.0.0.1:7897` |
| 节点连不上 | 切换节点、更新订阅、检查订阅是否过期 |
| 开机自启 | 设置 → 开启「开机启动」 |
| DNS 泄漏 | 开启 DNS 覆写 + DoH，使用 fake-ip 模式 |
| 链式代理不生效 | 确认内核为 Mihomo，检查 `dialer-proxy` 名称拼写 |

---

## 参考链接

- [Clash Verge Rev 官方文档](https://www.clashverge.dev/guide/quickstart.html)
- [规则配置](https://www.clashverge.dev/guide/rules.html)
- [链式代理](https://www.clashverge.dev/guide/proxy_chain.html)
- [配置管理](https://www.clashverge.dev/guide/profile.html)
- [Mihomo 懒人配置](https://gist.github.com/liuran001/5ca84f7def53c70b554d3f765ff86a33)
