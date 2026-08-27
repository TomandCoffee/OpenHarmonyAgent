# GitHub 仓库推送指南

## ✅ 已完成
- [x] Git 仓库初始化
- [x] 首次提交（45 个文件，5512 行代码）
- [x] .gitignore 配置

## 🚀 推送到 GitHub

### 方式一：使用命令行（推荐）

#### 1. 创建 GitHub 仓库
访问：https://github.com/new
- Repository name: `OpenHarmonyAgent`
- Description: `OpenHarmony Agent - 鸿蒙原生智能多模态个人助理`
- Public/Private: 根据需求选择
- **不要** 勾选 "Initialize this repository with a README"

#### 2. 关联远程仓库
```bash
cd C:\Users\17999\Desktop\创新大赛\OpenHarmonyAgent

# 添加远程仓库（替换为你的仓库地址）
git remote add origin https://github.com/Tom1224134426/OpenHarmonyAgent.git

# 验证远程仓库
git remote -v

# 推送到 GitHub
git push -u origin master
```

#### 3. 如果提示需要认证
- 使用 GitHub Personal Access Token
- 创建 Token: https://github.com/settings/tokens
- 权限：`repo` (Full control of private repositories)
- 使用 Token 代替密码

### 方式二：使用 DevEco Studio

1. File > Settings > Version Control > GitHub
2. 添加 GitHub 账号（使用 Token）
3. Git > Remotes > 添加远程仓库
4. Git > Push (Ctrl+Shift+K)

## 🔐 生成 Personal Access Token

1. 访问 https://github.com/settings/tokens
2. 点击 "Generate new token (classic)"
3. 填写 Note: `OpenHarmonyAgent`
4. 选择权限:
   - ✅ `repo` (全选)
   - ✅ `workflow` (可选)
5. 点击 "Generate token"
6. **复制并保存 Token**（只显示一次）

## 📝 后续 Git 操作

### 日常提交
```bash
# 查看修改
git status

# 添加文件
git add .

# 提交
git commit -m "feat: 添加新功能"

# 推送
git push
```

### 常用 Commit 消息格式
```
feat: 新功能
fix: 修复 bug
docs: 文档更新
style: 代码格式
refactor: 重构
test: 测试
chore: 构建/工具
```

### 分支管理
```bash
# 创建新分支
git checkout -b feature/rag-optimization

# 切换分支
git checkout master

# 合并分支
git merge feature/rag-optimization

# 删除分支
git branch -d feature/rag-optimization
```

## 📊 仓库统计

当前提交：
- Commit: `805eb72`
- 文件数：45
- 代码行数：5512

## ⚠️ 注意事项

### 敏感信息
**不要提交以下内容：**
- 签名文件（.p7b, .cer）
- 密码和密钥
- 个人账号信息
- .env 文件

### 大文件
如果文件超过 100MB，需要使用 Git LFS：
```bash
git lfs install
git lfs track "*.bin"
```

### 冲突解决
```bash
# 拉取最新代码
git pull origin master

# 如果有冲突，手动解决后
git add <resolved-files>
git commit -m "merge: 解决冲突"
git push
```

## 🎯 下一步

1. [ ] 在 GitHub 创建仓库
2. [ ] 推送代码到 GitHub
3. [ ] 配置 GitHub Pages（可选）
4. [ ] 添加 CI/CD（可选）
5. [ ] 邀请团队成员

## 📞 需要帮助？

遇到问题可以：
1. 查看 Git 错误信息
2. 检查网络连接
3. 验证 Token 权限
4. 联系技术支持

---

**仓库创建完成后，记得更新 README.md 中的仓库链接！**
