import { Message, MessageType } from '../models/Message';

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
  @Prop message: Message;

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
    .borderRadius(16)
    .borderRadius({ topLeft: 16, topRight: 16, bottomLeft: 4, bottomRight: 16 })
    .maxWidth('70%')
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

        // 消息文本
        Text(this.formatContent(this.message.content))
          .fontSize(15)
          .fontColor('#333333')
          .lineHeight(22)
          .width('100%')

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
      .borderRadius(16)
      .borderRadius({ topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16 })
      .maxWidth('70%')
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
   * 格式化内容（支持简单的 Markdown）
   */
  private formatContent(content: string): string {
    // 简单的格式化，实际可以使用富文本
    return content
      .replace(/\*\*(.*?)\*\*/g, '$1') // 粗体
      .replace(/•/g, '•'); // 列表项
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
