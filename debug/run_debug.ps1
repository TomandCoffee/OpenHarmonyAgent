# OpenHarmony Agent 调试自动化脚本

Write-Host "========================================"
Write-Host "  OpenHarmony Agent - 调试助手"
Write-Host "========================================"
Write-Host ""

# 检查项目路径
$projectPath = "D:\OpenHarmonyAgent"
Write-Host "项目路径：$projectPath" -ForegroundColor Cyan

if (!(Test-Path $projectPath)) {
    Write-Host "❌ 项目路径不存在！" -ForegroundColor Red
    exit 1
}

Write-Host "✅ 项目路径存在" -ForegroundColor Green
Write-Host ""

# 检查 Git 状态
Write-Host "检查 Git 状态..." -ForegroundColor Cyan
cd $projectPath
git status --short

Write-Host ""
Write-Host "========================================"
Write-Host "  下一步操作指南"
Write-Host "========================================"
Write-Host ""

Write-Host "1️⃣ 在 DevEco Studio 中：" -ForegroundColor Yellow
Write-Host "   File > Project Structure > SigningConfigs"
Write-Host "   点击 + 号创建签名证书"
Write-Host ""
Write-Host "   Certificate 信息："
Write-Host "   Alias: openharmony_agent"
Write-Host "   Password: (设置一个密码并记住)"
Write-Host "   Validity: 25 年"
Write-Host ""

Write-Host "2️⃣ 应用签名配置：" -ForegroundColor Yellow
Write-Host "   Products > default"
Write-Host "   Signing Config: 选择 openharmony_agent"
Write-Host "   Apply > OK"
Write-Host ""

Write-Host "3️⃣ 连接手机：" -ForegroundColor Yellow
Write-Host "   USB 连接华为手机"
Write-Host "   确保 USB 调试已开启"
Write-Host "   手机上授权 USB 调试"
Write-Host ""

Write-Host "4️⃣ 运行应用：" -ForegroundColor Yellow
Write-Host "   顶部工具栏选择设备"
Write-Host "   点击 Run 按钮 (绿色三角形)"
Write-Host "   等待编译安装 (首次 2-5 分钟)"
Write-Host ""

Write-Host "========================================"
Write-Host "  调试检查清单"
Write-Host "========================================"
Write-Host ""

$checklist = @(
    "应用正常启动",
    "首页聊天界面显示",
    "文本输入可用",
    "语音按钮响应",
    "图片选择可用",
    "知识库页面跳转",
    "智能体页面跳转",
    "设置页面跳转"
)

for ($i = 0; $i -lt $checklist.Count; $i++) {
    $num = $i + 1
    Write-Host "[$num] $($checklist[$i])" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================"
Write-Host "  截图保存位置"
Write-Host "========================================"
Write-Host ""
Write-Host "$projectPath\debug\screenshots\" -ForegroundColor Cyan
Write-Host ""
Write-Host "必截图片：" -ForegroundColor Yellow
Write-Host "  - home_first_run.png (首页首次运行)"
Write-Host "  - voice_input.png (语音输入)"
Write-Host "  - knowledge_base.png (知识库)"
Write-Host "  - agents.png (智能体)"
Write-Host ""

Write-Host "========================================"
Write-Host "  完成后执行"
Write-Host "========================================"
Write-Host ""
Write-Host "1. 更新调试记录：" -ForegroundColor Yellow
Write-Host "   编辑 debug/MOBILE_DEBUG_LOG.md"
Write-Host "   填写设备信息和测试结果"
Write-Host ""
Write-Host "2. 提交到 Git：" -ForegroundColor Yellow
Write-Host "   git add debug/screenshots/"
Write-Host "   git commit -m 'test: 添加手机调试记录'"
Write-Host "   git push"
Write-Host ""

Write-Host "========================================"
Write-Host ""
