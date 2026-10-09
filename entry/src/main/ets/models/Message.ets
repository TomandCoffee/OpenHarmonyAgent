/**
 * 消息类型枚举
 *
 * SYSTEM 用于错误气泡和系统提示 —— 它们会被 buildHistory 过滤掉，
 * 不会作为对话历史喂给模型。
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
  /** 是否正在流式接收中（用于在气泡末尾显示光标） */
  isStreaming: boolean = false;
  /** 是否已经持久化到本地库（避免重复写入） */
  persisted: boolean = false;

  constructor(id: string, type: MessageType, content: string, timestamp: number,
              imageUrl?: string) {
    this.id = id;
    this.type = type;
    this.content = content;
    this.timestamp = timestamp;
    this.imageUrl = imageUrl;
  }
}

/**
 * 知识条目模型
 */
export interface KnowledgeItem {
  id: string;
  content: string;
  type: string;
  tags: string[];
  timestamp: number;
}

/**
 * 会话模型
 */
export interface Conversation {
  id: string;
  title: string;
  createdAt: number;
  updatedAt: number;
}
