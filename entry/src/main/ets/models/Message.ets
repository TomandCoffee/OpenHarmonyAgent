/**
 * 消息类型枚举
 */
export enum MessageType {
  USER = 'user',
  AGENT = 'agent',
  SYSTEM = 'system'
}

/**
 * 消息模型
 *
 * 用 @Observed class 而不是 interface：流式输出需要「只改 content 就让对应的那一个
 * 气泡重绘」。普通 interface 配 @Prop 做不到 —— @Prop 是浅拷贝，父对象原地改属性
 * 子组件收不到通知，而 ForEach 的 key 不变时又不会重建组件。
 */
@Observed
export class Message {
  id: string;
  type: MessageType;
  content: string;
  timestamp: number;
  imageUrl?: string;
  agentName?: string;
  relatedAgent?: string;
  /** 是否正在流式接收中（用于在气泡末尾显示光标） */
  isStreaming: boolean = false;

  constructor(id: string, type: MessageType, content: string, timestamp: number,
              imageUrl?: string, agentName?: string, relatedAgent?: string) {
    this.id = id;
    this.type = type;
    this.content = content;
    this.timestamp = timestamp;
    this.imageUrl = imageUrl;
    this.agentName = agentName;
    this.relatedAgent = relatedAgent;
  }
}

/**
 * 智能体类型枚举
 */
export enum AgentType {
  LEARNING = 'learning',
  SCHEDULE = 'schedule',
  DOCUMENT = 'document',
  TRANSLATE = 'translate',
  MAIN = 'main'
}

/**
 * 智能体模型
 */
export interface Agent {
  id: string;
  name: string;
  type: AgentType;
  description: string;
  icon: string;
  color: string;
  capabilities: string[];
  isActive: boolean;
}

/**
 * 知识条目模型
 */
export interface KnowledgeItem {
  id: string;
  content: string;
  type: string;
  tags: string[];
  embedding?: number[];
  timestamp: number;
  source?: string;
}

/**
 * 请求处理结果
 */
export interface ProcessResult {
  content: string;
  agentName: string;
  /**
   * 智能体的类型标识（learning / schedule / document / main / multi）。
   *
   * 界面判断图标、配色这类逻辑必须用它，不能用 agentName ——
   * 显示名是要被本地化的，拿它当逻辑键，一改语言图标就全丢了。
   */
  agentType: string;
  needsKnowledgeUpdate: boolean;
  suggestedActions?: string[];
}

/**
 * 语音识别结果
 */
export interface VoiceResult {
  text: string;
  confidence: number;
  isFinal: boolean;
}

/**
 * 图像分析结果
 */
export interface ImageAnalysisResult {
  description: string;
  tags: string[];
  text?: string; // OCR 结果
  objects?: string[];
}
