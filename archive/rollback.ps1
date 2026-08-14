# =============================================================
# DeepChat 迭代回滚脚本
# 用法: ./archive/rollback.ps1 <迭代编号>
# 示例: ./archive/rollback.ps1 001
# =============================================================

param (
    [Parameter(Mandatory=$true)]
    [string]$IterNumber
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$ArchiveDir = Join-Path $ScriptDir "iterations"
$TargetDir = Join-Path $ArchiveDir "iter_$IterNumber"

# ---- 验证 ----
if (-not (Test-Path $TargetDir)) {
    Write-Host "❌ 迭代 iter_$IterNumber 的存档不存在" -ForegroundColor Red
    Write-Host "   可用存档:"
    Get-ChildItem $ArchiveDir -Directory | ForEach-Object { Write-Host "   - $($_.Name)" }
    exit 1
}

# ---- 确认 ----
Write-Host ""
Write-Host "⚠️  即将回滚到 iter_$IterNumber" -ForegroundColor Yellow
Write-Host "   这会覆盖当前工作区中以下目录的所有文件:" -ForegroundColor Yellow
Write-Host "   - entry/src/main/ets/" -ForegroundColor Yellow
Write-Host "   - entry/src/main/resources/" -ForegroundColor Yellow
Write-Host "   - AppScope/" -ForegroundColor Yellow
Write-Host "   - 构建配置文件" -ForegroundColor Yellow
Write-Host ""
Write-Host "   请确保当前修改已存档！" -ForegroundColor Red
Write-Host ""
$confirm = Read-Host "输入 'yes' 确认回滚"

if ($confirm -ne "yes") {
    Write-Host "已取消回滚。" -ForegroundColor Gray
    exit 0
}

# ---- 执行回滚 ----
Write-Host ""
Write-Host "🔄 正在回滚到 iter_$IterNumber ..." -ForegroundColor Cyan

$ArchiveSrc = Join-Path $TargetDir "src"

try {
    # 1. 回滚 ETS 源文件
    $etsSrc = Join-Path $ArchiveSrc "entry/src/main/ets"
    $etsDst = Join-Path $ProjectRoot "entry/src/main/ets"
    if (Test-Path $etsSrc) {
        # 清理目标目录
        if (Test-Path $etsDst) {
            Remove-Item -Recurse -Force "$etsDst/*" -ErrorAction SilentlyContinue
        }
        Copy-Item -Recurse "$etsSrc/*" $etsDst -Force
        Write-Host "   ✅ entry/src/main/ets/" -ForegroundColor Green
    }

    # 2. 回滚资源文件
    $resSrc = Join-Path $ArchiveSrc "entry/src/main/resources"
    $resDst = Join-Path $ProjectRoot "entry/src/main/resources"
    if (Test-Path $resSrc) {
        Copy-Item -Recurse "$resSrc/*" $resDst -Force
        Write-Host "   ✅ entry/src/main/resources/" -ForegroundColor Green
    }

    # 3. 回滚 module.json5
    $modSrc = Join-Path $ArchiveSrc "entry/src/main/module.json5"
    $modDst = Join-Path $ProjectRoot "entry/src/main/module.json5"
    if (Test-Path $modSrc) {
        Copy-Item $modSrc $modDst -Force
        Write-Host "   ✅ entry/src/main/module.json5" -ForegroundColor Green
    }

    # 4. 回滚 AppScope
    $appSrc = Join-Path $ArchiveSrc "AppScope"
    $appDst = Join-Path $ProjectRoot "AppScope"
    if (Test-Path $appSrc) {
        Copy-Item -Recurse "$appSrc/*" $appDst -Force
        Write-Host "   ✅ AppScope/" -ForegroundColor Green
    }

    # 5. 回滚配置文件
    $cfgSrc = Join-Path $TargetDir "config"
    $cfgDst = $ProjectRoot
    if (Test-Path $cfgSrc) {
        Copy-Item "$cfgSrc/*" $cfgDst -Force
        Write-Host "   ✅ 构建配置文件" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "✅ 回滚完成！项目已恢复到 iter_$IterNumber 的状态。" -ForegroundColor Green
    Write-Host "   请在 DevEco Studio 中重新同步项目。" -ForegroundColor Cyan

} catch {
    Write-Host "❌ 回滚失败: $_" -ForegroundColor Red
    exit 1
}
