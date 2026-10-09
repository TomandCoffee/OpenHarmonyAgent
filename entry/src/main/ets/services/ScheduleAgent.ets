import { hilog } from '@kit.PerformanceAnalysisKit';
import { AgentRequest } from '../models/LLM';
import { AgentType, ProcessResult } from '../models/Message';
import { SCHEDULE_SYSTEM } from './AgentPrompts';
import { runAgent } from './AgentRunner';

const TAG = 'ScheduleAgent';

/** 确定性的兑底声明：模型可能被长上下文带偏，这段由代码保证一定出现 */
const DRAFT_FOOTER = '\n\n（以上为日程草案，尚未写入系统日历，请自行添加）';

/**
 * 日程管家智能体
 *
 * 回答由 DeepSeek 生成，人设见 AgentPrompts.SCHEDULE_SYSTEM。
 * 这个应用没有接系统日历，所以能力宣称必须收敛 —— prompt 里禁止，
 * 代码这里再加一道兜底尾注，保证界面上不会出现"已添加到日历"这种假话。
 */
export class ScheduleAgent {
  private isInitialized: boolean = false;

  initialize(): void {
    this.isInitialized = true;
    hilog.info(0x0000, TAG, 'ScheduleAgent initialized');
  }

  /**
   * 处理日程相关请求
   */
  async handle(req: AgentRequest): Promise<ProcessResult> {
    hilog.info(0x0000, TAG, 'handling: %{public}s', req.text);

    const result: ProcessResult =
      await runAgent(AgentType.SCHEDULE, '日程管家', SCHEDULE_SYSTEM, req, false);

    // 尾注也要走一遍流式回调，否则界面显示的文本会和最终结果对不上
    if (req.onDelta !== undefined) {
      req.onDelta(DRAFT_FOOTER);
    }
    result.content = result.content + DRAFT_FOOTER;
    return result;
  }
}
