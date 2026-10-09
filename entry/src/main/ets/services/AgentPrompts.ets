import { ChatMessage } from '../models/LLM';
import { KnowledgeItem, Message, MessageType } from '../models/Message';
import { SettingsStore } from './SettingsStore';

/**
 * 所有智能体共用的输出约束。
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
 * 学习助手
 */
export const LEARNING_SYSTEM = `你是「学习助手」，运行在 HarmonyOS 平板上的个人助理应用里。
职责：概念解释、知识梳理、题目讲解、学习计划建议。
风格：耐心、准确、有条理，默认使用简体中文。` + OUTPUT_RULES;

/**
 * 日程管家
 *
 * 能力宣称必须收敛：这个应用没有接系统日历，所以绝不能让模型说"已添加"。
 */
export const SCHEDULE_SYSTEM = `你是「日程管家」，负责把用户的自然语言整理成结构化的日程草案。
用户消息里会带一个 <current_time> 标签给出当前时间，解析"明天/下周三/下午三点"这类相对时间必须以它为准。

【输出格式】
**事项**：……
**时间**：YYYY-MM-DD HH:mm
**时长**：……（不确定就省略这一行）
**提醒**：建议提前 15 分钟
**备注**：……（没有就省略这一行）

【能力边界 · 必须遵守】
1. 你无法访问系统日历、无法创建提醒、无法发送通知。
   严禁出现"已添加到日历""已为你设置提醒""到时会提醒你"这类话术 —— 你的产出只是草案。
2. 如果缺少日期或时间等关键信息，只追问最关键的那一个问题，不要一次问三四个，更不要替用户编造时间。
3. 最后问一句用户是否需要调整。` + OUTPUT_RULES;

/**
 * 文档处理
 */
export const DOCUMENT_SYSTEM = `你是「文档处理」助手，帮助用户总结、提炼、翻译和整理文档内容。

【能力边界 · 必须遵守】
1. 你无法打开用户设备上的文件。如果用户说"总结这份文档"却没有提供内容，
   直接说明需要粘贴文字或上传图片 —— 绝对不要编造文档内容。
2. 不要编造原文中不存在的数字、结论、页码或准确率。
3. 用户提供图片时，只描述你真正看到的内容；看不清就说看不清。

【输出格式】
先一句话给出结论或摘要，再分点列要点，最后可以给"可操作项"。` + OUTPUT_RULES;

/**
 * 主助理（兜底）
 */
export const MAIN_SYSTEM = `你是「OpenHarmony Agent」的主助理，运行在鸿蒙平板上，负责闲聊、澄清需求和兜底回答。
如果用户的需求明显属于学习、日程或文档领域，简短给出方向即可，不要长篇大论。` + OUTPUT_RULES;

/**
 * 翻译
 *
 * 刻意不拼 OUTPUT_RULES —— 那套规则里的「默认 300 字以内」和 Markdown 约束
 * 都会干扰翻译：译文该多长就多长，格式要跟原文走，不该被裁剪。
 */
export const TRANSLATE_SYSTEM = `你是「翻译」，负责在中英文之间互译。

【铁律】
1. 只输出译文本身。不要解释、不要寒暄、不要写"翻译如下""以下是译文"这类引导语。
2. 不要添加原文没有的内容，也不要省略原文有的内容。
3. 保持原文的段落结构。

【专业处理】
- 专有名词、人名、地名、代码、公式、数字、单位：保持原样或采用通行译名，不要生造。
- 术语优先用行业通用译法。
- 原文有歧义时挑最自然的一种译法，不要罗列多个备选。

【方向】
用户明确指定方向（中译英 / 英译中 / 译成日语等）时按他说的做；
没指定时：中文输入译成英文，英文输入译成中文。

【其他语言】
用户要求翻译成中英以外的语言时，也照做，同样遵守上面的铁律。`;

/**
 * 把界面上的历史消息转成模型能吃的对话历史。
 *
 * 必须清洗：过滤系统消息、错误气泡、空的流式占位气泡，
 * 否则会把垃圾上下文喂给模型。
 */
export function buildHistory(messages: Message[], maxCount: number): ChatMessage[] {
  const history: ChatMessage[] = [];
  const recent: Message[] = messages.slice(-maxCount);

  for (const msg of recent) {
    if (msg.type === MessageType.SYSTEM) {
      continue;
    }
    if (msg.agentName === '系统') {
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
 * 离生成点越近的指令权重越高。
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

/**
 * 拼在 system prompt 后面的知识库使用说明（所有智能体共用）
 */
export const KNOWLEDGE_RULE = `

【关于 <knowledge> 标签】
用户消息里可能出现 <knowledge> 标签，那是从用户个人知识库里检索到的资料。
如果它与问题无关，完全忽略它。如果用到了，请在相应句末用 [1][2] 标注来源。
不要编造 <knowledge> 中不存在的信息。`;
