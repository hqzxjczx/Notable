---
name: privacy
description: 跨平台隐私加固调度器 — Windows/WSL2/macOS/iOS 四端一致性配置（apply/verify/check/restore）。用户提到隐私加固、防指纹、SakuraCat、TUN、WARP、时区/DNS/语言一致性、Accept-Language、四端一致、wsl2-privacy.sh、macos-privacy.sh、windows-host-privacy-setup、ios-privacy 时使用。
allowed-tools: Read, Bash, Grep, Glob
---

# 跨平台隐私加固调度器

## 参数解析

`$ARGUMENTS` = `<action> [env] [region]`

- **action**（必填）: `apply` | `verify` | `check` | `restore`
- **env**（可选，可自动推断）: `windows` | `wsl2` | `macos` | `ios`
- **region**（默认 `us`）: `us` | `jp` | `uk` | `sg` | `cn`

若 `$ARGUMENTS` 缺 action 或含义不清，用 AskUserQuestion 询问。env 缺失时先尝试推断（见下），推断不出再问。

---

## 关键护栏（必须遵守，违反会出事）

1. **不自动执行特权命令**。HKLM 注册表、`Set-TimeZone`、`Set-DnsClientServerAddress`、`sudo`、`chattr +i` 等需要管理员/sudo 的命令，**只生成命令文本 + 说明**，让用户在 Admin PowerShell / sudo 终端里粘贴执行。CodeBuddy 工具安全策略禁止自我提权（见 memory `project_codebuddy_security_policy.md`）。
2. **Windows 语言列表必须用 New+Add 模式**，绝不写 `Set-WinUserLanguageList en-US -Force`（会清空中文输入法，见 memory `feedback_windows_ime.md`）。永远用：
   ```powershell
   $list = New-WinUserLanguageList en-US
   $list.Add("zh-Hans-CN")
   Set-WinUserLanguageList $list -Force
   ```
3. **写含中文的 .ps1 文件必须用 UTF-8 BOM**（PowerShell 5.1 把 BOM-less UTF-8 当 GBK 读，见 memory `feedback_ps1_utf8_bom.md`）。
4. **WSL2 里禁用 `bash -ic`**（无 TTY 会卡死，见 `notes/privacy-cheatsheet-beginner.md` 第四节坑 3）。
5. **验证出口 IP 用 `https://1.1.1.1/cdn-cgi/trace`**，禁用 `ipinfo.io`（429 限流）。
6. **不要动 WSL2/Meta 接口的 DNS `198.18.0.2`**（SakuraCat 隧道内部，正常）。

---

## 四柱一致性规则（所有环境必须统一，否则指纹穿帮）

| 柱 | 目标值（us 区域；其他区域见 `notes/macos-privacy.sh` 的 get_tz/get_locale/get_accept_lang）|
|---|---|
| 时区 | `America/New_York`（Windows: `Eastern Standard Time`，iOS: New York）|
| DNS | `1.1.1.1`（Windows/WSL2/iOS 隧道封装；macOS 经 WARP DNS-only）|
| 区域/locale | `en_US` / `en_US.UTF-8` / iOS `United States` + `English (US)` |
| 浏览器 Accept-Language | `en-US,en`（Chrome/Edge 改 `Preferences` JSON；Firefox 改 `user.js`）|

> 口诀：出口 IP 是美国，时区也得是美国，语言也得是英文 —— 三者一致才不露馅。

---

## env 自动推断

可执行无害命令推断 env（这些不算特权操作）：
- `uname -a` 含 `microsoft` 或 `/proc/version` 含 WSL → **wsl2**
- `uname -s` = `Darwin` → **macos**
- `$env:OS -eq 'Windows_NT'` 或 Git Bash 下 `uname -s` = `MINGW*` → 询问用户是 **windows** 还是 **wsl2**（用 AskUserQuestion）
- iOS 无法在桌面端推断 → 用户需显式声明

---

## 环境分派表

| env | apply / restore | verify / check |
|---|---|---|
| **wsl2** | `sudo bash notes/wsl2-privacy.sh apply`（restore 同理，脚本自带备份还原）| `bash notes/wsl2-privacy.sh verify` / `check`（无需 sudo）|
| **macos** | `sudo bash notes/macos-privacy.sh apply <region>`（restore 默认回到 cn）| `bash notes/macos-privacy.sh verify <region>` / `check`（无需 sudo）|
| **windows** | 读 `notes/windows-host-privacy-setup.md`，逐章生成 PowerShell 命令（管理员）| 同文档第五部分检测块 |
| **ios** | 读 `notes/ios-privacy-setup.md`，给 GUI 步骤清单（无脚本）| 按 verify 清单逐项问用户 |

**执行流程**：

1. 解析 `$ARGUMENTS`，缺失项询问用户。
2. 推断 env（见上）。
3. **用 Read 工具读取对应文档/脚本**确认命令细节，不要凭记忆生成（文档可能更新过）：
   - wsl2/macos：读 `notes/wsl2-privacy.sh` 或 `notes/macos-privacy.sh` 的 `apply`/`verify`/`restore` 函数
   - windows：读 `notes/windows-host-privacy-setup.md` 对应章节（第一部分时区、第二部分 DNS、第三部分区域、第四部分进阶、4.2 浏览器语言、第七部分 7897 端口）
   - ios：读 `notes/ios-privacy-setup.md`
4. 生成命令 + 说明，标明：
   - 是否需要管理员/sudo
   - 副作用（注销、重启、`wsl --shutdown`）
   - 验证方法与期望值（`loc=US`、`colo=SJC/LAX` 等）
5. verify 后列出通过/未通过项，附 `notes/privacy-cheatsheet-beginner.md` 第三节验证清单链接。

---

## 各环境要点速查（避免每次重读全文）

### WSL2（脚本 `notes/wsl2-privacy.sh`）
- 架构：**继承 Windows 宿主机 SakuraCat TUN**，无需 7897 代理变量（`http_proxy` 应为空）
- 关键操作：锁 `/etc/resolv.conf`（`chattr +i`）、写 `.bashrc` + `.profile` + `/etc/environment` 三处（.bashrc 有非交互保护，只写一处不够）
- systemd 自动检测：22.04 启用（要保留）、24.04 默认关闭，脚本会判断
- 生效需在 PowerShell 执行 `wsl --shutdown` 后重新进入
- 适用于 Ubuntu-22.04 与 Ubuntu-24.04 双实例

### macOS（脚本 `notes/macos-privacy.sh`）
- 架构：SakuraCat **代理 7897** + Cloudflare **WARP DNS-only**（**不是全隧道**）
- WARP 必须是 DNS 模式 —— 开全隧道会覆盖 SakuraCat 出口 IP，变成 Cloudflare
- 关 iCloud 私有中继（与 WARP 抢 DNS）
- Chrome Accept-Language 由脚本内 `set_browser_languages()` 自动改 `Preferences` JSON（Local State + 所有 Profile）
- 关所有活跃接口 IPv6（防绕过 WARP DNS）
- 支持 region 参数：us/jp/uk/sg/cn

### Windows 宿主（文档 `notes/windows-host-privacy-setup.md`）
- 架构：SakuraCat **TUN 模式**（Meta 网卡抓全流量）+ 本地 **7897 混合端口**（给 Docker/容器显式用，与 macOS 端口一致）
- 关自动时区：`Set-ItemProperty HKLM:\...\tzautoupdate Start=4`
- Wi-Fi DNS 改 `1.1.1.1, 8.8.8.8`（**不要动 Meta 的 198.18.0.2**）
- Chrome/Edge Accept-Language：用 4.2 节 PowerShell+Python 脚本改 `Local State` + 所有 Profile 的 `Preferences`（必须先完全退出浏览器）
- Firefox 用 `user.js` 持久化 `intl.accept_languages`
- DoH 系统级仅 Win11+，Win10 用浏览器层 DoH
- 恢复脚本见文档第六部分（含 `.bak.privacy` 还原）

### iOS（文档 `notes/ios-privacy-setup.md`）
- SakuraCat iOS **全隧道**（或代理 + Cloudflare 1.1.1.1）
- 关 iCloud 私有中继
- Safari WebRTC **保留 mDNS**（禁用会暴露真实 IP）
- 无脚本，纯 GUI/描述文件操作

---

## 三大坑速记（必背）

1. **Chrome/Edge Accept-Language 独立于系统语言** —— 改系统语言不够，必须改 `Preferences` JSON 或 `user.js`。
2. **`Set-WinUserLanguageList en-US -Force` 删输入法** —— 永远用 `New-WinUserLanguageList` + `Add`。
3. **`bash -ic` 卡死 WSL** —— 脚本里禁用，验证改用文件检查 + `net-test.sh`。

详见 `notes/privacy-overview.md` 第五节「关键坑速记」。

---

## 完成后

- 提示用户访问 `https://browserleaks.com/ip` 验证 HTTP `Accept-Language` 头（应为 `en-US,en;q=0.9`，无 `zh`）。
- 提示用 `https://1.1.1.1/cdn-cgi/trace` 验证 `loc=US`。
- 若有失败项，引用 `notes/privacy-overview.md` 第四节「跨平台一致性核对结论」与第五节排查。
- **不要把这些写进 memory**：四柱规则、命令清单都在 `notes/` 文档里可派生，写 memory 会重复。
- 若用户提到新的环境差异或坑（文档里没有的），才考虑更新 memory 或 `notes/privacy-overview.md`。
