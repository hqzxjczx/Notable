# sync-codex-config.ps1
# 把宿主机 cc-switch 生成的 Codex 配置同步到 WSL2
# 用法: 在宿主机 PowerShell 里运行
#   .\sync-codex-config.ps1                          # 默认 Ubuntu-24.04 / hqzxj
#   .\sync-codex-config.ps1 -Distro Ubuntu-22.04     # 指定发行版
#   .\sync-codex-config.ps1 -Test                    # 同步后跑一次冒烟测
#
# 背景: cc-switch 检测不到 WSL2 里的 codex,只把 config.toml + catalog 写到宿主 ~/.codex/。
#       WSL2 的 codex 读不到这些文件 → "Model metadata not found" 警告 + 工具调用可能异常。
#       本脚本把两个文件同步过去。
#
# ⚠️ config.toml 不是原样拷:宿主版含 requires_openai_auth=true + experimental_bearer_token,
#    会让交互式 codex 要求登录。本脚本打补丁:去掉这两行,改用 env_key=OPENAI_API_KEY
#    (配合 WSL2 .bashrc 里的 dummy key)。

param(
    [string]$Distro = "Ubuntu-24.04",
    [string]$User = "hqzxj",
    [switch]$Test
)

$ErrorActionPreference = "Stop"

$src = "$env:USERPROFILE\.codex"
$dst = "\\wsl.localhost\$Distro\home\$User\.codex"

Write-Host "=== 同步 Codex 配置: 宿主 -> WSL2 ($Distro) ===" -ForegroundColor Cyan

if (-not (Test-Path $src)) {
    Write-Error "宿主 ~/.codex 不存在: $src`n请先在 cc-switch 里配置 Codex provider 并启动路由。"
    exit 1
}
if (-not (Test-Path $dst)) {
    Write-Error "WSL2 ~/.codex 不可达: $dst`n确认 WSL2 已启动: wsl -l --running"
    exit 1
}

# 1. catalog 原样拷贝
$catalogSrc = Join-Path $src "cc-switch-model-catalog.json"
$catalogDst = Join-Path $dst "cc-switch-model-catalog.json"
if (Test-Path $catalogSrc) {
    Copy-Item $catalogSrc $catalogDst -Force
    Write-Host "  已同步: cc-switch-model-catalog.json ($((Get-Item $catalogDst).Length) bytes)" -ForegroundColor Green
} else {
    Write-Warning "源 catalog 不存在,跳过"
}

# 2. config.toml 打补丁后写入(不原样拷)
$cfgSrc = Join-Path $src "config.toml"
if (Test-Path $cfgSrc) {
    $cfg = Get-Content $cfgSrc -Raw
    # 去掉 requires_openai_auth 行(会让交互式 codex 要求登录)
    $cfg = $cfg -replace 'requires_openai_auth\s*=\s*true\r?\n', ''
    # 把 experimental_bearer_token = "PROXY_MANAGED" 替换成 env_key = "OPENAI_API_KEY"
    $cfg = $cfg -replace 'experimental_bearer_token\s*=\s*"[^"]*"', 'env_key = "OPENAI_API_KEY"'
    # 写入 WSL2(UTF-8 无 BOM,TOML 不需要 BOM)
    [System.IO.File]::WriteAllText((Join-Path $dst "config.toml"), $cfg, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  已同步(打补丁): config.toml" -ForegroundColor Green
    Write-Host "    去掉: requires_openai_auth = true" -ForegroundColor DarkGray
    Write-Host "    替换: experimental_bearer_token -> env_key = OPENAI_API_KEY" -ForegroundColor DarkGray
} else {
    Write-Warning "源 config.toml 不存在,跳过"
}

# 3. 验证
Write-Host "`n=== WSL2 侧验证 ===" -ForegroundColor Cyan
wsl -d $Distro -- bash -ic 'echo "--- config.toml ---"; cat ~/.codex/config.toml; echo; echo "--- catalog ---"; ls -la ~/.codex/cc-switch-model-catalog.json 2>&1'

# 4. 冒烟测(可选)
if ($Test) {
    Write-Host "`n=== 冒烟测: codex exec PONG ===" -ForegroundColor Cyan
    wsl -d $Distro -- bash -ic 'cd ~ && timeout 60 codex exec --skip-git-repo-check --ephemeral -s read-only --color never -o /tmp/sync_test.txt ''reply with exactly: PONG'' 2>&1 | tail -6; echo "---"; cat /tmp/sync_test.txt 2>/dev/null'
} else {
    Write-Host "`n(加 -Test 参数可同步后自动跑冒烟测)" -ForegroundColor DarkGray
}

Write-Host "`n=== 完成 ===" -ForegroundColor Green
Write-Host "提示: 在 cc-switch GUI 里切了 Codex provider 后,重新跑本脚本即可同步新配置。" -ForegroundColor Yellow