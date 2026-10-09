import { ChatMessage } from '../models/LLM';
import { KnowledgeItem, Message, MessageType } from '../models/Message';
import { SettingsStore } from './SettingsStore';

/** 带上的历史消息条数上限 */
const MAX_CONTEXT_MESSAGES = 10;

/**
 * 通用助手的输出约束。
 *
 * 这里刻意不出现任何动态内容（日期、用户数据），保证 system prompt 前缀稳定 ——
 * DeepSeek 的上下文硬盘缓存按前缀命中，前缀不变才能省钱、快首字。
 * 动态信息一律注入到最后一条 user 消息里。
 */
const OUTPUT_RULES = `

【格式要求】
只使用纯文本和少量 Markdown：可以用 **加粗**、以 • 开头的列表、"1. " 编号列表、空行分段。
不要使用井号标题、表格、代码块、HTML —— 本应用的聊天界面不渲染这些。

【诚实性】
不确定就明确说不确定。不要编造事实、数据、文献或引用来源。不要提及你是哪个模型。`;

/**
 * 默认的 system prompt。
 *
 * 去掉智能体之后只剩这一个 —— 通用对话，不带人设。
 *
 * 「能力边界」那一条是必须的：实测不加约束时，模型会自己发挥成
 * 「可以帮你操作设备和应用」—— 而本应用只是个对话界面，碰不到系统。
 * 宁可少承诺，不要编能力。
 */
export const DEFAULT_SYSTEM = `你是一个运行在 HarmonyOS 设备上的 AI 助手。

【能力边界】
你运行在一个聊天界面里，只能对话。
不能操作设备、不能打开应用、不能设置提醒或日历、不能读取用户的文件。
不要声称自己具备这些能力，也不要说"稍后帮你做"这类做不到的话。

【回答语言】
默认使用简体中文，除非用户使用其他语言或明确要求换语言。` + OUTPUT_RULES;

/**
 * 知识库使用说明（拼在 system prompt 之后）
 */
export const KNOWLEDGE_RULE = `

【关于 <knowledge> 标签】
用户消息里可能出现 <knowledge> 标签，那是从用户本地知识库里检索到的资料。
如果它与问题无关，完全忽略它。如果用到了，请在相应句末用 [1][2] 标注来源。
不要编造 <knowledge> 中不存在的信息。`;

/**
 * 把界面上的历史消息转成模型能吃的对话历史。
 *
 * 过滤规则：
 *   - MessageType.SYSTEM —— 错误气泡、系统提示走这个类型，不能喂给模型
 *   - 空内容 —— 流式占位气泡在还没收到内容时是空的
 * 单条截断到 2000 字，防止把长回答整段回灌。
 */
export function buildHistory(messages: Message[], maxCount: number): ChatMessage[] {
  const history: ChatMessage[] = [];
  const recent: Message[] = messages.slice(-maxCount);

  for (const msg of recent) {
    if (msg.type === MessageType.SYSTEM) {
      continue;
    }
    let text: string = msg.content.trim();
    if (text.length === 0) {
      continue;
    }
    if (text.length > 2000) {
      text = text.substring(0, 2000);
    }
    const role: string = msg.type === MessageType.USER ? 'user' : 'assistant';
    const turn: ChatMessage = { role: role, content: text };
    history.push(turn);
  }

  return history;
}

/**
 * 把本地时间格式化成「2026-10-09 周五 19:45」，注入给模型当相对时间的锚点
 */
export function formatNow(date: Date): string {
  const weekdays: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  const y: string = date.getFullYear().toString();
  const mo: string = (date.getMonth() + 1).toString().padStart(2, '0');
  const d: string = date.getDate().toString().padStart(2, '0');
  const h: string = date.getHours().toString().padStart(2, '0');
  const mi: string = date.getMinutes().toString().padStart(2, '0');
  return `${y}-${mo}-${d} ${weekdays[date.getDay()]} ${h}:${mi}`;
}

/**
 * 组装本轮发给模型的 user 消息内容：
 * 知识库检索结果 + 当前时间 + 用户原话 + 回复语言指令。
 *
 * 动态内容全部放这里而不是 system，是为了保护 system 前缀的缓存命中。
 * 没有检索到东西时不注入空的 <knowledge> 块。
 *
 * 语言指令必须放在这里（本轮 user 消息的末尾），不能只放 system ——
 * 实测：system 末尾写「Always answer in English」时，只要历史消息是中文，
 * 模型就会跟着历史用中文回答；把同一句放到本轮 user 尾部才会立刻切英文。
 */
export function buildUserContent(text: string, knowledge: KnowledgeItem[]): string {
  let head: string = '';

  if (knowledge.length > 0) {
    head += '<knowledge>\n';
    for (let i = 0; i < knowledge.length; i++) {
      let content: string = knowledge[i].content.trim();
      if (content.length > 300) {
        content = content.substring(0, 300);
      }
      head += `[${i + 1}] ${content}\n`;
    }
    head += '</knowledge>\n\n';
  }

  head += `<current_time>${formatNow(new Date())}</current_time>\n\n`;
  return head + text + SettingsStore.getInstance().getReplyLanguageDirective();
}

export const HISTORY_LIMIT = MAX_CONTEXT_MESSAGES;
