import { hilog } from '@kit.PerformanceAnalysisKit';
import { AgentRequest } from '../models/LLM';
import { AgentType, ProcessResult } from '../models/Message';
import { DOCUMENT_SYSTEM } from './AgentPrompts';
import { runAgent } from './AgentRunner';

const TAG = 'DocumentAgent';

/**
 * 文档处理智能体
 *
 * 回答由 DeepSeek 生成，人设见 AgentPrompts.DOCUMENT_SYSTEM。
 *
 * 关于图片：本地图片链路（相册选择 → 读字节 → base64）还没打通，
 * 界面传过来的 imageUrl 只是个占位路径。这里如实告知，而不是假装分析过了。
 */
export class DocumentAgent {
  private isInitialized: boolean = false;

  initialize(): void {
    this.isInitialized = true;
    hilog.info(0x0000, TAG, 'DocumentAgent initialized');
  }

  /**
   * 处理文档相关请求
   */
  async handle(req: AgentRequest): Promise<ProcessResult> {
    hilog.info(0x0000, TAG, 'handling: %{public}s', req.text);

    const hasAttachment: boolean = req.imageUrl !== undefined && req.imageUrl.length > 0;

    const effective: AgentRequest = {
      text: hasAttachment
        ? `${req.text}\n\n（注：用户附加了一张图片，但当前版本还读不到图片内容，请如实说明并请他粘贴文字。）`
        : req.text,
      context: req.context,
      knowledge: req.knowledge,
      onDelta: req.onDelta
    };

    return runAgent(AgentType.DOCUMENT, '文档处理', DOCUMENT_SYSTEM, effective, false);
  }
}
