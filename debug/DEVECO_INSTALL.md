# DevEco Studio 下载安装指南

## ⚠️ 当前状态

**检测结果：** 电脑上未安装 DevEco Studio

**需要操作：** 下载并安装 DevEco Studio 4.0+

---

## 📥 下载地址

### 官方网站（推荐）
访问：https://developer.harmonyos.com/cn/download

### 直接链接
- **DevEco Studio 4.0+**: https://developer.harmonyos.com/cn/download
- 选择对应操作系统的版本（Windows/Mac）

---

## 💻 系统要求

### Windows
- 操作系统：Windows 10/11 (64 位)
- 内存：≥8GB（推荐 16GB）
- 硬盘：≥10GB 可用空间
- 分辨率：≥1920×1080

### macOS
- 操作系统：macOS 10.15+
- 内存：≥8GB（推荐 16GB）
- 硬盘：≥10GB 可用空间

---

## 🚀 安装步骤

### Step 1: 下载安装包

1. 访问 https://developer.harmonyos.com/cn/download
2. 选择 **DevEco Studio**
3. 点击 **Download** 下载 Windows 版本
4. 等待下载完成（约 1-2GB）

### Step 2: 安装 DevEco Studio

1. 双击下载的安装包（`.exe` 文件）
2. 点击 **Next**
3. 选择安装路径（建议默认）
   ```
   C:\Program Files\DevEco Studio\
   ```
4. 选择开始菜单文件夹
5. 点击 **Install** 开始安装
6. 等待安装完成（约 5-10 分钟）
7. 点击 **Finish**

### Step 3: 首次启动配置

1. 双击桌面 **DevEco Studio** 图标
2. 接受许可协议
3. 选择是否导入设置（首次选择 **Do not import settings**）
4. 点击 **Next**

### Step 4: 安装 SDK

1. DevEco Studio 会自动检测或提示安装 SDK
2. 选择 **OpenHarmony SDK**
3. 选择 API 版本（选择 **API 10+**）
4. 选择 SDK 安装路径（建议默认）
   ```
   C:\Users\你的用户名\AppData\Local\OpenHarmony\Sdk\
   ```
5. 点击 **Next** 开始下载和安装
6. 等待 SDK 下载完成（约 10-30 分钟，取决于网络）

### Step 5: 完成配置

1. SDK 安装完成后点击 **Finish**
2. DevEco Studio 启动
3. 关闭欢迎界面

---

## ✅ 验证安装

### 方法一：启动应用

1. 双击桌面 **DevEco Studio** 图标
2. 应用正常启动即安装成功

### 方法二：检查版本

1. Help > About
2. 查看版本号（应 ≥4.0）

### 方法三：检查 SDK

1. File > Settings > SDK
2. 查看 OpenHarmony SDK 是否已安装
3. 确认 API 版本 ≥10

---

## 🔧 常见问题

### Q1: 下载速度慢？

**解决方案：**
- 使用有线网络连接
- 选择网络较好的时段下载
- 使用下载工具（如迅雷）

### Q2: 安装失败？

**解决方案：**
- 关闭杀毒软件
- 确保有足够的磁盘空间
- 以管理员身份运行安装程序

### Q3: SDK 下载失败？

**解决方案：**
- 检查网络连接
- 在 Settings > SDK 中重新下载
- 手动下载 SDK 包并导入

### Q4: 启动闪退？

**解决方案：**
- 检查内存是否足够（≥8GB）
- 调整 JVM 内存设置
- 重新安装 DevEco Studio

---

## 📊 安装时间估算

| 步骤 | 预计时间 |
|------|----------|
| 下载 DevEco Studio | 10-30 分钟 |
| 安装 DevEco Studio | 5-10 分钟 |
| 下载 SDK | 10-30 分钟 |
| 配置 SDK | 5-10 分钟 |
| **总计** | **30-80 分钟** |

---

## 🎯 安装完成后

安装完成后，继续以下步骤：

### 1. 打开项目
```
File > Open > C:\Users\17999\Desktop\创新大赛\OpenHarmonyAgent
```

### 2. 配置签名
```
File > Project Structure > SigningConfigs > Create
```

### 3. 连接设备
```
USB 连接华为手机
确保 USB 调试已开启
```

### 4. 运行应用
```
点击 Run 按钮（绿色三角形）
```

---

## 📞 需要帮助？

### 官方文档
- [DevEco Studio 用户指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/deveco-studio-guide-0000001066966088-V5)
- [鸿蒙开发者论坛](https://developer.huawei.com/consumer/cn/forum/)

### 本项目文档
- [设备连接指南](./DEVICE_CONNECTION.md)
- [快速开始](./QUICK_START.md)

---

## ⏱️ 时间规划

**如果现在下载安装：**
- 预计完成时间：约 1 小时后
- 建议：开始下载后可以先做其他事情

**如果已有安装包：**
- 直接安装，约 15 分钟完成

---

**准备好了吗？开始下载安装吧！** 🚀

---

*最后更新：2024-01-XX*
