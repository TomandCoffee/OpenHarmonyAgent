# 华为设备连接指南

## 📱 手机端配置

### Step 1: 开启开发者模式

1. 打开 **设置**
2. 进入 **关于手机**
3. 找到 **版本号**
4. 连续点击 **版本号** 7 次
5. 提示"您已处于开发者模式"

### Step 2: 开启 USB 调试

1. 打开 **设置**
2. 进入 **系统和更新**
3. 进入 **开发人员选项**
4. 开启 **USB 调试** 开关
5. 开启 **仅充电模式下允许 ADB 调试**

### Step 3: USB 连接电脑

1. 使用 USB 数据线连接手机和电脑
2. 手机上弹出"允许 USB 调试"对话框
3. 勾选"始终允许"
4. 点击"确定"

### Step 4: 验证连接

#### 方式一：DevEco Studio
1. 打开 DevEco Studio
2. 顶部工具栏查看设备列表
3. 应显示已连接的设备

#### 方式二：华为手机助手
1. 安装 [华为手机助手](https://consumer.huawei.com/cn/support/hisuite/)
2. 打开华为手机助手
3. 应显示已连接的设备

---

## 🖥️ DevEco Studio 配置

### 安装 DevEco Studio

1. 下载地址：https://developer.harmonyos.com/cn/download
2. 选择 DevEco Studio 4.0+
3. 安装完成后启动

### 配置 SDK

1. File > Settings > SDK
2. 确认 OpenHarmony SDK API 10+ 已安装
3. 如未安装，点击 Download 下载

### 配置签名

1. File > Project Structure
2. SigningConfigs > Create
3. 填写信息：
   ```
   Alias: openharmony_agent
   Password: (设置密码)
   有效期：25 年
   ```
4. 应用到 default product

---

## 🚀 运行应用

### Step 1: 打开项目

```
File > Open > C:\Users\17999\Desktop\创新大赛\OpenHarmonyAgent
```

### Step 2: 选择设备

1. 顶部工具栏点击设备选择器
2. 选择已连接的华为手机
3. 如无设备，点击"Select Multiple Devices"

### Step 3: 运行应用

1. 点击 Run 按钮（绿色三角形）
2. 或按 Shift + F10
3. 等待应用安装启动

### Step 4: 授予权限

应用首次运行需要以下权限：
- 麦克风权限（语音输入）
- 相机/存储权限（图片选择）

在弹出的权限对话框中点击"允许"

---

## 🐛 常见问题

### Q1: 设备未识别

**解决方案：**
1. 重新插拔 USB 数据线
2. 尝试不同 USB 端口
3. 安装华为手机助手
4. 重启手机和电脑

### Q2: USB 调试未授权

**解决方案：**
1. 设置 > 系统和更新 > 开发人员选项
2. 关闭再开启 USB 调试
3. 撤销 USB 调试授权
4. 重新连接 USB 线

### Q3: 应用安装失败

**解决方案：**
1. 检查签名配置是否正确
2. 清理设备缓存
3. 卸载旧版本应用
4. 重新运行应用

### Q4: 应用启动后崩溃

**解决方案：**
1. 查看 DevEco Studio Log 面板
2. 检查权限是否授予
3. 清理应用数据
4. 重新安装应用

---

## 📊 调试记录

### 连接成功标记
- [ ] 设备在 DevEco Studio 中显示
- [ ] 应用成功安装
- [ ] 应用正常启动
- [ ] 权限正常授予

### 性能记录
| 指标 | 目标 | 实际 | 状态 |
|------|------|------|------|
| 冷启动 | ≤3s | 待填写 | ⏳ |
| 内存占用 | <200MB | 待填写 | ⏳ |
| CPU 使用 | <30% | 待填写 | ⏳ |

---

## 📸 截图位置

调试截图请保存到：
```
./debug/screenshots/
```

命名规范：
- `home.png` - 首页
- `voice.png` - 语音输入
- `knowledge.png` - 知识库
- `agents.png` - 智能体

---

## 🔗 相关文档

- [手机调试记录](./MOBILE_DEBUG_LOG.md)
- [调试索引](./DEBUG_INDEX.md)
- [GET_STARTED.md](../GET_STARTED.md)

---

**最后更新：** 2024-01-XX  
**维护人：** Tom1224134426
