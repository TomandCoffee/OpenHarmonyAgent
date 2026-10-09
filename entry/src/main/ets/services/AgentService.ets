import { hilog } from '@kit.PerformanceAnalysisKit';
import { AgentRequest } from '../models/LLM';
import { Agent, AgentType, KnowledgeItem, Message, ProcessResult } from '../models/Message';
import { LearningAgent } from './LearningAgent';
import { ScheduleAgent } from './ScheduleAgent';
import { DocumentAgent } from './DocumentAgent';
import { RAGService } from './RAGService';
import { MAIN_SYSTEM } from './AgentPrompts';
import { runAgent } from './AgentRunner';

const TAG = 'AgentService';

/**
 * 请求参数
 */
interface RequestParams {
  text: string;
  imageUrl?: string;
  context?: Message[];
  /** 流式增量回调，透传给具体智能体 */
  onDelta?: (delta: string) => void;
  /** 意图路由确定后立刻回调，让界面先把气泡的署名填上 */
  onAgentName?: (name: string) => void;
}

/**
 * 智能体编排服务
 * 负责意图识别、知识库检索和智能体调度
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
   * 处理用户请求：识别意图 → 检索知识库 → 分发给对应智能体
   */
  async processRequest(params: RequestParams): Promise<ProcessResult> {
    const text: string = params.text;
    const imageUrl: string | undefined = params.imageUrl;
    const context: Message[] | undefined = params.context;

    hilog.info(0x0000, TAG, 'Processing request, length: %{public}d', text.length);

    // 1. 意图识别
    const intent: AgentType = this.identifyIntent(text, imageUrl);

    // 2. 需要同时处理文档和日程的复合请求
    if (this.needsTwoAgents(text, imageUrl)) {
      if (params.onAgentName !== undefined) {
        params.onAgentName('多智能体协作');
      }
      return await this.handleComplexTask(params);
    }

    // 3. 路由已定，先把署名告诉界面（模型首字可能还要等一两秒）
    if (params.onAgentName !== undefined) {
      params.onAgentName(AgentService.displayName(intent));
    }

    // 3. 检索本地知识库（只在学习类和兜底场景做，日程/文档用不上）
    let knowledge: KnowledgeItem[] = [];
    if (intent === AgentType.LEARNING || intent === AgentType.MAIN) {
      knowledge = await RAGService.getInstance().retrieve(text, 3);
    }

    const req: AgentRequest = {
      text: text,
      imageUrl: imageUrl,
      context: context,
      onDelta: params.onDelta,
      knowledge: knowledge
    };

    // 4. 分发
    switch (intent) {
      case AgentType.LEARNING:
        return await this.learningAgent.handle(req);
      case AgentType.SCHEDULE:
        return await this.scheduleAgent.handle(req);
      case AgentType.DOCUMENT:
        return await this.documentAgent.handle(req);
      default:
        return await runAgent(MAIN_SYSTEM, '主助理', req, false);
    }
  }

  /**
   * 意图对应的显示名，要和各智能体 handle() 里传的 agentName 保持一致
   */
  private static displayName(intent: AgentType): string {
    switch (intent) {
      case AgentType.LEARNING: return '学习助手';
      case AgentType.SCHEDULE: return '日程管家';
      case AgentType.DOCUMENT: return '文档处理';
      default: return '主助理';
    }
  }

  /**
   * 识别用户意图
   */
  private identifyIntent(text: string, imageUrl?: string): AgentType {
    const lowerText: string = text.toLowerCase();

    // 文档相关关键词
    if (imageUrl !== undefined && imageUrl.length > 0) {
      return AgentType.DOCUMENT;
    }
    if (lowerText.includes('文档') || lowerText.includes('总结') || lowerText.includes('提取')
      || lowerText.includes('pdf') || lowerText.includes('文件') || lowerText.includes('摘要')) {
      return AgentType.DOCUMENT;
    }

    // 日程相关关键词
    if (lowerText.includes('日程') || lowerText.includes('提醒') || lowerText.includes('会议')
      || lowerText.includes('安排') || lowerText.includes('明天') || lowerText.includes('后天')
      || lowerText.includes('约') || lowerText.includes('几点')) {
      return AgentType.SCHEDULE;
    }

    // 学习相关关键词
    if (lowerText.includes('学习') || lowerText.includes('知识') || lowerText.includes('问题')
      || lowerText.includes('解释') || lowerText.includes('概念') || lowerText.includes('笔记')
      || lowerText.includes('什么是') || lowerText.includes('为什么') || lowerText.includes('怎么')) {
      return AgentType.LEARNING;
    }

    return AgentType.MAIN;
  }

  /**
   * 判断是否需要同时跑文档和日程两个智能体。
   *
   * 旧实现是「文本里出现 和/并且/同时/还有 就算复杂任务」，问题是中文里带"和"的
   * 句子太多（"什么是调和分析"会被误判），而它注释里举的例子
   * 「帮我总结这份文档，并安排明天下午的会议」反而不含任何一个关键词。
   * 现在改成：文档意图和日程意图都命中才并行。
   */
  private needsTwoAgents(text: string, imageUrl?: string): boolean {
    const lowerText: string = text.toLowerCase();

    const docHit: boolean = (imageUrl !== undefined && imageUrl.length > 0)
      || lowerText.includes('文档') || lowerText.includes('总结')
      || lowerText.includes('提取') || lowerText.includes('pdf');

    const scheduleHit: boolean = lowerText.includes('日程') || lowerText.includes('提醒')
      || lowerText.includes('会议') || lowerText.includes('安排');

    return docHit && scheduleHit;
  }

  /**
   * 复合任务：串行跑两个智能体，把两段结果拼在一个气泡里。
   *
   * 之所以串行而不是并行：只有一个气泡，两路并行的流没法交错渲染。
   */
  private async handleComplexTask(params: RequestParams): Promise<ProcessResult> {
    const emit = (chunk: string): void => {
      if (params.onDelta !== undefined) {
        params.onDelta(chunk);
      }
    };

    const docHeader: string = '【文档处理】\n';
    emit(docHeader);
    const docResult: ProcessResult = await this.documentAgent.handle({
      text: params.text,
      imageUrl: params.imageUrl,
      context: params.context,
      knowledge: [],
      onDelta: params.onDelta
    });

    const scheduleHeader: string = '\n\n【日程管家】\n';
    emit(scheduleHeader);
    const scheduleResult: ProcessResult = await this.scheduleAgent.handle({
      text: params.text,
      context: params.context,
      knowledge: [],
      onDelta: params.onDelta
    });

    return {
      content: `${docHeader}${docResult.content}${scheduleHeader}${scheduleResult.content}`,
      agentName: '多智能体协作',
      needsKnowledgeUpdate: false
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
