import { textToSpeech } from '@kit.CoreSpeechKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { stripMarkdown } from '../utils/TextFormat';
import { Capability } from '../utils/Capability';

const TAG = 'TTSService';

/** 单次播报的文本上限。引擎对长度有限制（错误码 1002300001），超过就分段落 */
const MAX_SEGMENT_CHARS = 180;

/** 默认音色：传 0 让引擎自己选，实测这个一定能建起来 */
const DEFAULT_PERSON = 0;

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
  /** 全局静音 */
  private muted: boolean = false;
  /** 引擎实际生效的音色（用户选的音色不可用时会回退到默认） */
  private effectivePerson: number = 0;
  /** 实测建不起引擎的音色，记住避免每次重试 */
  private unavailablePersons: number[] = [];

  /** 待播报的文本分段队列 */
  private queue: string[] = [];
  /** 当前播报到第几段 */
  private cursor: number = 0;
  /**
   * 播报会话代号。
   *
   * 分段播报是靠引擎的 onComplete 驱动下一段的，而打断重来时旧段落的
   * onComplete 还在路上 —— 直接响应它会把新队列提前推进（实测日志里能看到
   * 旧 requestId 的 onComplete 紧跟着新队列的入队）。所以每次 speak/stop 都
   * 递增代号，回调里先核对代号，对不上就丢弃。
   */
  private epoch: number = 0;

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
   * 全局静音开关。
   *
   * 语义：静音时不接受任何新的朗读请求，并且立刻停掉正在播的内容。
   * 这是「总开关」，消息上的喇叭只是「读这条」——两者职责分开。
   */
  setMuted(value: boolean): void {
    if (this.muted === value) {
      return;
    }
    this.muted = value;
    if (value && this.speaking) {
      this.stop();
    }
    hilog.info(0x0000, TAG, 'muted: %{public}s', value.toString());
  }

  isMuted(): boolean {
    return this.muted;
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
    // 语言一致，且要么音色就是当前生效的、要么这个音色已知不可用 —— 都不必重建
    if (this.engine !== null && this.language === language
      && (this.effectivePerson === person || this.unavailablePersons.indexOf(person) >= 0)) {
      return true;
    }

    // 参数变了就重建引擎
    this.release();
    this.language = language;
    this.person = person;
    return await this.createBestEngine(language, person);
  }

  /**
   * 建引擎：先按用户选的音色试，建不起来就退回默认音色。
   *
   * 为什么必须回退：设备的 listVoices() 会列出**资源还没下载**的音色。
   * 用这种音色 createEngine 直接失败（1002300005，底层报 "Invalid relative path"）。
   * 实测选中中文男声后引擎完全建不起来，朗读彻底不能用 —— 所以列表能查到
   * 不等于能用，必须容错。
   */
  private async createBestEngine(language: string, person: number): Promise<boolean> {
    if (this.unavailablePersons.indexOf(person) < 0) {
      // 优先离线（不依赖网络），失败退回在线
      if (await this.createWithMode(language, person, 1)
        || await this.createWithMode(language, person, 0)) {
        this.effectivePerson = person;
        return true;
      }
      if (person !== DEFAULT_PERSON) {
        this.unavailablePersons.push(person);
        hilog.warn(0x0000, TAG, 'voice %{public}d unusable (resource missing?), remembered', person);
      }
    }

    if (person !== DEFAULT_PERSON) {
      if (await this.createWithMode(language, DEFAULT_PERSON, 1)
        || await this.createWithMode(language, DEFAULT_PERSON, 0)) {
        this.effectivePerson = DEFAULT_PERSON;
        hilog.info(0x0000, TAG, 'fell back to default voice');
        return true;
      }
    }
    return false;
  }

  /**
   * 引擎实际生效的音色。可能是回退后的默认值，
   * 设置页用它判断用户选的音色有没有真的生效。
   */
  getEffectivePerson(): number {
    return this.effectivePerson;
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
        if (!this.isCurrent(requestId)) {
          hilog.info(0x0000, TAG, 'drop stale onComplete: %{public}s', requestId);
          return;
        }
        hilog.info(0x0000, TAG, 'onComplete: %{public}s', requestId);
        this.speakNext();
      },
      onStop: (requestId: string, response: textToSpeech.StopResponse) => {
        hilog.info(0x0000, TAG, 'onStop: %{public}s', requestId);
      },
      onError: (requestId: string, errorCode: number, errorMessage: string) => {
        hilog.error(0x0000, TAG, 'onError %{public}d: %{public}s', errorCode, errorMessage);
        if (!this.isCurrent(requestId)) {
          return;
        }
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
    if (this.muted) {
      hilog.info(0x0000, TAG, 'muted, ignore speak request');
      return false;
    }

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

    // 无论如何都要推进会话代号。
    //
    // 引擎会拒绝重复的 requestId（错误码 40003 "requestId is empty or repeated"），
    // 而上一条播完时 speaking 已经是 false、不会走 stop()，代号不变的话
    // 这次就会发出和上一轮完全相同的 requestId —— 表现为「第一遍能念，
    // 之后再点就没声音」。所以推进动作必须在这里，不能只放在 stop() 里。
    this.epoch++;

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
  /**
   * 判断这个回调是否属于当前播报会话
   */
  private isCurrent(requestId: string): boolean {
    return requestId.startsWith(`e${this.epoch}_`);
  }

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
        requestId: `e${this.epoch}_${this.cursor}`
      };
      this.engine.speak(segment, params);
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, TAG, 'speak failed: code=%{public}d, msg=%{public}s', err.code, err.message);
      this.speakNext();
    }
  }

  stop(): void {
    // 先递增代号：让在途的 onComplete 立刻失效
    this.epoch++;

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
   * 查指定语言下可用的音色。
   *
   * 先确保引擎按这个语言建起来再查 —— 否则 listVoices 返回空
   * （引擎没初始化时会直接抛，这里也不会有结果）。
   */
  async listVoicesFor(language: string): Promise<textToSpeech.VoiceInfo[]> {
    const ok: boolean = await this.initialize(language, this.person);
    if (!ok) {
      hilog.warn(0x0000, TAG, 'cannot list voices: engine not ready');
      return [];
    }
    return await this.listVoices();
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
