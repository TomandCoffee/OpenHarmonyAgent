# 设备连接检查脚本

Write-Host "========================================"
Write-Host "  OpenHarmony Agent - 设备连接检查"
Write-Host "========================================"
Write-Host ""

# 检查 ADB
Write-Host "1. 检查 ADB 连接..." -ForegroundColor Cyan
try {
    $devices = adb devices 2>&1
    Write-Host $devices
    $deviceCount = ($devices | Select-String "device$" -AllMatches).Matches.Count
    Write-Host "   已连接设备数：$deviceCount" -ForegroundColor Green
} catch {
    Write-Host "   ADB 未安装或不可用" -ForegroundColor Red
    Write-Host "   请安装华为手机助手或 ADB 工具" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "2. 检查设备详细信息..." -ForegroundColor Cyan
try {
    $deviceInfo = adb shell getprop 2>&1 | Select-String "ro.build.version.release|ro.product.model|ro.build.version.sdk"
    Write-Host $deviceInfo
} catch {
    Write-Host "   无法获取设备信息" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================"
Write-Host "  下一步操作："
Write-Host "========================================"
Write-Host ""
Write-Host "1. 如果设备未显示，请检查："
Write-Host "   - USB 调试是否开启"
Write-Host "   - USB 线是否支持数据传输"
Write-Host "   - 是否授权了 USB 调试"
Write-Host ""
Write-Host "2. 设备连接正常后，在 DevEco Studio 中："
Write-Host "   - File > Open > 项目目录"
Write-Host "   - 配置签名"
Write-Host "   - 点击 Run 运行"
Write-Host ""
