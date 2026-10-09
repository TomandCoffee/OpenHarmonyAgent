import { Message, MessageType } from '../models/Message';
import { stripMarkdown } from '../utils/TextFormat';
import { TTSService } from '../services/TTSService';
import { Capability } from '../utils/Capability';
import { promptAction } from '@kit.ArkUI';

/**
 * 对话气泡组件属性
 */
interface ChatBubbleProps {
  message: Message;
}

/**
 * 对话气泡组件
 * 显示用户和助手的消息
 */
@Component
export struct ChatBubble {
  // @ObjectLink 配合 Message 的 @Observed：流式时只改 message.content
  // 就能让这一个气泡重绘，列表其他部分不参与 diff
  @ObjectLink message: Message;
  /** 本条消息是否正在被朗读 */
  @State isSpeaking: boolean = false;

  private ttsListener = (speaking: boolean, tag: string): void => {
    this.isSpeaking = speaking && tag === this.message.id;
  };

  aboutToAppear(): void {
    TTSService.getInstance().addStateListener(this.ttsListener);
  }

  aboutToDisappear(): void {
    TTSService.getInstance().removeStateListener(this.ttsListener);
  }

  /**
   * 朗读入口的显示条件：设备支持 + 消息已生成完 + 有内容 + 不是用户自己发的
   */
  private canSpeak(): boolean {
    return Capability.canUseTts()
      && this.message.type === MessageType.AGENT
      && !this.message.isStreaming
      && this.message.content.trim().length > 0;
  }

  /**
   * 消息上的喇叭：单击朗读这条；如果这条正在念，单击即停。
   *
   * 静音是全局开关（在首页右上角），这里只做提示，不改变全局状态。
   */
  private toggleSpeak(): void {
    const tts: TTSService = TTSService.getInstance();

    if (this.isSpeaking) {
      tts.stop();
      return;
    }

    if (tts.isMuted()) {
      promptAction.showToast({ message: '已静音，可在右上角开启' });
      return;
    }

    tts.speak(this.message.content, this.message.id);
  }

  build() {
    Row() {
      if (this.message.type === MessageType.USER) {
        // 用户消息（右侧）
        this.UserBubble()
      } else {
        // 助手消息（左侧）
        this.AgentBubble()
      }
    }
    .width('100%')
    .justifyContent(this.message.type === MessageType.USER ? FlexAlign.End : FlexAlign.Start)
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  UserBubble() {
    Column() {
      Text(this.message.content)
        .fontSize(15)
        .fontColor('#FFFFFF')
        .lineHeight(22)
    }
    .padding(12)
    .backgroundColor('#007DFF')
    .borderRadius({ topLeft: 16, topRight: 16, bottomLeft: 4, bottomRight: 16 })
    .constraintSize({ maxWidth: '70%' })
    .shadow({ radius: 2, color: '#20007DFF', offsetY: 1 })
  }

  @Builder
  AgentBubble() {
    Row() {
      // 头像：去掉智能体之后统一用一个中性图标
      Column() {
        Text('🤖')
          .fontSize(24)
      }
      .width(36)
      .height(36)
      .backgroundColor('#F0F0F0')
      .borderRadius(18)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 8 })

      // 消息内容
      Column() {
        // 消息文本（流式时末尾跟一个光标）
        //
        // 光标用 Span 而不是外面再包一层 Row —— 包 Row 就得给 Row 设
        // width('100%')，而百分比是相对外层容器算的，会直接撑破
        // Column 上的 constraintSize({maxWidth:'70%'})，表现为文字溢出气泡背景。
        // 放进同一个 Text 里，换行和宽度都由 Text 自己算，不会出这个问题。
        Text() {
          Span(this.formatContent(this.message.content))
          Span(this.message.isStreaming ? '▍' : '')
            .fontColor('#007DFF')
        }
        .fontSize(15)
        .fontColor('#333333')
        .lineHeight(22)

        // 图片（如果有）
        if (this.message.imageUrl) {
          Image(this.message.imageUrl)
            .width(200)
            .height(150)
            .objectFit(ImageFit.Cover)
            .borderRadius(8)
            .margin({ top: 8 })
        }

        // 时间戳 + 朗读按钮
        Row() {
          Text(this.formatTime(this.message.timestamp))
            .fontSize(11)
            .fontColor('#999999')

          // 朗读只对已生成完的助手消息开放：流式进行中内容还在变，
          // 念出来必然和最终结果对不上
          if (this.canSpeak()) {
            Button() {
              Image(this.isSpeaking
                ? $r('sys.media.ohos_ic_public_sound_off')
                : $r('sys.media.ohos_ic_public_sound'))
                .width(16)
                .height(16)
                .fillColor(this.isSpeaking ? '#007DFF' : '#999999')
            }
            .type(ButtonType.Circle)
            .backgroundColor('transparent')
            .padding(0)
            .margin({ left: 10 })
            .onClick(() => {
              this.toggleSpeak();
            })
          }
        }
        .margin({ top: 4 })
      }
      .padding(12)
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16 })
      .constraintSize({ maxWidth: '70%' })
      .alignItems(HorizontalAlign.Start)
    }
  }

  /**
   * 格式化内容（剥掉模型输出的轻量 Markdown）
   *
   * 聊天界面只渲染纯文本，所以这里把标记去掉而不是真去渲染富文本 ——
   * 为演示引入富文本渲染器不划算。
   */
  private formatContent(content: string): string {
    return stripMarkdown(content);
  }

  /**
   * 格式化时间
   */
  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    return `${hours}:${minutes}`;
  }
}
