import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatRequest, ChatMessage } from '../models/LLM';
import { KnowledgeItem } from '../models/Message';
import { LLMService, StreamOutcome } from './LLMService';
import { buildHistory, buildUserContent, DEFAULT_SYSTEM, HISTORY_LIMIT, KNOWLEDGE_RULE } from './Prompts';

const TAG = 'ChatEngine';

/** 一次对话的产出 */
export interface ChatReply {
  /** 完整回答（可能带错误说明） */
  content: string;
  /** 这轮内容是否值得沉淀进本地知识库 */
  remember: boolean;
}

/** 太短的内容不值得记进知识库（"好的" "嗯" 这类） */
const MIN_REMEMBER_LENGTH = 8;

/**
 * 对话引擎：把一轮提问变成一次模型调用。
 *
 * 去掉智能体之后这里不再有路由 —— 所有提问走同一条链路：
 *   拼 system + 历史 + 本轮提问（含知识库检索结果和时间锚点）→ 流式调模型
 */
export async function chat(req: ChatRequest): Promise<ChatReply> {
  const knowledge: KnowledgeItem[] = req.knowledge !== undefined ? req.knowledge : [];
  const history: ChatMessage[] =
    buildHistory(req.context !== undefined ? req.context : [], HISTORY_LIMIT);

  const messages: ChatMessage[] = [];
  // KNOWLEDGE_RULE 无条件拼上，保证 system 前缀恒定 —— 前缀不变才能命中
  // DeepSeek 的上下文硬盘缓存。语言指令不在这里，见 buildUserContent 的注释。
  const system: ChatMessage = { role: 'system', content: DEFAULT_SYSTEM + KNOWLEDGE_RULE };
  messages.push(system);

  for (const turn of history) {
    messages.push(turn);
  }
  const user: ChatMessage = { role: 'user', content: buildUserContent(req.text, knowledge) };
  messages.push(user);

  hilog.info(0x0000, TAG, 'sending: history=%{public}d, knowledge=%{public}d',
    history.length, knowledge.length);

  const onDelta = req.onDelta;
  const callback = (delta: string): void => {
    if (onDelta !== undefined) {
      onDelta(delta);
    }
  };

  const outcome: StreamOutcome = await LLMService.getInstance().chatStream(messages, callback);

  let content: string = outcome.content;
  if (outcome.errorMessage.length > 0) {
    content = content.length > 0
      ? `${content}\n\n———\n⚠️ ${outcome.errorMessage}`
      : `⚠️ ${outcome.errorMessage}`;
  }
  if (content.length === 0) {
    content = '（没有收到内容，请重新发送）';
  }

  return {
    content: content,
    remember: req.text.trim().length >= MIN_REMEMBER_LENGTH
  };
}
