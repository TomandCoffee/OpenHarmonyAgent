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
 */
export interface Message {
  id: string;
  type: MessageType;
  content: string;
  timestamp: number;
  imageUrl?: string;
  agentName?: string;
  relatedAgent?: string;
}

/**
 * 智能体类型枚举
 */
export enum AgentType {
  LEARNING = 'learning',
  SCHEDULE = 'schedule',
  DOCUMENT = 'document',
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
