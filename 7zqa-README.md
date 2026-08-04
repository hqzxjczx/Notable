# 7z Finder 右键快速压缩 · 使用说明

把文件 / 文件夹右键压缩成 `.7z`，可选 AES-256 密码加密，压缩完成有系统横幅通知。

## 依赖

- macOS（本机 Tahoe 26，Apple Silicon）
- `p7zip`：`brew install p7zip`（提供 `/opt/homebrew/bin/7z`）

## 已实现的右键项

两个 Finder 快速操作（Quick Action / 服务）：

| 右键项              | 行为                                                                                | 脚本调用               |
| ------------------- | ----------------------------------------------------------------------------------- | ---------------------- |
| **7z 压缩**         | 弹出密码框；留空=不加密，填密码=AES-256 强加密（含文件名加密 `-mhe=on`），取消=中止 | `7zqa.sh "$@"`         |
| **7z 压缩(无密码)** | 跳过密码框，直接不加密压缩                                                          | `7zqa.sh --no-pw "$@"` |

两者共用同一个核心脚本 `7zqa.sh`，逻辑单一来源。

## 工作流程（以「7z 压缩」为例）

1. Finder 里右键选中文件 / 文件夹（可多选）。
2. 服务菜单 → **7z 压缩**。
3. 弹密码框：「设置压缩密码（留空 = 不加密）」——
   - 留空 + 确定 → 不加密
   - 填密码 + 确定 → AES-256 强加密（同时加密文件名）
   - 取消 → 中止，不做任何事
4. 弹目录选择框：「选择压缩包输出目录」（默认定位到选中项所在目录），取消=中止。
5. 按选中项自动命名生成 `.7z`：
   - 单个文件 `report.pdf` → `report.7z`
   - 单个文件夹 `Photos` → `Photos.7z`
   - 多个 → 用它们所在父目录名
   - 同名已存在时自动加序号：`report (1).7z`
6. 压缩完成，右上角弹横幅「已生成 xxx.7z」。

## 文件清单

```
~/bin/7zqa.sh                                 核心脚本（两个右键项共用）
~/Library/Services/7z 压缩.workflow           带密码版右键项
~/Library/Services/7z 压缩(无密码).workflow    无密码版右键项
```

## 完成通知方案（重要）

- **用 `osascript display notification`**，不用 `terminal-notifier`。
- 原因：terminal-notifier 走已废弃的 `NSUserNotification` API，在 macOS Tahoe 上第三方应用横幅会被系统抑制（app 能启动、退出码 0、能弹授权框，但横幅就是不显示）。`osascript` 的通知归到 Apple 自家的 Script Editor，不受抑制，能稳定弹出。
- **已知瑕疵**：点横幅的「显示」会打开脚本编辑器（`display notification` 不支持自定义点击跳转）。
- 调试日志：`/tmp/7zqa.log`（每次压缩写一行 `时间 out=路径 notify_rc=退出码`）。

## 如何卸载

```bash
rm -rf "/Users/fatestayzerotw/Library/Services/7z 压缩.workflow"
rm -rf "/Users/fatestayzerotw/Library/Services/7z 压缩(无密码).workflow"
rm -f  /Users/fatestayzerotw/bin/7zqa.sh
rm -f  /tmp/7zqa.log
# 若想彻底移除依赖：brew uninstall p7zip
```

## 未做的可选项（按用户决定跳过）

- B1 改名/换输出位置独立项：输出目录选择已用 `choose folder` 覆盖，自定义文件名未单独做。
- B3 `.zip` 弱加密版（ZipCrypto）：未做；如需对外发送可用 `zip -e` 另起一项。
- 单独的卸载/回滚说明文档：未做（见上「如何卸载」）。
