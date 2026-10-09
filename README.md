# OpenHarmony Agent

<div align="center">

[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)
[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-6.0.0%20(API%2020)-orange)](https://developer.huawei.com/consumer/cn/)

**鸿蒙原生的大模型对话客户端**

流式回答 · 语音输入 · 语音朗读 · 本地知识库

</div>

---

## 适用机型

| 设备形态 | 支持 | 说明 |
|:---|:---:|:---|
| **平板** | ✅ | **已实测** —— HUAWEI MatePad 11.5"S，HarmonyOS 6.x（API 24）。开发与验证全部在真机完成 |
| **手机** | ⚪ | **未实测**。代码里没有平板独有逻辑（单列布局、未使用平板专属 API），理论上可用 |
| **PC / 2in1** | ❌ | **不支持**。`deviceTypes` 未声明，界面也未做 PC 布局适配 |
| 车机 / 手表 / TV | ❌ | 不支持 |

**系统版本要求：HarmonyOS 6.0.0（API 20）及以上。**
由 `build-profile.json5` 的 `compatibleSdkVersion: "6.0.0(20)"` 决定 —— 低于这个版本的设备装不上。

机型声明写在 [`entry/src/main/module.json5`](entry/src/main/module.json5)：

```json5
"deviceTypes": ["phone", "tablet"]
```

### 各功能对设备能力的依赖

| 功能 | 依赖 | 设备不支持时 |
|:---|:---|:---|
| 对话（核心） | 网络 | 无降级 —— 必须有网 |
| 语音输入 | 麦克风 + `SystemCapability.AI.SpeechRecognizer` | 麦克风按钮仍显示，但点了没反应 |
| 语音朗读 | `SystemCapability.AI.TextToSpeech` | 喇叭图标自动隐藏（有 `canIUse()` 守卫） |
| 本地知识库 | 无 | 纯内存关键词索引，不依赖任何系统 AI 能力 |

> **注意**：本项目**没有**使用 `@kit.DataAugmentationKit`。
> `utils/Capability.ets` 里的 `canUseRetrieval()` / `canUseKnowledgeProcessor()` 是能力探测预留，
> 目前没有任何调用方 —— 知识库走的是自己实现的内存索引。原因见下方「为什么不用端侧 RAG」。

---

## 这是什么

一个跑在鸿蒙设备上的大模型对话应用。目标很窄：**把自己平板上用 AI 这件事做顺手**。

- 默认接 **DeepSeek**（`deepseek-flash`），OpenAI 兼容协议
- 回答**流式**渲染 —— 不是等整段生成完才显示
- 系统自带的**语音输入**和**朗读回答**，两者都**支持离线**
- 有**本地知识库**，命中的内容会注入到本轮提问

### 为什么自己做，而不是装个豆包

1. **模型锁死** —— 商业助手只给自家模型，换不了
2. **有推荐流和广告** —— 一个只想问问题的输入框不需要这些
3. **鸿蒙原生这一格是空的** —— 通用 LLM 客户端里 [kelivo](https://github.com/Chevey339/kelivo)（★4000+）是 Flutter 写的，
   鸿蒙原生 ArkTS 的实现基本找不到

技术上还额外拿到两样东西：系统的语音识别和语音播报**都不需要额外权限声明、不需要华为账号、不需要三方 SDK**。

### 为什么不用端侧 RAG

`@kit.DataAugmentationKit` 的四个子模块按设备分层，本机 SDK 的 `device-define/*-hmos.json` 写得很清楚：

| 能力 | 手机 | 平板 | PC / 2in1 |
|:---|:---:|:---:|:---:|
| `rag`（RagSession 问答） | ❌ | ❌ | ✅ |
| `localChatModel`（端侧问答模型） | ❌ | ❌ | ✅ |
| `retrieval`（向量 + 倒排检索） | ✅ | ✅ | ✅ |
| `knowledgeProcessor`（知识加工） | ✅ | ✅ | ✅ |

目标是平板，而平板**拿不到生成式的那两块** —— 端侧只能做检索，回答还得自己接大模型。
所以知识库先用内存索引落地，`retrieval` 的接入留在 TODO 里。

---

## 功能现状

如实标注：

| 功能 | 状态 | 说明 |
|:---|:---:|:---|
| 大模型对话 | ✅ | 真实调用 `deepseek-flash`，SSE 流式渲染 |
| 语音输入 | ✅ | 系统 Core Speech Kit，**离线模式**真机实测可用 |
| 语音朗读 | ✅ | 系统 TTS，可切换音色；部分音色资源未预装，会自动回退默认 |
| 本地知识库 | ⚠️ | 检索真实（2-gram 关键词索引 + 打分），但**重启即失**（[#1](../../issues/1)） |
| 对话持久化 | ❌ | 未实现，杀掉应用对话就没了 |
| 图片输入 | ❌ | 入口存在，链路未打通，会如实告知用户（[#3](../../issues/3)） |
| 跨设备协同 | ❌ | 已移除 |

---

## 技术要点

开发过程中真正花时间的地方，做类似项目的应该用得上。

### 1. SSE 流式：中文会被 TCP 分片切开

`http.requestInStream()` 的 `on('dataReceive')` 给的是 `ArrayBuffer`，**不保证是一个完整事件**。
一个中文字符 3 字节，很容易被切在中间。

```ts
// ❌ 每次 new 一个 decoder —— 被切开的多字节字符会解成乱码
new util.TextDecoder().decodeToString(bytes)

// ✅ 保留状态，跨 chunk 续上
decoder.decodeToString(bytes, { stream: true })
```

另外不能按单个 `\n` 切事件，要**按 `\n\n` 切完整事件**，否则 JSON 被截断解析失败。

### 2. 系统语音识别：全局单例 + 音频块硬约束

- **`speechRecognizer` 是系统服务，全局只允许一个引擎**。服务必须写成单例，否则报 `1002200006 engine is busy`；
  并发初始化会创建双引擎，表现为「界面显示在录音，但一个字都收不到」
- **`writeAudio()` 只接受 640 或 1280 字节的块**，而 `AudioCapturer` 每次返回多少字节不保证 —— 必须自己缓冲对齐
- **引擎按 VAD 自动判定「说完了」并回调**，此时必须立刻停止喂音频，否则持续报 `1002200010` 刷屏
- **离线模式（`online: 1`）反而比在线可用**：真机上在线模式被拒（`1002200001 CreateEngineParams is wrong`），
  离线模式设备预装了语言包，直接能用

### 3. TTS 的 `onComplete` 是「合成完成」，不是「播放完成」

最反直觉的一个。52 个字的文本**合成只要 0.5 秒**，音频**要播 10 秒**（实测合成 331000 字节），
而 `onComplete` 在合成结束时就回调了。

拿它维护「正在播」状态会同时坏三件事：点击停不掉、静音掐不断、播放中途再点会**排到队尾**
（引擎日志 `busyStatus: true, excute in next turn`）而不是立刻重来。

正确做法是不依赖这个状态，**每次 `speak()` 前无条件 `engine.stop()`**。

### 4. TTS 的 requestId 不能重复

引擎拒绝重复的 `requestId`（`40003 "requestId is empty or repeated"`）。分段播报时若代号不推进，
第二次点击会发出和第一轮完全相同的 `requestId` —— 表现为**「第一遍能念，之后再点就没声音」**。

### 5. 语言指令要放在本轮 user 消息末尾

把「Always answer in English」放 system prompt 里，只要对话历史是中文就会被压过去，**实测不生效**。
放到当前这条 user 消息的末尾才稳定生效。

### 6. 音色列表会列出「资源未下载」的音色

`listVoices()` 返回引擎**支持**的音色，不是本机**可用**的音色。选中未下载资源的音色，
`createEngine` 直接失败（`1002300005`，底层报 `Invalid relative path`），朗读彻底不能用。
必须做回退：建不起来就退回默认音色，并记住失败过的音色避免重试。（详见 [#9](../../issues/9)）

---

## 项目结构

```
entry/src/main/ets/
├── entryability/          # 应用入口
├── pages/
│   ├── Index.ets          # 对话主界面
│   ├── KnowledgeBase.ets  # 知识库
│   └── Settings.ets       # 设置（API Key / 语言 / 音色）
├── components/
│   ├── ChatBubble.ets     # 消息气泡（含朗读按钮）
│   ├── VoiceInput.ets     # 语音输入
│   └── TextInput.ets      # 输入框
├── services/
│   ├── LLMService.ets     # 模型调用 + SSE 流式解析
│   ├── ChatEngine.ets     # 拼 prompt → 调模型 → 返回
│   ├── Prompts.ets        # system prompt 与上下文构建
│   ├── TTSService.ets     # 语音朗读
│   ├── VoiceService.ets   # 语音识别
│   ├── RAGService.ets     # 本地知识库（内存索引）
│   ├── SettingsStore.ets  # 偏好持久化
│   └── ApiKeyStore.ets    # API Key 持久化
├── models/                # 数据模型
└── utils/
    ├── Capability.ets     # 运行时能力探测
    └── TextFormat.ets     # Markdown 剥离
```

全部代码约 4600 行 ArkTS，**零三方依赖** —— 只用系统 kit。

---

## 构建与运行

### 环境

- DevEco Studio 6.x，自带 SDK **API 24**
- 一台 HarmonyOS 6.0.0（API 20）及以上的设备

### 签名（必需，且有个坑）

1. 用数据线连上设备
2. DevEco → `File > Project Structure > Signing Configs` → 勾选 `Automatically generate signature`
3. **手动**在 `build-profile.json5` 的 `products` 里加一行 `"signingConfig": "default"`

> ⚠️ 第 3 步 DevEco **不会自动做**。不加的话构建产物仍然是 unsigned，装不上设备。

### 命令行构建

```bash
export DEVECO_SDK_HOME="<你的 DevEco SDK 路径>"
hvigorw assembleHap --no-daemon

hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc shell aa start -a EntryAbility -b com.example.openharmonyagent
```

### 配置模型

打开应用 → 右上角 ⚙️ → 填入 DeepSeek API Key。

API Key 存在 `preferences` 里，**不进代码、不进仓库**。

---

## 已知问题

未解决的问题都在 [Issues](../../issues) 里，共 9 条，包括：知识库不持久化、对话不持久化、
图片链路未打通、界面文案未国际化、部分文档与实现不一致等。

它们是**已知问题的记录，不是待办清单** —— 这个项目的目标范围很窄，不打算做大而全。

---

## 参赛信息

| 项目 | 信息 |
|:---|:---|
| 比赛名称 | 中国国际大学生创新大赛 |
| 命题企业 | 华为技术有限公司 |
| 命题组别 | 国产操作系统软件组 |

---

## 开源协议

[MIT License](LICENSE)

## 联系方式

- GitHub: [@TomandCoffee](https://github.com/TomandCoffee)
- 仓库：https://github.com/TomandCoffee/OpenHarmonyAgent

---

<div align="center">

**如果这个项目对你有帮助，请给一个 ⭐️ Star！**

</div>
