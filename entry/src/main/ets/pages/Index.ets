import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { VoiceInput } from '../components/VoiceInput';
import { TextInput } from '../components/TextInput';
import { ImageInput } from '../components/ImageInput';
import { ChatBubble } from '../components/ChatBubble';
import { Message, MessageType } from '../models/Message';
import { AgentService } from '../services/AgentService';
import { RAGService } from '../services/RAGService';

const TAG = 'Index';

@Entry
@Component
struct Index {
  @State messages: Message[] = [];
  @State isProcessing: boolean = false;
  @State currentInput: string = '';
  @State selectedImage: string = '';
  @State showInputMethods: boolean = false;
  
  private agentService: AgentService = new AgentService();
  private ragService: RAGService = new RAGService();

  aboutToAppear(): void {
    hilog.info(0x0000, TAG, 'Index aboutToAppear');
    // 初始化服务
    this.agentService.initialize();
    this.ragService.initialize();
    
    // 添加欢迎消息
    this.messages.push({
      id: 'welcome',
      type: MessageType.AGENT,
      content: '你好！我是 OpenHarmony Agent，你的智能个人助理。我可以帮你：\n\n📚 整理学习资料、解答问题\n📅 管理日程安排、设置提醒\n📄 处理文档、总结重点\n\n你可以语音、文字或图片与我交流，试试说"帮我总结这份文档"吧！',
      timestamp: Date.now(),
      agentName: '主助理'
    });
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
        Image($r('sys.media.ohos_ic_public_search'))
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

      // 智能体入口
      Button() {
        Image($r('sys.media.ohos_ic_public_more'))
          .width(24)
          .height(24)
          .fillColor('#666666')
      }
      .type(ButtonType.Circle)
      .backgroundColor('transparent')
      .onClick(() => {
        router.pushUrl({ url: 'pages/Agents' });
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .shadow({ radius: 2, color: '#10000000', offsetY: 1 })
  }

  @Builder
  MessageList() {
    Scroll() {
      Column() {
        ForEach(this.messages, (message: Message) => {
          ChatBubble({ message: message })
        }, (message: Message) => message.id)
      }
      .width('100%')
      .padding(12)
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  @Builder
  InputArea() {
    Column() {
      // 图片预览
      if (this.selectedImage) {
        this.ImagePreview()
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
        TextInput({ placeholder: '输入消息...', text: this.currentInput })
          .layoutWeight(1)
          .height(40)
          .margin({ left: 8, right: 8 })
          .backgroundColor('#F5F5F5')
          .borderRadius(20)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.currentInput = value;
          })

        // 语音输入按钮
        VoiceInput({
          onResult: (text: string) => {
            this.currentInput = text;
            this.sendMessage();
          }
        })

        // 发送按钮
        if (this.currentInput || this.selectedImage) {
          Button() {
            Image($r('sys.media.ohos_ic_public_send'))
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
        Image($r('sys.media.ohos_ic_public_delete'))
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
          Image($r('sys.media.ohos_ic_public_microphone'))
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
          Image($r('sys.media.ohos_ic_public_image'))
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
          Image($r('sys.media.ohos_ic_public_file'))
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
   * 发送消息
   */
  private async sendMessage(): Promise<void> {
    if (!this.currentInput && !this.selectedImage) {
      return;
    }

    if (this.isProcessing) {
      return;
    }

    this.isProcessing = true;

    // 添加用户消息
    const userMessage: Message = {
      id: `user_${Date.now()}`,
      type: MessageType.USER,
      content: this.currentInput,
      timestamp: Date.now(),
      imageUrl: this.selectedImage || undefined
    };
    this.messages.push(userMessage);

    // 清空输入
    const inputText = this.currentInput;
    const inputImage = this.selectedImage;
    this.currentInput = '';
    this.selectedImage = '';

    try {
      // 调用智能体服务处理
      const response = await this.agentService.processRequest({
        text: inputText,
        imageUrl: inputImage,
        context: this.messages.slice(-10) // 传递最近 10 条消息作为上下文
      });

      // 添加助手回复
      const agentMessage: Message = {
        id: `agent_${Date.now()}`,
        type: MessageType.AGENT,
        content: response.content,
        timestamp: Date.now(),
        agentName: response.agentName
      };
      this.messages.push(agentMessage);

      // 如果是知识相关的查询，更新 RAG 知识库
      if (response.needsKnowledgeUpdate) {
        await this.ragService.addKnowledge({
          content: inputText,
          type: 'conversation',
          timestamp: Date.now()
        });
      }
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to process message: %{public}s', JSON.stringify(error) ?? '');
      
      // 添加错误消息
      const errorMessage: Message = {
        id: `error_${Date.now()}`,
        type: MessageType.AGENT,
        content: '抱歉，处理您的请求时出现了问题，请稍后重试。',
        timestamp: Date.now(),
        agentName: '系统'
      };
      this.messages.push(errorMessage);
    } finally {
      this.isProcessing = false;
    }
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
