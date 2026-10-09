import { Message, MessageType } from '../models/Message';
import { stripMarkdown } from '../utils/TextFormat';

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
      // 头像
      Column() {
        Text(this.getAgentIcon())
          .fontSize(24)
      }
      .width(36)
      .height(36)
      .backgroundColor(this.getAgentColor())
      .borderRadius(18)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 8 })

      // 消息内容
      Column() {
        // 发送者名称
        if (this.message.agentName) {
          Text(this.message.agentName)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ bottom: 4 })
        }

        // 消息文本（流式中在末尾显示光标）
        Row() {
          Text(this.formatContent(this.message.content))
            .fontSize(15)
            .fontColor('#333333')
            .lineHeight(22)
            .layoutWeight(1)

          if (this.message.isStreaming) {
            Text('▍')
              .fontSize(15)
              .fontColor('#007DFF')
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        // 图片（如果有）
        if (this.message.imageUrl) {
          Image(this.message.imageUrl)
            .width(200)
            .height(150)
            .objectFit(ImageFit.Cover)
            .borderRadius(8)
            .margin({ top: 8 })
        }

        // 时间戳
        Text(this.formatTime(this.message.timestamp))
          .fontSize(11)
          .fontColor('#999999')
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
   * 获取智能体图标
   */
  private getAgentIcon(): string {
    switch (this.message.agentName) {
      case '学习助手':
        return '📚';
      case '日程管家':
        return '📅';
      case '文档处理':
        return '📄';
      default:
        return '🤖';
    }
  }

  /**
   * 获取智能体颜色
   */
  private getAgentColor(): string {
    switch (this.message.agentName) {
      case '学习助手':
        return '#E6F4FF';
      case '日程管家':
        return '#E6F7E6';
      case '文档处理':
        return '#F3E5F5';
      default:
        return '#F0F0F0';
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
