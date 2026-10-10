import { speechRecognizer } from '@kit.CoreSpeechKit';
import { audio } from '@kit.AudioKit';
import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { SettingsStore } from './SettingsStore';

const TAG = 'VoiceService';

const SAMPLE_RATE = 16000;
/** writeAudio 只接受 640 或 1280 字节的音频块，多一个少一个都会被拒 */
const WRITE_CHUNK_BYTES = 640;
/** finish() 之后等引擎吐完最后一段结果的超时 */
const FINISH_TIMEOUT_MS = 4000;

/**
 * 语音自检结果
 */
export interface VoiceProbeResult {
  offlineOk: boolean;
  onlineOk: boolean;
  /** 自检过程中的原始信息，用于定位问题 */
  detail: string;
}

/**
 * 语音识别服务
 *
 * 用系统自带的 Core Speech Kit（SystemCapability.AI.SpeechRecognizer）——
 * 不需要三方 SDK、不需要申请额外权限、不需要华为账号。
 *
 * 采集用 AudioKit 的 AudioCapturer，边采边喂给识别引擎，所以能拿到
 * 说话过程中的中间结果（打字机式的实时转写）。
 */
export class VoiceService {
  private static instance: VoiceService | null = null;

  /**
   * 全局单例。
   *
   * ASR 是系统服务，全局只允许存在一个识别引擎（否则报 1002200006 engine is busy），
   * 所以这个服务不能每个页面各 new 一份。
   */
  static getInstance(): VoiceService {
    if (VoiceService.instance === null) {
      VoiceService.instance = new VoiceService();
    }
    return VoiceService.instance;
  }

  private engine: speechRecognizer.SpeechRecognitionEngine | null = null;
  /** 进行中的初始化。并发调用要复用同一个，否则会创建出两个引擎 */
  private initPromise: Promise<boolean> | null = null;
  private capturer: audio.AudioCapturer | null = null;
  private sessionId: string = '';
  private recording: boolean = false;
  private shutdown: boolean = false;

  /** 累积的音频字节，凑够 WRITE_CHUNK_BYTES 才发一包 */
  private pending: Uint8Array = new Uint8Array(0);
  /** 已发出的音频包数，用于诊断 */
  private sentChunks: number = 0;

  private partialText: string = '';
  private finalText: string = '';
  private onPartial: ((text: string, isFinal: boolean) => void) | null = null;
  private onCompleteResolve: (() => void) | null = null;

  /**
   * 申请麦克风权限。
   *
   * 麦克风是敏感权限，光在 module.json5 里声明不够，必须运行时弹窗申请。
   * （旧实现的 checkPermission() 直接 return true，是假的。）
   */
  async ensureMicrophonePermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const permissions: Array<Permissions> = ['ohos.permission.MICROPHONE'];
      const result: PermissionRequestResult =
        await atManager.requestPermissionsFromUser(context, permissions);

      if (result.authResults.length > 0 && result.authResults[0] === 0) {
        return true;
      }
      hilog.warn(0x0000, TAG, 'microphone permission denied by user');
      return false;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, TAG, 'request permission failed: code=%{public}d, msg=%{public}s',
        err.code, err.message);
      return false;
    }
  }

  /**
   * 自检：分别试着创建离线和在线引擎，报告哪条路能走通。
   *
   * 之所以要这个：离线模式依赖设备上预装的中文语言包，这个没法从代码里
   * 推断，只能实际建一次引擎才知道。建得起来就说明能用。
   */
  async probe(): Promise<VoiceProbeResult> {
    const result: VoiceProbeResult = { offlineOk: false, onlineOk: false, detail: '' };

    // 先释放当前实例占着的引擎，否则和 ASR 系统服务的单引擎约束冲突
    this.release();

    result.offlineOk = await this.tryCreateEngine(1);
    result.detail += `offline(online=1): ${result.offlineOk ? 'OK' : 'FAIL'}\n`;

    result.onlineOk = await this.tryCreateEngine(0);
    result.detail += `online(online=0): ${result.onlineOk ? 'OK' : 'FAIL'}`;

    hilog.info(0x0000, TAG, 'probe result: %{public}s', result.detail);
    return result;
  }

  private async tryCreateEngine(online: number): Promise<boolean> {
    return await this.tryCreateEngineWith(this.currentLanguage(), online);
  }

  /**
   * 探测某个语言在本机能不能做语音识别。不落盘、不改设置，纯粹试一次。
   *
   * 和 TTS 是同一个道理：设备的语音资源**按语言**安装，能不能用只能实际建一次
   * 引擎才知道。实测这台 MatePad 只装了中文离线识别资源 —— 把识别语言设成英文后
   * `createEngine` 报 `1002200001 Asr CreateEngineParams is wrong`，
   * 表现为**麦克风按钮按下去毫无反应**（长按有动画，但一个字都识别不出来），
   * 而界面上完全看不出原因。所以存语言之前必须先探测。
   *
   * 离线或在线任一条能建起来就算可用。
   */
  async canRecognize(language: string): Promise<boolean> {
    // 先释放当前引擎 —— ASR 是系统服务，全局只允许一个实例
    this.release();
    if (await this.tryCreateEngineWith(language, 1)) {
      return true;
    }
    return await this.tryCreateEngineWith(language, 0);
  }

  private async tryCreateEngineWith(language: string, online: number): Promise<boolean> {
    try {
      const params: speechRecognizer.CreateEngineParams = {
        language: language,
        online: online
      };
      const engine: speechRecognizer.SpeechRecognitionEngine =
        await speechRecognizer.createEngine(params);
      engine.shutdown();
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(0x0000, TAG,
        'createEngine(%{public}s, online=%{public}d) failed: code=%{public}d, msg=%{public}s',
        language, online, err.code, err.message);
      return false;
    }
  }

  /**
   * 初始化识别引擎。优先离线，失败退回在线。
   *
   * 并发安全：初始化期间再次调用会复用同一个 Promise。之前这里是裸的
   * `if (engine !== null) return true`，两次并发调用会各自建一个引擎，
   * 结果一个拿了 listener、另一个被用来 startListening，
   * ASR 服务直接报 "start listening failed, no preceding init"。
   */
  async initialize(): Promise<boolean> {
    // 语言设置变了就重建引擎，否则还在用旧语言识别
    if (this.engine !== null && this.engineLanguage !== this.currentLanguage()) {
      hilog.info(0x0000, TAG, 'language changed, rebuilding engine');
      this.invalidateEngine();
    }
    if (this.engine !== null) {
      return true;
    }
    if (this.initPromise !== null) {
      return await this.initPromise;
    }

    this.initPromise = this.doInitialize();
    const ok: boolean = await this.initPromise;
    this.initPromise = null;
    return ok;
  }

  private async doInitialize(): Promise<boolean> {
    if (await this.createWithMode(1)) {
      return true;
    }
    hilog.warn(0x0000, TAG, 'offline engine unavailable, falling back to online');
    return await this.createWithMode(0);
  }

  private async createWithMode(online: number): Promise<boolean> {
    try {
      const language: string = this.currentLanguage();
      const params: speechRecognizer.CreateEngineParams = {
        language: language,
        online: online
      };
      const engine: speechRecognizer.SpeechRecognitionEngine =
        await speechRecognizer.createEngine(params);
      this.attachListener(engine);
      this.engine = engine;
      this.shutdown = false;
      this.engineLanguage = language;
      hilog.info(0x0000, TAG, 'engine ready, language=%{public}s online=%{public}d', language, online);
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, TAG, 'create engine failed: code=%{public}d, msg=%{public}s',
        err.code, err.message);
      return false;
    }
  }

  /**
   * 识别语言从设置里读，改动后下次初始化生效
   */
  private currentLanguage(): string {
    return SettingsStore.getInstance().getRecognizeLanguage();
  }

  /**
   * 语言设置变了要让引擎重建，否则还是用旧语言识别
   */
  private engineLanguage: string = '';

  invalidateEngine(): void {
    this.release();
    this.engineLanguage = '';
  }

  private attachListener(engine: speechRecognizer.SpeechRecognitionEngine): void {
    engine.setListener({
      onStart: (sessionId: string, eventMessage: string) => {
        hilog.info(0x0000, TAG, 'onStart: %{public}s', sessionId);
      },
      onEvent: (sessionId: string, eventCode: number, eventMessage: string) => {
        hilog.debug(0x0000, TAG, 'onEvent %{public}d: %{public}s', eventCode, eventMessage);
      },
      onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
        hilog.info(0x0000, TAG, 'onResult final=%{public}s text=%{public}s',
          result.isFinal.toString(), result.result);
        if (result.isFinal) {
          this.finalText = result.result;
        } else {
          this.partialText = result.result;
        }
        if (this.onPartial !== null) {
          this.onPartial(result.result, result.isFinal);
        }
      },
      onComplete: (sessionId: string, eventMessage: string) => {
        hilog.info(0x0000, TAG, 'onComplete');
        this.stopFeeding();
        this.notifyComplete();
      },
      onError: (sessionId: string, errorCode: number, errorMessage: string) => {
        hilog.error(0x0000, TAG, 'onError %{public}d: %{public}s', errorCode, errorMessage);
        this.stopFeeding();
        this.notifyComplete();
      }
    });
  }

  /**
   * 停止向引擎喂音频，但保留已识别出的文本。
   *
   * 必须做这件事：引擎靠 VAD 判断说话结束，会在用户松手之前就自己 onComplete。
   * 如果采集循环还继续 writeAudio，会一路报 1002200010
   * （Write audio failed because the start listening is failed），
   * 采集器最后还会 read 失败（6800301 system error）。
   */
  private stopFeeding(): void {
    if (!this.recording) {
      return;
    }
    hilog.info(0x0000, TAG, 'engine finished, stopping capture after %{public}d chunks', this.sentChunks);
    this.recording = false;
    this.releaseCapture();
  }

  /**
   * 开始录音并实时识别
   *
   * @param onPartial 中间结果回调（isFinal=false 是临时结果，true 是本句最终结果）
   */
  async startRecording(onPartial: (text: string, isFinal: boolean) => void): Promise<boolean> {
    if (this.recording) {
      return false;
    }

    const ready: boolean = await this.initialize();
    if (!ready || this.engine === null) {
      hilog.error(0x0000, TAG, 'engine not available');
      return false;
    }
    if (this.engine.isBusy()) {
      hilog.warn(0x0000, TAG, 'engine busy');
      return false;
    }

    try {
      this.partialText = '';
      this.finalText = '';
      this.pending = new Uint8Array(0);
      this.sentChunks = 0;
      this.onPartial = onPartial;
      this.sessionId = `session_${Date.now()}`;

      const audioInfo: speechRecognizer.AudioInfo = {
        audioType: 'pcm',
        sampleRate: SAMPLE_RATE,
        soundChannel: 1,
        sampleBit: 16
      };
      const startParams: speechRecognizer.StartParams = {
        sessionId: this.sessionId,
        audioInfo: audioInfo
      };

      // 必须在启动采集循环之前置位 —— readLoop 的 while 条件读的就是它，
      // 置晚了循环会一次都不进就退出，音频一个字节都喂不进去
      this.recording = true;

      this.engine.startListening(startParams);
      await this.startCapture();
      hilog.info(0x0000, TAG, 'Recording started');
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, TAG, 'startRecording failed: code=%{public}d, msg=%{public}s',
        err.code, err.message);
      this.recording = false;
      await this.releaseCapture();
      return false;
    }
  }

  private async startCapture(): Promise<void> {
    const options: audio.AudioCapturerOptions = {
      streamInfo: {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      },
      capturerInfo: {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      }
    };

    this.capturer = await audio.createAudioCapturer(options);
    await this.capturer.start();
    this.readLoop();
  }

  /**
   * 采集循环：读一块 → 攒够 640 字节就喂给引擎
   *
   * 不能读一块发一块 —— writeAudio 对长度有硬性要求（640 或 1280），
   * 而 AudioCapturer 每次返回多少字节是不保证的。
   */
  private async readLoop(): Promise<void> {
    while (this.recording && this.capturer !== null) {
      try {
        const buffer: ArrayBuffer = await this.capturer.read(WRITE_CHUNK_BYTES, true);
        this.feed(buffer);
      } catch (error) {
        const err = error as BusinessError;
        hilog.error(0x0000, TAG, 'read failed: code=%{public}d, msg=%{public}s', err.code, err.message);
        break;
      }
    }
  }

  private feed(chunk: ArrayBuffer): void {
    const incoming: Uint8Array = new Uint8Array(chunk);
    const merged: Uint8Array = new Uint8Array(this.pending.length + incoming.length);
    merged.set(this.pending, 0);
    merged.set(incoming, this.pending.length);
    this.pending = merged;

    while (this.pending.length >= WRITE_CHUNK_BYTES) {
      const piece: Uint8Array = this.pending.slice(0, WRITE_CHUNK_BYTES);
      this.pending = this.pending.slice(WRITE_CHUNK_BYTES);
      if (this.engine !== null) {
        try {
          this.engine.writeAudio(this.sessionId, piece);
          this.sentChunks++;
          // 每约 1 秒（16kHz 单声道下 640 字节 ≈ 20ms）打一条，确认音频确实在流动
          if (this.sentChunks % 50 === 0) {
            hilog.info(0x0000, TAG, 'audio flowing: %{public}d chunks sent', this.sentChunks);
          }
        } catch (error) {
          const err = error as BusinessError;
          hilog.error(0x0000, TAG, 'writeAudio failed: code=%{public}d', err.code);
          return;
        }
      }
    }
  }

  /**
   * 停止录音，等引擎吐完最后一段结果后返回最终文本
   */
  async stopRecording(): Promise<string> {
    if (!this.recording) {
      return this.finalText.length > 0 ? this.finalText : this.partialText;
    }

    this.recording = false;
    await this.releaseCapture();

    if (this.engine !== null) {
      try {
        const done: Promise<void> = new Promise<void>((resolve: () => void) => {
          this.onCompleteResolve = resolve;
        });
        this.engine.finish(this.sessionId);
        await this.raceTimeout(done, FINISH_TIMEOUT_MS);
      } catch (error) {
        const err = error as BusinessError;
        hilog.error(0x0000, TAG, 'finish failed: code=%{public}d', err.code);
      }
    }

    const text: string = this.finalText.length > 0 ? this.finalText : this.partialText;
    hilog.info(0x0000, TAG, 'stopRecording done: chunks=%{public}d, len=%{public}d',
      this.sentChunks, text.length);
    return text;
  }

  /**
   * 取消本次录音，不等待识别结果
   */
  async cancelRecording(): Promise<void> {
    this.recording = false;
    await this.releaseCapture();

    if (this.engine !== null && this.sessionId.length > 0) {
      try {
        this.engine.cancel(this.sessionId);
      } catch (error) {
        const err = error as BusinessError;
        hilog.warn(0x0000, TAG, 'cancel failed: code=%{public}d', err.code);
      }
    }
    this.sessionId = '';
  }

  isCurrentlyRecording(): boolean {
    return this.recording;
  }

  /**
   * 释放引擎资源（页面销毁时调用）
   */
  release(): void {
    if (this.shutdown || this.engine === null) {
      return;
    }
    this.recording = false;
    this.shutdown = true;
    try {
      this.engine.shutdown();
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(0x0000, TAG, 'shutdown failed: code=%{public}d', err.code);
    }
    this.engine = null;
    this.capturer = null;
  }

  private async releaseCapture(): Promise<void> {
    if (this.capturer === null) {
      return;
    }
    const capturer: audio.AudioCapturer = this.capturer;
    this.capturer = null;
    try {
      await capturer.stop();
      await capturer.release();
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(0x0000, TAG, 'release capturer failed: code=%{public}d', err.code);
    }
  }

  private notifyComplete(): void {
    if (this.onCompleteResolve !== null) {
      const resolve: () => void = this.onCompleteResolve;
      this.onCompleteResolve = null;
      resolve();
    }
  }

  /**
   * 给一个 Promise 加超时，避免引擎无响应时界面一直卡着
   */
  private raceTimeout(work: Promise<void>, ms: number): Promise<void> {
    const timeout: Promise<void> = new Promise<void>((resolve: () => void) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
    return Promise.race([work, timeout]);
  }
}
