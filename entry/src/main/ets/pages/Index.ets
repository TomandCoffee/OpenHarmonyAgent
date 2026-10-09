import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { VoiceInput } from '../components/VoiceInput';
import { ChatTextInput } from '../components/TextInput';
import { ChatBubble } from '../components/ChatBubble';
import { Message, MessageType } from '../models/Message';
import { chat, ChatReply } from '../services/ChatEngine';
import { RAGService } from '../services/RAGService';
import { TTSService } from '../services/TTSService';

const TAG = 'Index';

/** 流式渲染的合并窗口：每 50ms 才真正写一次 @Observed 对象，避免每个 token 都触发重绘 */
const FLUSH_INTERVAL_MS = 50;

@Entry
@Component
struct Index {
  @State messages: Message[] = [];
  @State isProcessing: boolean = false;
  @State currentInput: string = '';
  @State selectedImage: string = '';
  @State showInputMethods: boolean = false;
  /** 语音识别过程中的实时文字 */
  @State voicePartial: string = '';
  /** 是否正在朗读回答 */
  @State isSpeaking: boolean = false;

  private ragService: RAGService = RAGService.getInstance();
  private listScroller: Scroller = new Scroller();

  /** TTS 状态监听：用于显示全局的「停止朗读」条 */
  private ttsListener = (speaking: boolean, tag: string): void => {
    this.isSpeaking = speaking;
  };

  // 流式渲染的中间状态（刻意不用 @State —— 攒够一批再一次性触发重绘）
  private streamTarget: Message | null = null;
  private pendingDelta: string = '';
  private flushTimerId: number = -1;
  private lastFlushAt: number = 0;

  aboutToAppear(): void {
    hilog.info(0x0000, TAG, 'Index aboutToAppear');
    this.ragService.initialize();
    TTSService.getInstance().addStateListener(this.ttsListener);

    this.messages.push(new Message(
      'welcome',
      MessageType.AGENT,
      '你好，我是你的 AI 助手。\n\n直接输入问题，或长按右下角麦克风说话；回答右下角的喇叭可以把内容念出来。',
      Date.now()
    ));
  }

  aboutToDisappear(): void {
    if (this.flushTimerId !== -1) {
      clearTimeout(this.flushTimerId);
      this.flushTimerId = -1;
    }
    TTSService.getInstance().removeStateListener(this.ttsListener);
  }

  build() {
    Column() {
      // 顶部标题栏
      this.Header()

      // 消息列表
      this.MessageList()

      // 输入区域
      this.InputArea()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  Header() {
    Row() {
      Text('OpenHarmony Agent')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')

      Blank()

      // 知识库入口
      Button() {
        Image($r('sys.media.ohos_ic_public_search_filled'))
          .width(24)
          .height(24)
          .fillColor('#666666')
      }
      .type(ButtonType.Circle)
      .backgroundColor('transparent')
      .onClick(() => {
        router.pushUrl({ url: 'pages/KnowledgeBase' });
      })
      .margin({ right: 12 })

      // 新对话（清空当前上下文）
      Button() {
        Image($r('sys.media.ohos_ic_public_add'))
          .width(24)
          .height(24)
          .fillColor('#666666')
      }
      .type(ButtonType.Circle)
      .backgroundColor('transparent')
      .onClick(() => {
        this.startNewChat();
      })
      .margin({ right: 12 })

      // 设置入口（模型 API Key 在这里配）
      Button() {
        Image($r('app.media.ic_settings'))
          .width(22)
          .height(22)
      }
      .type(ButtonType.Circle)
      .backgroundColor('transparent')
      .onClick(() => {
        router.pushUrl({ url: 'pages/Settings' });
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .shadow({ radius: 2, color: '#10000000', offsetY: 1 })
  }

  @Builder
  MessageList() {
    Scroll(this.listScroller) {
      Column() {
        if (this.messages.length === 0) {
          this.EmptyState()
        } else {
          ForEach(this.messages, (message: Message) => {
            ChatBubble({ message: message })
          }, (message: Message) => message.id)
        }
      }
      .width('100%')
      .padding(12)
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  /**
   * 空会话的引导态
   */
  @Builder
  EmptyState() {
    Column() {
      Text('💬')
        .fontSize(56)
        .margin({ bottom: 20 })

      Text('开始一段新对话')
        .fontSize(16)
        .fontColor('#333333')

      Text('直接输入问题，或长按右下角麦克风说话')
        .fontSize(13)
        .fontColor('#999999')
        .margin({ top: 10 })
    }
    .width('100%')
    .padding({ top: 140, bottom: 60 })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  InputArea() {
    Column() {
      // 图片预览
      if (this.selectedImage) {
        this.ImagePreview()
      }

      // 语音识别中的实时文字
      if (this.voicePartial.length > 0) {
        Row() {
          Text(this.voicePartial)
            .fontSize(15)
            .fontColor('#007DFF')
            .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor('#E6F4FF')
      }

      // 朗读控制条
      //
      // 每条消息右下角虽然有个小喇叭，但要停下来得先找到那条消息，
      // 长回答播报时很别扭 —— 所以这里给一个始终可见的全局停止入口。
      if (this.isSpeaking) {
        Row() {
          Image($r('sys.media.ohos_ic_public_sound'))
            .width(18)
            .height(18)
            .fillColor('#007DFF')

          Text('正在朗读回答')
            .fontSize(14)
            .fontColor('#007DFF')
            .margin({ left: 8 })

          Blank()

          Button() {
            Row() {
              Image($r('sys.media.ohos_ic_public_pause'))
                .width(16)
                .height(16)
                .fillColor('#007DFF')

              Text('停止')
                .fontSize(13)
                .fontColor('#007DFF')
                .margin({ left: 6 })
            }
          }
          .backgroundColor('transparent')
          .padding({ left: 12, right: 8, top: 4, bottom: 4 })
          .onClick(() => {
            TTSService.getInstance().stop();
          })
        }
        .width('100%')
        .padding({ left: 16, right: 8, top: 8, bottom: 8 })
        .backgroundColor('#E6F4FF')
      }

      // 输入方法选择
      if (this.showInputMethods) {
        this.InputMethodSelector()
      }

      // 主输入栏
      Row() {
        // 更多选项按钮
        Button() {
          Image($r('sys.media.ohos_ic_public_add'))
            .width(24)
            .height(24)
            .fillColor('#666666')
        }
        .type(ButtonType.Circle)
        .backgroundColor('transparent')
        .onClick(() => {
          this.showInputMethods = !this.showInputMethods;
        })

        // 文本输入框
        ChatTextInput({
          placeholder: '输入消息...',
          text: this.currentInput,
          onChange: (value: string) => {
            this.currentInput = value;
          }
        })
          .layoutWeight(1)
          .margin({ left: 8, right: 8 })

        // 语音输入按钮
        VoiceInput({
          onResult: (text: string) => {
            this.currentInput = text;
            this.sendMessage();
          },
          onPartialText: (text: string) => {
            this.voicePartial = text;
          }
        })

        // 发送按钮
        if (this.currentInput || this.selectedImage) {
          Button() {
            Image($r('sys.media.ohos_ic_public_arrow_right'))
              .width(24)
              .height(24)
              .fillColor('#FFFFFF')
          }
          .type(ButtonType.Circle)
          .backgroundColor('#007DFF')
          .enabled(!this.isProcessing)
          .onClick(() => {
            this.sendMessage();
          })
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor('#FFFFFF')
      .shadow({ radius: 4, color: '#10000000', offsetY: -2 })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  ImagePreview() {
    Row() {
      Image(this.selectedImage)
        .width(80)
        .height(80)
        .objectFit(ImageFit.Cover)
        .borderRadius(8)
        .margin({ right: 8 })

      Button() {
        Image($r('sys.media.ohos_ic_public_remove'))
          .width(20)
          .height(20)
          .fillColor('#FFFFFF')
      }
      .type(ButtonType.Circle)
      .backgroundColor('#FF4D4F')
      .width(32)
      .height(32)
      .onClick(() => {
        this.selectedImage = '';
      })
    }
    .width('100%')
    .padding(8)
    .backgroundColor('#F5F5F5')
  }

  @Builder
  InputMethodSelector() {
    Row() {
      // 语音输入
      Column() {
        Button() {
          Image($r('sys.media.ohos_ic_public_voice'))
            .width(32)
            .height(32)
            .fillColor('#007DFF')
        }
        .type(ButtonType.Circle)
        .backgroundColor('#E6F4FF')
        .width(56)
        .height(56)
        .onClick(() => {
          this.showInputMethods = false;
          // 触发语音输入
        })

        Text('语音')
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 4 })
      }
      .width(72)

      // 图片输入
      Column() {
        Button() {
          Image($r('sys.media.ohos_ic_public_albums'))
            .width(32)
            .height(32)
            .fillColor('#52C41A')
        }
        .type(ButtonType.Circle)
        .backgroundColor('#E6F7E6')
        .width(56)
        .height(56)
        .onClick(() => {
          this.showInputMethods = false;
          this.selectImage();
        })

        Text('图片')
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 4 })
      }
      .width(72)

      // 文档输入
      Column() {
        Button() {
          Image($r('sys.media.ohos_ic_public_text'))
            .width(32)
            .height(32)
            .fillColor('#722ED1')
        }
        .type(ButtonType.Circle)
        .backgroundColor('#F3E5F5')
        .width(56)
        .height(56)
        .onClick(() => {
          this.showInputMethods = false;
          this.selectDocument();
        })

        Text('文档')
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 4 })
      }
      .width(72)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor('#FAFAFA')
    .justifyContent(FlexAlign.SpaceAround)
  }

  /**
   * 发送消息（流式渲染）
   */
  private async sendMessage(): Promise<void> {
    if (this.currentInput.length === 0 && this.selectedImage.length === 0) {
      return;
    }
    if (this.isProcessing) {
      return;
    }
    this.isProcessing = true;

    const inputText: string = this.currentInput;
    const inputImage: string = this.selectedImage;

    // 历史快照必须在 push 本轮消息之前取，否则会把刚加的用户消息重复传一遍
    const history: Message[] = this.messages.slice();

    this.messages.push(new Message(
      `user_${Date.now()}`,
      MessageType.USER,
      inputText,
      Date.now(),
      inputImage.length > 0 ? inputImage : undefined
    ));

    this.currentInput = '';
    this.selectedImage = '';

    // 先放一个空气泡占位，流式的增量往它身上填
    const placeholder: Message = new Message(
      `agent_${Date.now()}`,
      MessageType.AGENT,
      '',
      Date.now()
    );
    placeholder.isStreaming = true;
    this.messages.push(placeholder);

    this.streamTarget = placeholder;
    this.pendingDelta = '';
    this.lastFlushAt = 0;
    this.scrollToBottom();

    try {
      // 先查本地知识库（纯本地字符串匹配，微秒级），命中的内容会注入到本轮提问
      const hit = await this.ragService.retrieve(inputText, 3);

      const reply: ChatReply = await chat({
        text: inputText,
        imageUrl: inputImage.length > 0 ? inputImage : undefined,
        context: history,
        knowledge: hit,
        onDelta: (delta: string) => {
          this.onStreamDelta(delta);
        }
      });

      // 收尾：把攒着的尾巴刷出去，再用权威全文覆盖一次（顺带补上可能的差异）
      this.finishStream();
      placeholder.content = reply.content;
      placeholder.isStreaming = false;

      if (reply.remember) {
        // 存「问 + 答摘要」而不是只存问题 —— 只存问题的话，检索出来是一条
        // 没有信息量的疑问句，拼进 prompt 反而干扰模型
        let answer: string = reply.content.trim();
        if (answer.length > 300) {
          answer = answer.substring(0, 300);
        }
        await this.ragService.addKnowledge({
          id: `kb_${Date.now()}`,
          content: `问：${inputText}\n答：${answer}`,
          type: '对话',
          tags: ['对话'],
          timestamp: Date.now()
        });
      }
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'sendMessage failed: %{public}s', err.message);
      this.finishStream();
      // 标成 SYSTEM：buildHistory 会把它过滤掉，不会作为历史喂给模型
      placeholder.type = MessageType.SYSTEM;
      placeholder.content = `⚠️ 处理请求时出错了：${err.message}`;
      placeholder.isStreaming = false;
    } finally {
      this.streamTarget = null;
      this.isProcessing = false;
      this.scrollToBottom();
    }
  }

  /**
   * 开一段新对话：清空消息与上下文。
   * 已经沉淀进本地知识库的内容不受影响。
   */
  private startNewChat(): void {
    if (this.isProcessing) {
      return;
    }
    this.finishStream();
    this.streamTarget = null;
    this.messages = [];
    this.currentInput = '';
    this.selectedImage = '';
    this.voicePartial = '';
  }

  /**
   * 收到一段文本增量。
   * 只往普通字段里拼，攒够 FLUSH_INTERVAL_MS 才写一次 UI —— 每个 token 都
   * 触发重绘会拖垮栅格化，几十毫秒一批肉眼完全看不出差别。
   */
  private onStreamDelta(delta: string): void {
    this.pendingDelta += delta;

    const now: number = Date.now();
    const elapsed: number = now - this.lastFlushAt;
    if (elapsed >= FLUSH_INTERVAL_MS) {
      this.flushStream();
    } else if (this.flushTimerId === -1) {
      // 尾部补偿：保证最后一段增量不会因为不够一个窗口而被丢掉
      this.flushTimerId = setTimeout(() => {
        this.flushTimerId = -1;
        this.flushStream();
      }, FLUSH_INTERVAL_MS - elapsed);
    }
  }

  /**
   * 唯一真正触发重绘的地方（改的是 @Observed 对象的属性，
   * 只会让这一个气泡更新，列表其余部分不参与 diff）
   */
  private flushStream(): void {
    if (this.pendingDelta.length === 0 || this.streamTarget === null) {
      return;
    }
    this.streamTarget.content += this.pendingDelta;
    this.pendingDelta = '';
    this.lastFlushAt = Date.now();
    this.scrollToBottom();
  }

  /**
   * 结束流式：清掉定时器并确保残余增量落地
   */
  private finishStream(): void {
    if (this.flushTimerId !== -1) {
      clearTimeout(this.flushTimerId);
      this.flushTimerId = -1;
    }
    this.flushStream();
  }

  private scrollToBottom(): void {
    this.listScroller.scrollEdge(Edge.Bottom);
  }

  /**
   * 选择图片
   */
  private selectImage(): void {
    // 使用文件选择器选择图片
    // 实际实现需要使用 photoAccess 等 API
    this.selectedImage = 'temp_image_path'; // 占位
  }

  /**
   * 选择文档
   */
  private selectDocument(): void {
    // 使用文件选择器选择文档
    // 实际实现需要使用 fileIo 等 API
  }
}
