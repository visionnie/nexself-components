# =====================================================================
# build-component.ps1
#   把某个源目录打包成组件 zip 放到 packages/，算 SHA-256。
#
# 用法：
#   .\scripts\build-component.ps1 -SourceDir ".\packages\_src\frpc-windows-x64"
#   .\scripts\build-component.ps1 -SourceDir "F:\...\theme-dark" -Id "theme-dark-v1"
#
# 参数：
#   -SourceDir   必填，组件源文件所在目录（内容平铺进 zip 根）
#   -Id          可选，默认从源目录的 .nexself-component.json 读
#   -Version     可选，同上
#   -OutDir      可选，默认 <repo>/packages/
#
# 输出：
#   写 packages/<id>-<version>.zip，打印体积和 SHA-256
#
# ⚠️ 打完**不用**改 manifest.json —— 传 Release 后由 .github/workflows/update-manifest.yml
#    自动重算并提交。手工改会在下次发 Release 时被覆盖。
# =====================================================================

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SourceDir,

    [string]$Id = "",

    [string]$Version = "",

    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $SourceDir -PathType Container)) {
    Write-Host "[FAIL] SourceDir 不存在或不是目录: $SourceDir" -ForegroundColor Red
    exit 1
}

# ── 校验：组件包的两条硬要求（客户端 api/components.rs 会卡这两条）──
$descPath = Join-Path $SourceDir ".nexself-component.json"
if (-not (Test-Path $descPath)) {
    Write-Host "[FAIL] 源目录缺 .nexself-component.json —— 客户端装的时候会判定「组件 zip 打包不合规」并删目录" -ForegroundColor Red
    exit 1
}
# 带 BOM 的 UTF-8 会让 Rust 侧 serde_json 直接解析失败
$descBytes = [System.IO.File]::ReadAllBytes($descPath)
if ($descBytes.Length -ge 3 -and $descBytes[0] -eq 239 -and $descBytes[1] -eq 187 -and $descBytes[2] -eq 191) {
    Write-Host "[FAIL] .nexself-component.json 带 BOM，客户端解析会失败。存成 UTF-8 无 BOM 再来" -ForegroundColor Red
    exit 1
}
# 注意：PowerShell 5.1 的 Get-Content 按 ANSI 读，中文会乱码；必须显式 UTF-8
$desc = [System.IO.File]::ReadAllText($descPath, (New-Object System.Text.UTF8Encoding $false)) | ConvertFrom-Json

if ([string]::IsNullOrEmpty($Id))      { $Id = $desc.id }
if ([string]::IsNullOrEmpty($Version)) { $Version = $desc.version }
if ([string]::IsNullOrEmpty($Id) -or [string]::IsNullOrEmpty($Version)) {
    Write-Host "[FAIL] 描述文件里缺 id 或 version，且没有从参数传入" -ForegroundColor Red
    exit 1
}
if ((Get-ChildItem $SourceDir -Force -Directory).Count -gt 0) {
    Write-Host "[FAIL] 源目录里有子目录 —— 客户端的 extract_zip_flat() 只认平铺结构" -ForegroundColor Red
    exit 1
}

# 默认输出到本仓 packages/
if ([string]::IsNullOrEmpty($OutDir)) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $OutDir = Join-Path $repoRoot "packages"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# 文件名带版本：id 不含版本号的组件（如 frpc-windows-x64）靠它区分 Release
$baseName = "$Id-$Version"
$zipPath = Join-Path $OutDir "$baseName.zip"
if (Test-Path $zipPath) {
    Write-Host "-> 覆盖已有 $zipPath" -ForegroundColor Yellow
    Remove-Item $zipPath -Force
}

# 用 .NET ZipFile 保证 dot-file (.nexself-component.json 等) 也进包
# —— Compress-Archive -Path "dir\*" 会**漏掉点开头的文件**，踩过
Write-Host "-> 打包 $SourceDir → $zipPath" -ForegroundColor Cyan
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($zipPath, "Create")
try {
    $files = Get-ChildItem $SourceDir -Force -File
    foreach ($f in $files) {
        Write-Host "   + $($f.Name)"
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, $f.FullName, $f.Name,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
} finally {
    $archive.Dispose()
}

$sz = (Get-Item $zipPath).Length
$sha = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()

Write-Host ""
Write-Host "[OK] 生成完成" -ForegroundColor Green
Write-Host "  组件:   $Id v$Version ($($desc.kind))"
Write-Host "  路径:   $zipPath"
Write-Host "  大小:   $sz bytes ($([math]::Round($sz/1MB,2)) MB)"
Write-Host "  SHA256: $sha"
Write-Host ""
Write-Host "-> 接下来只有一步：" -ForegroundColor Cyan
Write-Host "  1. https://github.com/visionnie/nexself-components/releases/new"
Write-Host "  2. Tag: $baseName  （选 Create new tag on publish）"
Write-Host "  3. 正文写变更说明 —— 会被自动写进 manifest 的 changelog"
Write-Host "  4. 附件拖入: $zipPath"
Write-Host "  5. Publish"
Write-Host ""
Write-Host "  manifest.json 由 Actions 自动更新，不要手工改。" -ForegroundColor Yellow
