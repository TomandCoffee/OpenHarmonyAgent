import { hilog } from '@kit.PerformanceAnalysisKit';
import { Agent, AgentType, Message, ProcessResult } from '../models/Message';
import { LearningAgent } from './LearningAgent';
import { ScheduleAgent } from './ScheduleAgent';
import { DocumentAgent } from './DocumentAgent';

const TAG = 'AgentService';

/**
 * 智能体编排服务
 * 负责任务分解、智能体调度和结果整合
 */
export class AgentService {
  private learningAgent: LearningAgent;
  private scheduleAgent: ScheduleAgent;
  private documentAgent: DocumentAgent;
  private isInitialized: boolean = false;

  constructor() {
    this.learningAgent = new LearningAgent();
    this.scheduleAgent = new ScheduleAgent();
    this.documentAgent = new DocumentAgent();
  }

  /**
   * 初始化服务
   */
  initialize(): void {
    if (this.isInitialized) {
      return;
    }

    this.learningAgent.initialize();
    this.scheduleAgent.initialize();
    this.documentAgent.initialize();
    this.isInitialized = true;

    hilog.info(0x0000, TAG, 'AgentService initialized');
  }

  /**
   * 处理用户请求
   * 自动识别意图并分发给相应的智能体
   */
  async processRequest(params: {
    text: string;
    imageUrl?: string;
    context?: Message[];
  }): Promise<ProcessResult> {
    const { text, imageUrl, context } = params;

    hilog.info(0x0000, TAG, 'Processing request: %{public}s', text);

    // 1. 意图识别
    const intent = this.identifyIntent(text, imageUrl);

    // 2. 任务分解（复杂任务）
    if (this.isComplexTask(intent, text)) {
      return await this.handleComplexTask(text, context);
    }

    // 3. 分发到相应智能体
    switch (intent) {
      case AgentType.LEARNING:
        return await this.learningAgent.handle(text, context);
      case AgentType.SCHEDULE:
        return await this.scheduleAgent.handle(text, context);
      case AgentType.DOCUMENT:
        return await this.documentAgent.handle(text, imageUrl, context);
      default:
        // 主助理处理通用请求
        return await this.handleGeneralRequest(text, context);
    }
  }

  /**
   * 识别用户意图
   */
  private identifyIntent(text: string, imageUrl?: string): AgentType {
    const lowerText = text.toLowerCase();

    // 文档相关关键词
    if (imageUrl || 
        lowerText.includes('文档') || 
        lowerText.includes('总结') || 
        lowerText.includes('提取') ||
        lowerText.includes('pdf') ||
        lowerText.includes('文件')) {
      return AgentType.DOCUMENT;
    }

    // 日程相关关键词
    if (lowerText.includes('日程') || 
        lowerText.includes('提醒') || 
        lowerText.includes('会议') ||
        lowerText.includes('安排') ||
        lowerText.includes('时间') ||
        lowerText.includes('明天') ||
        lowerText.includes('今天')) {
      return AgentType.SCHEDULE;
    }

    // 学习相关关键词
    if (lowerText.includes('学习') || 
        lowerText.includes('知识') || 
        lowerText.includes('问题') ||
        lowerText.includes('解释') ||
        lowerText.includes('概念') ||
        lowerText.includes('笔记')) {
      return AgentType.LEARNING;
    }

    // 默认返回主助理
    return AgentType.MAIN;
  }

  /**
   * 判断是否为复杂任务（需要多智能体协作）
   */
  private isComplexTask(intent: AgentType, text: string): boolean {
    const complexKeywords = ['并且', '同时', '还有', '另外', '以及', '和'];
    return complexKeywords.some(keyword => text.includes(keyword));
  }

  /**
   * 处理复杂任务（多智能体协作）
   */
  private async handleComplexTask(text: string, context?: Message[]): Promise<ProcessResult> {
    hilog.info(0x0000, TAG, 'Handling complex task');

    // 任务分解示例
    // "帮我总结这份文档，并安排明天下午的会议来讨论"
    // -> 文档处理 + 日程安排

    const results: ProcessResult[] = [];

    // 并行执行多个智能体
    const [docResult, scheduleResult] = await Promise.all([
      this.documentAgent.handle(text, undefined, context).catch(() => null),
      this.scheduleAgent.handle(text, context).catch(() => null)
    ]);

    if (docResult) results.push(docResult);
    if (scheduleResult) results.push(scheduleResult);

    // 整合结果
    const combinedContent = results.map(r => r.content).join('\n\n');
    
    return {
      content: combinedContent,
      agentName: '多智能体协作',
      needsKnowledgeUpdate: true,
      suggestedActions: results.flatMap(r => r.suggestedActions || [])
    };
  }

  /**
   * 处理通用请求
   */
  private async handleGeneralRequest(text: string, context?: Message[]): Promise<ProcessResult> {
    // 简单的通用响应逻辑
    // 实际应该调用 LLM API
    
    return {
      content: `我收到了你的消息："${text}"\n\n我可以帮你处理学习、日程或文档相关的任务。请告诉我具体需要什么帮助？`,
      agentName: '主助理',
      needsKnowledgeUpdate: false,
      suggestedActions: ['询问学习问题', '设置日程提醒', '处理文档']
    };
  }

  /**
   * 获取所有智能体状态
   */
  getAgentsStatus(): Agent[] {
    return [
      {
        id: 'learning',
        name: '学习助手',
        type: AgentType.LEARNING,
        description: '帮助整理学习资料、解答问题',
        icon: '📚',
        color: '#1890FF',
        capabilities: ['知识问答', '资料整理', '概念解释'],
        isActive: true
      },
      {
        id: 'schedule',
        name: '日程管家',
        type: AgentType.SCHEDULE,
        description: '管理日程安排、提醒事项',
        icon: '📅',
        color: '#52C41A',
        capabilities: ['日程管理', '会议安排', '提醒设置'],
        isActive: true
      },
      {
        id: 'document',
        name: '文档处理',
        type: AgentType.DOCUMENT,
        description: '文档总结、提取重点、格式转换',
        icon: '📄',
        color: '#722ED1',
        capabilities: ['文档总结', '重点提取', 'OCR 识别'],
        isActive: true
      }
    ];
  }
}
