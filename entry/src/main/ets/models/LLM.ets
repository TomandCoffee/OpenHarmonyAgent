/**
 * DeepSeek / OpenAI 兼容接口的请求与响应类型。
 *
 * ArkTS 不允许无类型对象字面量，也不允许 any，所以这里把用到的字段
 * 都显式声明出来；SSE 响应体只映射我们真正读取的字段。
 */

import { KnowledgeItem, Message } from './Message';

/**
 * 对话消息（发给模型）
 */
export interface ChatMessage {
  role: string; // system | user | assistant
  content: string;
}

/**
 * 思考模式开关。deepseek-flash 默认开启思考模式且 effort=high，
 * 聊天场景必须显式关闭，否则首字要等好几秒。
 */
export interface ThinkingConfig {
  type: string; // enabled | disabled
}

/**
 * 请求体
 */
export interface ChatRequestBody {
  model: string;
  messages: ChatMessage[];
  thinking: ThinkingConfig;
  stream: boolean;
  max_tokens: number;
}

/**
 * 流式响应中的增量
 */
export interface SSEDelta {
  role?: string;
  content?: string;
  reasoning_content?: string;
}

/**
 * 流式响应中的一个候选
 */
export interface SSEChoice {
  index: number;
  delta: SSEDelta;
  finish_reason: string | null;
}

/**
 * 流式响应的一帧（data: {...} 里的内容）
 */
export interface SSEChunk {
  id: string;
  model: string;
  choices: SSEChoice[];
}

/**
 * 非流式响应的消息体
 */
export interface ChatResponseMessage {
  role: string;
  content: string;
}

/**
 * 非流式响应中的一个候选
 */
export interface ChatResponseChoice {
  index: number;
  message: ChatResponseMessage;
  finish_reason: string | null;
}

/**
 * 非流式响应体
 */
export interface ChatResponse {
  id: string;
  model: string;
  choices: ChatResponseChoice[];
}

/**
 * 接口返回的错误体
 */
export interface APIErrorDetail {
  message: string;
  type: string;
  code: string;
}

export interface APIErrorBody {
  error: APIErrorDetail;
}

/**
 * 一次对话请求需要的全部输入
 */
export interface ChatRequest {
  /** 用户这轮说的话 */
  text: string;
  /** 用户选的图片（本地路径或 data URL），目前链路未打通 */
  imageUrl?: string;
  /** 界面上的历史消息，用于拼多轮上下文 */
  context?: Message[];
  /** 流式增量回调；不传就是纯后端调用 */
  onDelta?: (delta: string) => void;
  /** 从本地知识库检索到的相关内容，会注入到本轮提问里 */
  knowledge?: KnowledgeItem[];
}
