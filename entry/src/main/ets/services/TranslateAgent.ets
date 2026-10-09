import { hilog } from '@kit.PerformanceAnalysisKit';
import { AgentRequest } from '../models/LLM';
import { AgentType, ProcessResult } from '../models/Message';
import { TRANSLATE_SYSTEM } from './AgentPrompts';
import { runAgent } from './AgentRunner';

const TAG = 'TranslateAgent';

/**
 * 翻译智能体
 *
 * 没有用任何系统翻译 API —— HarmonyOS 目前没有对外的端侧翻译能力。
 * 直接用大模型做，好处是方向（中译英/英译中/译成第三种语言）和语体
 * 都能靠自然语言指定，不用为每种组合写分支。
 */
export class TranslateAgent {
  private isInitialized: boolean = false;

  initialize(): void {
    this.isInitialized = true;
    hilog.info(0x0000, TAG, 'TranslateAgent initialized');
  }

  async handle(req: AgentRequest): Promise<ProcessResult> {
    hilog.info(0x0000, TAG, 'handling: %{public}s', req.text);
    // 翻译内容不需要沉淀进知识库，也不该被知识库检索结果干扰
    return runAgent(AgentType.TRANSLATE, '翻译', TRANSLATE_SYSTEM, {
      text: req.text,
      context: undefined,
      knowledge: [],
      onDelta: req.onDelta
    }, false);
  }
}
