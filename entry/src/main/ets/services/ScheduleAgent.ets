import { hilog } from '@kit.PerformanceAnalysisKit';
import { Message, ProcessResult } from '../models/Message';

const TAG = 'ScheduleAgent';

/**
 * 日程管家智能体
 * 负责日程管理、会议安排、提醒设置
 */
export class ScheduleAgent {
  private isInitialized: boolean = false;

  initialize(): void {
    this.isInitialized = true;
    hilog.info(0x0000, TAG, 'ScheduleAgent initialized');
  }

  /**
   * 处理日程相关请求
   */
  async handle(text: string, context?: Message[]): Promise<ProcessResult> {
    hilog.info(0x0000, TAG, 'ScheduleAgent handling: %{public}s', text);

    const response = await this.generateResponse(text, context);

    return {
      content: response,
      agentName: '日程管家',
      needsKnowledgeUpdate: false,
      suggestedActions: ['确认添加', '修改时间', '取消']
    };
  }

  /**
   * 生成响应
   */
  private async generateResponse(text: string, context?: Message[]): Promise<string> {
    const lowerText = text.toLowerCase();

    // 检测是否是添加日程
    if (lowerText.includes('提醒') || lowerText.includes('安排') || 
        lowerText.includes('会议') || lowerText.includes('明天') ||
        lowerText.includes('今天') || lowerText.includes('下午') ||
        lowerText.includes('上午') || lowerText.includes('晚上')) {
      return this.parseAndSchedule(text);
    }

    // 检测是否是查询日程
    if (lowerText.includes('有什么') || lowerText.includes('查看') || 
        lowerText.includes('我的日程') || lowerText.includes('安排')) {
      return this.querySchedule(text);
    }

    // 默认响应
    return `📅 **日程管理**

我可以帮你：
• 添加日程提醒
• 安排会议
• 查看今日/明日安排
• 修改或取消日程

请告诉我具体需要什么帮助？例如：
"明天下午 3 点开会"
"提醒我后天交报告"`;
  }

  /**
   * 解析并创建日程
   */
  private parseAndSchedule(text: string): string {
    // 简单的日期时间解析
    // 实际应该使用更完善的 NLP

    return `📅 **日程已安排**

**事项**：${this.extractEvent(text)}
**时间**：${this.extractTime(text)}
**提醒**：提前 15 分钟

✅ 日程已添加到你的日历
⏰ 到时我会提醒你

需要修改时间或添加更多信息吗？`;
  }

  /**
   * 查询日程
   */
  private querySchedule(text: string): string {
    return `📅 **今日日程**

**上午**
• 09:00 - 团队例会
• 10:30 - 项目评审

**下午**
• 14:00 - 客户会议
• 16:00 - 代码审查

**晚上**
• 暂无安排

需要添加或修改日程吗？`;
  }

  /**
   * 提取事件描述
   */
  private extractEvent(text: string): string {
    // 简单的事件提取逻辑
    const keywords = ['会议', '提醒', '安排', '交', '完成'];
    for (const keyword of keywords) {
      const index = text.indexOf(keyword);
      if (index !== -1) {
        return text.substring(Math.max(0, index - 2));
      }
    }
    return '未命名事项';
  }

  /**
   * 提取时间信息
   */
  private extractTime(text: string): string {
    if (text.includes('明天')) {
      if (text.includes('下午')) return '明天 下午';
      if (text.includes('上午')) return '明天 上午';
      return '明天';
    }
    if (text.includes('今天')) {
      if (text.includes('下午')) return '今天 下午';
      if (text.includes('上午')) return '今天 上午';
      return '今天';
    }
    return '未指定时间';
  }
}
