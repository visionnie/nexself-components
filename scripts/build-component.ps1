# =====================================================================
# build-component.ps1
#   把某个源目录打包成 <id>.zip 放到 packages/，算 SHA-256，输出可直接
#   贴进 manifest.json 的字段。
#
# 用法：
#   .\scripts\build-component.ps1 -SourceDir "F:\...\bge-small-zh" -Id "bge-small-zh-v1.5"
#   .\scripts\build-component.ps1 -SourceDir ".\src\theme-dark" -Id "theme-dark-v1"
#
# 参数：
#   -SourceDir   必填，组件源文件所在目录（内容会平铺进 zip 根）
#   -Id          必填，组件 id，用作 zip 文件名（xxx.zip）
#   -OutDir      可选，默认 <repo>/packages/
#
# 输出：
#   写 packages/<id>.zip
#   打印 sizeBytes / sha256 / 首选 download URL 模板，方便复制粘贴
# =====================================================================

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SourceDir,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Id,

    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $SourceDir -PathType Container)) {
    Write-Host "[FAIL] SourceDir 不存在或不是目录: $SourceDir" -ForegroundColor Red
    exit 1
}

# 默认输出到本仓 packages/
if ([string]::IsNullOrEmpty($OutDir)) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $OutDir = Join-Path $repoRoot "packages"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$zipPath = Join-Path $OutDir "$Id.zip"
if (Test-Path $zipPath) {
    Write-Host "-> 覆盖已有 $zipPath" -ForegroundColor Yellow
    Remove-Item $zipPath -Force
}

# 用 .NET ZipFile 保证 dot-file (.nexself-component.json 等) 也进包
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
Write-Host "  路径:  $zipPath"
Write-Host "  大小:  $sz bytes ($([math]::Round($sz/1MB,2)) MB)"
Write-Host "  SHA256: $sha"
Write-Host ""
Write-Host "-> 贴进 manifest.json 的字段：" -ForegroundColor Cyan
Write-Host @"
      "sizeBytes": $sz,
      "sha256": "$sha",
      "download": {
        "primary": "https://github.com/visionnie/nexself-components/releases/download/$Id/$Id.zip",
        "mirrors": []
      },
"@
Write-Host ""
Write-Host "-> 上传步骤：" -ForegroundColor Cyan
Write-Host "  1. https://github.com/visionnie/nexself-components/releases → Draft a new release"
Write-Host "  2. Tag: $Id"
Write-Host "  3. Attach: $zipPath"
Write-Host "  4. Publish"
Write-Host "  5. commit + push manifest.json 变更"
