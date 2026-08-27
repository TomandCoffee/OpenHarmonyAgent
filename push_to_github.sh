#!/bin/bash
# OpenHarmony Agent - GitHub 推送脚本
# 使用方法：在 Git Bash 中运行 ./push_to_github.sh

echo "========================================"
echo "  OpenHarmony Agent - GitHub 推送"
echo "========================================"
echo ""

# 配置仓库地址
REPO_URL="https://github.com/Tom1224134426/OpenHarmonyAgent.git"

echo "1. 请在 GitHub 上创建仓库："
echo "   访问：https://github.com/new"
echo "   Repository name: OpenHarmonyAgent"
echo "   不要勾选 'Initialize this repository with a README'"
echo ""

read -p "2. 仓库创建完成后，按回车继续..."

echo ""
echo "3. 添加远程仓库..."
git remote add origin $REPO_URL

if [ $? -ne 0 ]; then
    echo "   远程仓库已存在，更新 URL..."
    git remote set-url origin $REPO_URL
fi

echo ""
echo "4. 验证远程仓库..."
git remote -v

echo ""
echo "5. 推送到 GitHub..."
echo "   如果需要认证，请使用 GitHub Personal Access Token"
echo "   创建 Token: https://github.com/settings/tokens"
echo ""

git push -u origin master

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "  ✅ 推送成功！"
    echo "========================================"
    echo ""
    echo "仓库地址：https://github.com/Tom1224134426/OpenHarmonyAgent"
    echo ""
    echo "下一步："
    echo "1. 访问仓库页面查看代码"
    echo "2. 更新 README.md 中的仓库链接"
    echo "3. 邀请团队成员（如需要）"
    echo ""
else
    echo ""
    echo "========================================"
    echo "  ❌ 推送失败"
    echo "========================================"
    echo ""
    echo "可能的原因："
    echo "1. 仓库未创建"
    echo "2. 认证失败（需要使用 Token）"
    echo "3. 网络连接问题"
    echo ""
    echo "请查看 GITHUB_SETUP.md 获取详细帮助"
    echo ""
fi
