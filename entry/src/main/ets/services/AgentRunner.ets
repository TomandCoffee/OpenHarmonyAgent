import { AgentRequest, ChatMessage } from '../models/LLM';
import { KnowledgeItem, ProcessResult } from '../models/Message';
import { LLMService, StreamOutcome } from './LLMService';
import { buildHistory, buildUserContent, KNOWLEDGE_RULE } from './AgentPrompts';

const TAG = 'AgentRunner';

/** 拼给模型的历史消息条数上限 */
const MAX_CONTEXT = 10;

/**
 * 所有智能体共用的执行流程：
 *   拼 system + 历史 + 本轮提问（含知识库检索结果和当前时间）→ 调模型 → 包成 ProcessResult
 *
 * 三个智能体的区别只在于 system prompt 和 agentName。
 *
 * @param needsKnowledgeUpdate 这轮对话的内容是否值得沉淀进知识库
 */
export async function runAgent(systemPrompt: string, agentName: string,
                               req: AgentRequest, needsKnowledgeUpdate: boolean): Promise<ProcessResult> {
  const knowledge: KnowledgeItem[] = req.knowledge !== undefined ? req.knowledge : [];
  const history: ChatMessage[] = buildHistory(req.context !== undefined ? req.context : [], MAX_CONTEXT);

  const messages: ChatMessage[] = [];
  // KNOWLEDGE_RULE 无条件拼上，保证 system 前缀恒定 —— 前缀不变才能命中
  // DeepSeek 的上下文硬盘缓存（省钱 + 首字更快）
  const system: ChatMessage = { role: 'system', content: systemPrompt + KNOWLEDGE_RULE };
  messages.push(system);

  for (const turn of history) {
    messages.push(turn);
  }
  const user: ChatMessage = { role: 'user', content: buildUserContent(req.text, knowledge) };
  messages.push(user);

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
    agentName: agentName,
    needsKnowledgeUpdate: needsKnowledgeUpdate
  };
}
