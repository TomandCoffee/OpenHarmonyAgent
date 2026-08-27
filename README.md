# OpenHarmony Agent - 鸿蒙原生智能多模态个人助理

<div align="center">

[![GitHub stars](https://img.shields.io/badge/GitHub-OpenHarmonyAgent-blue?logo=github)](https://github.com/Tom1224134426/OpenHarmonyAgent)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)
[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-API%2010+-orange)](https://developer.harmonyos.com/)

🤖 基于鸿蒙原生智能的多模态个人助理 | AI 时代的人机交互新范式

[项目文档](./GET_STARTED.md) • [架构设计](./ARCHITECTURE.md) • [演示脚本](./DEMO_SCRIPT.md)

</div>

---

## 项目概述

OpenHarmony Agent 是一款基于鸿蒙原生智能的多模态个人助理应用，深度集成 AI 能力到操作系统层面，提供语音、文本、图像三种交互方式，支持端侧 RAG 知识库和跨设备协同。

## 核心功能

### 1. 多模态交互
- **语音输入**: 支持语音指令识别和响应
- **文本输入**: 自然语言文本交互
- **图像输入**: 拍照/上传图片进行智能分析
- **复合指令**: 支持"拍一下这个文档，帮我总结重点"等复合指令

### 2. 端侧 RAG 知识库
- 本地构建个人知识库（课程笔记、文献资料、会议纪要）
- 离线语义检索和问答
- 使用鸿蒙 @kit.DataAugmentationKit 的 RAG API

### 3. 跨设备协同
- 手机、平板、PC 间无缝流转任务和上下文
- 分布式软总线实现多设备协同

### 4. AI 智能体编排
- **学习助手**: 帮助整理学习资料、解答问题
- **日程管家**: 管理日程安排、提醒事项
- **文档处理**: 文档总结、提取重点、格式转换

## 技术架构

```
┌─────────────────────────────────────────────────────────────┐
│                      UI Layer (ArkUI)                        │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐  │
│  │   首页      │   知识库    │   智能体    │   设置      │  │
│  └─────────────┴─────────────┴─────────────┴─────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                   Agent Orchestration Layer                  │
│  ┌─────────────┬─────────────┬─────────────┐                 │
│  │ 学习助手    │  日程管家   │  文档处理   │                 │
│  └─────────────┴─────────────┴─────────────┘                 │
├─────────────────────────────────────────────────────────────┤
│                    Multimodal Input Layer                    │
│  ┌─────────────┬─────────────┬─────────────┐                 │
│  │  语音识别   │  文本处理   │  图像分析   │                 │
│  └─────────────┴─────────────┴─────────────┘                 │
├─────────────────────────────────────────────────────────────┤
│                      RAG Knowledge Layer                     │
│  ┌─────────────────────────────────────────────────────┐    │
│  │           DataAugmentationKit (RAG API)              │    │
│  │     向量存储 │ 语义检索 │ 知识更新 │ 离线问答       │    │
│  └─────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────┤
│                   Distributed Capability Layer               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │         分布式软总线 │ 跨设备任务流转 │ 上下文同步   │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## 项目结构

```
OpenHarmonyAgent/
├── entry/                          # 主应用模块
│   ├── src/main/
│   │   ├── ets/
│   │   │   ├── entryability/       # 应用入口
│   │   │   ├── pages/              # 页面
│   │   │   │   ├── Index.ets       # 首页
│   │   │   │   ├── KnowledgeBase.ets  # 知识库页面
│   │   │   │   ├── Agents.ets      # 智能体页面
│   │   │   │   └── Settings.ets    # 设置页面
│   │   │   ├── components/         # 公共组件
│   │   │   │   ├── VoiceInput.ets  # 语音输入组件
│   │   │   │   ├── TextInput.ets   # 文本输入组件
│   │   │   │   ├── ImageInput.ets  # 图像输入组件
│   │   │   │   └── ChatBubble.ets  # 对话气泡组件
│   │   │   ├── services/           # 服务层
│   │   │   │   ├── AgentService.ets    # 智能体服务
│   │   │   │   ├── RAGService.ets      # RAG 服务
│   │   │   │   ├── VoiceService.ets    # 语音服务
│   │   │   │   ├── ImageService.ets    # 图像服务
│   │   │   │   └── DistributeService.ets # 分布式服务
│   │   │   ├── models/             # 数据模型
│   │   │   │   ├── Message.ets     # 消息模型
│   │   │   │   ├── Agent.ets       # 智能体模型
│   │   │   │   └── Knowledge.ets   # 知识模型
│   │   │   └── utils/              # 工具类
│   │   │       ├── Logger.ets      # 日志工具
│   │   │       └── Constants.ets   # 常量定义
│   │   ├── resources/              # 资源文件
│   │   └── module.json5            # 模块配置
│   └── build-profile.json5
├── common/                         # 公共模块
│   └── src/main/ets/
├── build-profile.json5             # 构建配置
├── hvigorfile.ts                   # 构建脚本
└── README.md                       # 项目说明
```

## 性能指标

| 指标 | 目标 | 实现方案 |
|------|------|----------|
| 冷启动时间 | ≤3s | 懒加载、预加载关键资源 |
| 语音响应时延 | ≤2s | 端侧语音识别、流式处理 |
| 知识库检索 | <500ms | 向量索引、缓存优化 |
| 跨设备同步 | <1s | 分布式软总线直连 |

## 开发环境要求

- DevEco Studio 4.0+
- OpenHarmony SDK API 10+
- Node.js 16+
- 鸿蒙设备（手机/平板）或模拟器

## 快速开始

### 📥 获取代码
```bash
git clone https://github.com/Tom1224134426/OpenHarmonyAgent.git
cd OpenHarmonyAgent
```

### 🚀 运行应用
1. 使用 DevEco Studio 4.0+ 打开项目
2. File > Project Structure > 配置签名信息
3. 连接鸿蒙设备（手机/平板）或启动模拟器
4. 点击 Run 运行应用

### 📚 查看更多
- 📘 [快速启动指南](./GET_STARTED.md)
- 🏗️ [架构设计文档](./ARCHITECTURE.md)
- 📱 [设备连接指南](./DEVICE_GUIDE.md)
- 🎬 [演示脚本](./DEMO_SCRIPT.md)

## 参考资料

- [鸿蒙 Data Augmentation Kit](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/dataaugmentation-introduction)
- [openJiuwen 智能体平台](https://openjiuwen.com/)
- [鸿蒙开发者文档](https://developer.huawei.com/consumer/cn/doc/)

## 参赛信息

| 项目 | 信息 |
|------|------|
| 比赛名称 | **中国国际大学生创新大赛** |
| 英文名称 | China International College Students' Innovation Competition |
| 命题企业 | 华为技术有限公司 |
| 命题组别 | 国产操作系统软件组 |
| GitHub | [Tom1224134426/OpenHarmonyAgent](https://github.com/Tom1224134426/OpenHarmonyAgent) |

## 开源协议

本项目采用 [MIT License](LICENSE) 协议开源。

## 贡献指南

欢迎提交 Issue 和 Pull Request！

## 联系方式

- GitHub: [@Tom1224134426](https://github.com/Tom1224134426)
- 仓库：https://github.com/Tom1224134426/OpenHarmonyAgent

---

<div align="center">

**如果这个项目对你有帮助，请给一个 ⭐️ Star！**

[OpenHarmony Agent](https://github.com/Tom1224134426/OpenHarmonyAgent) © 2024

</div>
