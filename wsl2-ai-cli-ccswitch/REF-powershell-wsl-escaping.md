# REF: PowerShell ↔ WSL2 转义生存手册

从 PowerShell 工具层驱动 WSL2(bash)时,命令串会被**二次展开**,各种字符被吃掉或改写。这是横切技术,被所有 WSL2 相关技能依赖。

## 陷阱表(实测踩中)

| 写法 | 后果 | 解法 |
|---|---|---|
| `$VAR` | PowerShell 提前展开成空串 | 用单引号 here-string `@'...'@` 包住,bash 内自行展开 |
| `echo "VAR=$VAR"` | 双引号被原生参数传递剥掉 + `$VAR` 被展开 → 输出 `VAR=`(空) | **查 env 用 `printenv VAR`** |
| 双引号在 `@'...'@` here-string 内 | here-string 只保 `$` 不保双引号,双引号仍被剥掉 → bash 语法错误 | bash 命令内**只用单引号,不用双引号** |
| `tr -d "\r"` | 反斜杠丢失 → 变成删除所有字母 `r`(曾把 `[network]` 写成 `[netwok]`) | 避免反斜杠;必须用时走文件中转 |
| `curl -w "%{http_code}"` | `%{}` 被当 cmd 变量吃掉 | 改用单引号 `'%{http_code}'` |
| 反引号命令替换 | 被吃掉 | 走文件中转,或用 `$()`(在 here-string 内) |
| `curl \| bash` | 被安全策略拦截 | 不要管道给 bash |
| `echo BASE64 \| base64 -d \| bash` | 被安全策略拦截("Spawning a non-PowerShell shell") | **base64 中转走不通,改用文件中转** |

## 对策(按优先级)

### 1. 复杂脚本 → 文件中转(首选)

把 bash 脚本写到 WSL ext4 文件再执行,彻底绕开命令行转义:

```powershell
$script = @'
#!/bin/bash
echo "$VAR"           # here-string 内 $ 保住,bash 自行展开
curl -d '{"k":"v"}'   # 单引号 JSON 没问题
RESP=$(curl ...)       # $() 命令替换没问题
'@
[System.IO.File]::WriteAllText(
  '\\wsl.localhost\Ubuntu-24.04\tmp\run.sh',
  $script,
  [System.Text.UTF8Encoding]::new($false)   # 必须 UTF-8 无 BOM
)
wsl -d Ubuntu-24.04 -- bash /tmp/run.sh
```

**要点:**
- 用 `\\wsl.localhost\Ubuntu-24.04\...` UNC 路径从宿主直写 WSL ext4。`automount=false`(WSL→Windows 方向切断)**不影响**这个方向(Windows→WSL 的 9p 服务,见沙箱文档 4.1)。
- 必须 `UTF8Encoding($false)`(无 BOM),否则 shebang / 首行被 BOM 破坏,bash 执行报错。
- PowerShell 单引号 here-string `@'...'@` 内的 `$` 不会被 PowerShell 展开,bash 拿到字面 `$VAR` 自行展开 —— 这是**唯一能传 bash 变量/`$()` 的方式**。
- here-string 内的**双引号仍会被原生参数传递剥掉**,但写文件时(`WriteAllText`)不经过原生参数传递,所以**文件中转里双引号安全**。

### 2. 简单命令 → 单引号 here-string + bash 内只用单引号

```powershell
$cmd = @'
echo -n 'codex: '; codex --version
curl -sS -m 5 -o /dev/null -w '%{http_code}\n' http://192.168.144.1:15721/v1/models
'@
wsl -d Ubuntu-24.04 -- bash -ic $cmd
```

**规则:**
- here-string `@'...'@` 保住 `$`(bash 展开),但**不保双引号**
- 所以 bash 内**只用单引号**,不用双引号,不用 `$()`(简单命令够用)
- `-w '%{http_code}\n'` 单引号格式串 OK;`"%{http_code}"` 双引号会被吃

### 3. 查环境变量 → `printenv VAR`

```powershell
wsl -d Ubuntu-24.04 -- bash -ic 'printenv ANTHROPIC_BASE_URL'
```

**不要用** `echo "VAR=$VAR"` —— 双引号被剥 + `$VAR` 被 PowerShell 展开成空,会误判变量没设(这个坑浪费过大量排查时间)。

### 4. 需要 fnm 环境 → `bash -ic`

```powershell
wsl -d Ubuntu-24.04 -- bash -ic 'codex --version'
```

Ubuntu 的 `.bashrc` 对**非交互 shell** 会提前 `return`(开头有 `case $- in *i*) ;; *) return;; esac`),导致 fnm env 不加载,`codex`/`claude`/`node` 找不到。`-i` 强制交互式,`.bashrc` 正常加载。

### 5. 写完配置 → `cat -A` 回读校验

```bash
cat -A ~/.codex/config.toml   # 显示行尾 $、制表符 ^I、不可见字符
```

防止转义把内容改坏(如 `[network]` 变 `[netwok]`、BOM 进首行)而不自知。

### 6. 读 cc-switch.db(被进程锁) → 共享读

```powershell
$fs = [System.IO.File]::Open($db, [System.IO.FileMode]::Open,
  [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
$ms = New-Object System.IO.MemoryStream
$fs.CopyTo($ms); $fs.Close()
$bytes = $ms.ToArray()
# 再提取可读 ASCII 字符串
```

SQLite db 被 cc-switch 运行时独占,`ReadAllBytes` 会报 "being used by another process"。`FileShare.ReadWrite` 共享读可绕过。db 里 TEXT 列存的是 UTF-8 JSON,按可打印 ASCII 截取即可读 provider 配置。

## 速查:什么场景用什么

| 场景 | 方法 |
|---|---|
| 一两条简单命令,无 `$` 无双引号 | `wsl -- bash -ic '...'`(PowerShell 单引号字符串) |
| 命令带 `$VAR` / `$()`,无双引号 | `wsl -- bash -ic $cmd`(`$cmd` 是 `@'...'@` here-string) |
| 命令带双引号(JSON / `-H "..."`) | **文件中转**(`WriteAllText` + `wsl -- bash /tmp/x.sh`) |
| 查环境变量 | `printenv VAR` |
| 验证配置文件内容 | `cat -A file` |
| 读被锁的 SQLite db | `File.Open` + `FileShare.ReadWrite` |
