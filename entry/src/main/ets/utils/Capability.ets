/**
 * 运行时能力探测
 *
 * 同一个应用要跑在不同形态（手机/平板/PC）、不同 HarmonyOS 版本的设备上，
 * 各家支持的 AI 能力并不一致 —— 比如 DataAugmentationKit 的 RAG 模块
 * 只在 PC/2in1 上提供，手机上连编译产物都不会有。
 *
 * 所以凡是「可选能力」，用之前先问一下，不可用就隐藏入口，
 * 而不是等运行时报错。canIUse 是 ArkTS 内置的 syscap 查询函数。
 */
export class Capability {
  /**
   * 语音识别（Core Speech Kit）
   */
  static canUseSpeech(): boolean {
    return canIUse('SystemCapability.AI.SpeechRecognizer');
  }

  /**
   * 语音播报（Core Speech Kit）
   */
  static canUseTts(): boolean {
    return canIUse('SystemCapability.AI.TextToSpeech');
  }

  /**
   * 端侧文本处理（实体识别等）
   */
  static canUseNaturalLanguage(): boolean {
    return canIUse('SystemCapability.AI.NaturalLanguage');
  }

  /**
   * 端侧 OCR
   */
  static canUseOcr(): boolean {
    return canIUse('SystemCapability.AI.OCR');
  }

  /**
   * 端侧向量检索（Data Augmentation Kit 的 retrieval 子模块）
   *
   * 注意：同一 kit 里的 rag / localChatModel 只支持 PC/2in1，
   * 手机和平板查这两个会返回 false，是正常的。
   */
  static canUseRetrieval(): boolean {
    return canIUse('SystemCapability.DataAugmentation.Retrieval');
  }

  /**
   * 端侧知识加工
   */
  static canUseKnowledgeProcessor(): boolean {
    return canIUse('SystemCapability.DataAugmentation.KnowledgeProcessor');
  }

  /**
   * 把当前设备的可用能力汇总成一行，方便在设置页和日志里展示
   */
  static summary(): string {
    const parts: string[] = [];
    parts.push(`语音识别 ${Capability.canUseSpeech() ? '✓' : '✗'}`);
    parts.push(`语音播报 ${Capability.canUseTts() ? '✓' : '✗'}`);
    parts.push(`文本处理 ${Capability.canUseNaturalLanguage() ? '✓' : '✗'}`);
    parts.push(`OCR ${Capability.canUseOcr() ? '✓' : '✗'}`);
    parts.push(`端侧检索 ${Capability.canUseRetrieval() ? '✓' : '✗'}`);
    return parts.join('   ');
  }
}
