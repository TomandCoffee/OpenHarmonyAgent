import { textToSpeech } from '@kit.CoreSpeechKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { stripMarkdown } from '../utils/TextFormat';
import { Capability } from '../utils/Capability';

const TAG = 'TTSService';

/** 单次播报的文本上限。引擎对长度有限制（错误码 1002300001），超过就分段落 */
const MAX_SEGMENT_CHARS = 180;

/**
 * 语音播报自检结果
 */
export interface TtsProbeResult {
  available: boolean;
  voices: string[];
  detail: string;
}

/**
 * 语音播报服务
 *
 * 用系统自带的 Core Speech Kit（SystemCapability.AI.TextToSpeech）——
 * 和语音识别同一个 kit，同样不需要三方服务、不需要额外权限。
 */
export class TTSService {
  private static instance: TTSService | null = null;

  static getInstance(): TTSService {
    if (TTSService.instance === null) {
      TTSService.instance = new TTSService();
    }
    return TTSService.instance;
  }

  private engine: textToSpeech.TextToSpeechEngine | null = null;
  private language: string = 'zh-CN';
  private person: number = 0;
  private speaking: boolean = false;

  /** 待播报的文本分段队列 */
  private queue: string[] = [];
  /** 当前播报到第几段 */
  private cursor: number = 0;

  /** 当前正在播报的内容标识（通常是消息 id），用于让对应的气泡显示播放状态 */
  private currentTag: string = '';

  /**
   * 播报状态变化监听。可以注册多个（每条消息气泡都要知道自己是不是在播），
   * 回调参数是「是否在播」和「正在播哪一条」。
   */
  private listeners: ((speaking: boolean, tag: string) => void)[] = [];

  addStateListener(callback: (speaking: boolean, tag: string) => void): void {
    this.listeners.push(callback);
  }

  removeStateListener(callback: (speaking: boolean, tag: string) => void): void {
    const index: number = this.listeners.indexOf(callback);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  getCurrentTag(): string {
    return this.currentTag;
  }

  isSpeaking(): boolean {
    return this.speaking;
  }

  /**
   * 更新播报语言和音色。下次播报时会用新参数重建引擎。
   */
  setVoice(language: string, person: number): void {
    if (this.language === language && this.person === person) {
      return;
    }
    this.language = language;
    this.person = person;
    // 参数变了，旧引擎作废（下次 speak 时 initialize 会重建）
    if (this.speaking) {
      this.stop();
    }
    this.release();
    hilog.info(0x0000, TAG, 'voice changed to %{public}s/%{public}d', language, person);
  }

  async initialize(language: string, person: number): Promise<boolean> {
    if (!Capability.canUseTts()) {
      hilog.warn(0x0000, TAG, 'TTS syscap not available on this device');
      return false;
    }
    if (this.engine !== null && this.language === language && this.person === person) {
      return true;
    }

    // 参数变了就重建引擎
    this.release();
    this.language = language;
    this.person = person;

    // 优先离线（不依赖网络），失败退回在线
    if (await this.createWithMode(language, person, 1)) {
      return true;
    }
    hilog.warn(0x0000, TAG, 'offline TTS unavailable, falling back to online');
    return await this.createWithMode(language, person, 0);
  }

  private async createWithMode(language: string, person: number, online: number): Promise<boolean> {
    try {
      const params: textToSpeech.CreateEngineParams = {
        language: language,
        person: person,
        online: online
      };
      const engine: textToSpeech.TextToSpeechEngine = await textToSpeech.createEngine(params);
      this.attachListener(engine);
      this.engine = engine;
      hilog.info(0x0000, TAG, 'engine ready, language=%{public}s person=%{public}d online=%{public}d',
        language, person, online);
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, TAG, 'createEngine failed: code=%{public}d, msg=%{public}s',
        err.code, err.message);
      return false;
    }
  }

  private attachListener(engine: textToSpeech.TextToSpeechEngine): void {
    engine.setListener({
      onStart: (requestId: string, response: textToSpeech.StartResponse) => {
        hilog.info(0x0000, TAG, 'onStart: %{public}s', requestId);
      },
      onComplete: (requestId: string, response: textToSpeech.CompleteResponse) => {
        hilog.info(0x0000, TAG, 'onComplete: %{public}s', requestId);
        this.speakNext();
      },
      onStop: (requestId: string, response: textToSpeech.StopResponse) => {
        hilog.info(0x0000, TAG, 'onStop: %{public}s', requestId);
      },
      onError: (requestId: string, errorCode: number, errorMessage: string) => {
        hilog.error(0x0000, TAG, 'onError %{public}d: %{public}s', errorCode, errorMessage);
        // 单段出错就继续下一段，别让整条回答卡住
        this.speakNext();
      }
    });
  }

  /**
   * 播报一段文本。内部会剥掉 Markdown 并按长度分段。
   *
   * @param tag 内容标识（传消息 id），用于让对应的气泡显示播放状态
   */
  async speak(text: string, tag: string): Promise<boolean> {
    const plain: string = stripMarkdown(text).trim();
    if (plain.length === 0) {
      return false;
    }

    const ready: boolean = await this.initialize(this.language, this.person);
    if (!ready || this.engine === null) {
      hilog.error(0x0000, TAG, 'engine not available');
      return false;
    }

    // 正在播就直接打断重来，符合"点一下换个内容念"的直觉
    if (this.speaking) {
      this.stop();
    }

    this.currentTag = tag;
    this.queue = TTSService.split(plain, MAX_SEGMENT_CHARS);
    this.cursor = 0;
    this.setSpeaking(true);
    this.speakNext();
    return true;
  }

  /**
   * 播报下一段；队列空了就收尾
   */
  private speakNext(): void {
    if (this.cursor >= this.queue.length || this.engine === null) {
      this.setSpeaking(false);
      this.queue = [];
      this.cursor = 0;
      return;
    }

    const segment: string = this.queue[this.cursor];
    this.cursor++;

    try {
      const params: textToSpeech.SpeakParams = {
        requestId: `tts_${Date.now()}_${this.cursor}`
      };
      this.engine.speak(segment, params);
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, TAG, 'speak failed: code=%{public}d, msg=%{public}s', err.code, err.message);
      this.speakNext();
    }
  }

  stop(): void {
    if (this.engine !== null && this.speaking) {
      try {
        this.engine.stop();
      } catch (error) {
        const err = error as BusinessError;
        hilog.warn(0x0000, TAG, 'stop failed: code=%{public}d', err.code);
      }
    }
    this.queue = [];
    this.cursor = 0;
    this.setSpeaking(false);
  }

  private setSpeaking(value: boolean): void {
    if (this.speaking === value) {
      return;
    }
    this.speaking = value;
    if (!value) {
      this.currentTag = '';
    }
    for (const listener of this.listeners) {
      listener(this.speaking, this.currentTag);
    }
  }

  /**
   * 查设备支持哪些语言和音色 —— 设置页用它来填下拉选项
   */
  async listVoices(): Promise<textToSpeech.VoiceInfo[]> {
    const engine: textToSpeech.TextToSpeechEngine | null = this.engine;
    if (engine === null) {
      return [];
    }
    try {
      const query: textToSpeech.VoiceQuery = { requestId: `query_${Date.now()}`, online: 1 };
      return await engine.listVoices(query);
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(0x0000, TAG, 'listVoices failed: code=%{public}d', err.code);
      return [];
    }
  }

  /**
   * 自检：能不能建引擎、支持哪些音色
   */
  async probe(): Promise<TtsProbeResult> {
    const result: TtsProbeResult = { available: false, voices: [], detail: '' };

    if (!Capability.canUseTts()) {
      result.detail = '当前设备不支持语音播报（AI.TextToSpeech syscap 缺失）';
      return result;
    }

    const ok: boolean = await this.initialize('zh-CN', 0);
    result.available = ok;
    if (!ok) {
      result.detail = '引擎创建失败，可能是语言或音色不受支持';
      return result;
    }

    const voices: textToSpeech.VoiceInfo[] = await this.listVoices();
    for (const v of voices) {
      result.voices.push(`${v.language} / 音色${v.person} / ${v.gender}`);
    }
    result.detail = voices.length > 0
      ? `可用音色 ${voices.length} 个`
      : '引擎可用，但未查到音色列表';
    return result;
  }

  /**
   * 释放引擎（应用退出时）
   */
  release(): void {
    const engine: textToSpeech.TextToSpeechEngine | null = this.engine;
    this.engine = null;
    this.speaking = false;
    this.queue = [];
    this.cursor = 0;
    if (engine !== null) {
      try {
        engine.shutdown();
      } catch (error) {
        const err = error as BusinessError;
        hilog.warn(0x0000, TAG, 'shutdown failed: code=%{public}d', err.code);
      }
    }
  }

  /**
   * 按标点把长文本切成小段，避免撞引擎的长度上限。
   *
   * 优先在句末标点处断，其次逗号，最后才硬切。
   */
  private static split(text: string, maxChars: number): string[] {
    const segments: string[] = [];
    let rest: string = text;

    while (rest.length > maxChars) {
      let cut: number = -1;
      // 在窗口内从后往前找句末标点
      for (let i = maxChars; i > maxChars / 2; i--) {
        const ch: string = rest.charAt(i);
        if (ch === '。' || ch === '！' || ch === '？' || ch === '；'
          || ch === '.' || ch === '!' || ch === '?' || ch === ';' || ch === '\n') {
          cut = i + 1;
          break;
        }
      }
      // 找不到句末标点就退而求其次找逗号
      if (cut < 0) {
        for (let i = maxChars; i > maxChars / 2; i--) {
          const ch: string = rest.charAt(i);
          if (ch === '，' || ch === ',' || ch === '、') {
            cut = i + 1;
            break;
          }
        }
      }
      // 还是没有就硬切
      if (cut < 0) {
        cut = maxChars;
      }

      segments.push(rest.substring(0, cut).trim());
      rest = rest.substring(cut);
    }

    if (rest.trim().length > 0) {
      segments.push(rest.trim());
    }
    return segments;
  }
}
