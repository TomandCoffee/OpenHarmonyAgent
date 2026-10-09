import { hilog } from '@kit.PerformanceAnalysisKit';
import { AgentRequest } from '../models/LLM';
import { ProcessResult } from '../models/Message';
import { LEARNING_SYSTEM } from './AgentPrompts';
import { runAgent } from './AgentRunner';

const TAG = 'LearningAgent';

/**
 * 学习助手智能体
 *
 * 回答由 DeepSeek 生成，人设见 AgentPrompts.LEARNING_SYSTEM。
 */
export class LearningAgent {
  private isInitialized: boolean = false;

  initialize(): void {
    this.isInitialized = true;
    hilog.info(0x0000, TAG, 'LearningAgent initialized');
  }

  /**
   * 处理学习相关请求
   */
  async handle(req: AgentRequest): Promise<ProcessResult> {
    hilog.info(0x0000, TAG, 'handling: %{public}s', req.text);
    // 学习类内容最值得沉淀进知识库，其余场景不自动存，避免知识库里全是闲聊
    return runAgent(LEARNING_SYSTEM, '学习助手', req, true);
  }
}
