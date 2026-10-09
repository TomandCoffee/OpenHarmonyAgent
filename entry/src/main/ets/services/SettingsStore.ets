import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'SettingsStore';

/** 和 ApiKeyStore 共用同一个 preferences 库，只是键不同 */
const STORE_NAME = 'agent_config';

const KEY_RECOGNIZE_LANG = 'language.recognize';
const KEY_SPEAK_LANG = 'language.speak';
const KEY_SPEAK_PERSON = 'language.speakPerson';
const KEY_REPLY_LANG = 'language.reply';
const KEY_MUTED = 'audio.muted';

/** 支持的语言。加语言只要在这里补一行，各处下拉和 prompt 选择会自动跟上 */
export interface LanguageOption {
  code: string;
  label: string;
}

export const LANGUAGE_OPTIONS: LanguageOption[] = [
  { code: 'zh-CN', label: '中文' },
  { code: 'en-US', label: 'English' }
];

/**
 * 通用设置存储（单例）
 *
 * 和 ApiKeyStore 分开写：那个聚焦「凭证」，这个聚焦「偏好」。
 * 两者共用同一个 preferences 库，互不干扰。
 *
 * 之所以需要它：设置页原来的开关全是 @State，退出页面就丢 ——
 * 语言这种跨页面、跨启动都要一致的设置必须落盘。
 */
export class SettingsStore {
  private static instance: SettingsStore | null = null;

  static getInstance(): SettingsStore {
    if (SettingsStore.instance === null) {
      SettingsStore.instance = new SettingsStore();
    }
    return SettingsStore.instance;
  }

  private prefs: preferences.Preferences | null = null;

  // 内存缓存（设置项少且变更不频繁，读缓存足够；写入时同步更新）
  private recognizeLang: string = 'zh-CN';
  private speakLang: string = 'zh-CN';
  private speakPerson: number = 0;
  private replyLang: string = 'zh-CN';
  private muted: boolean = false;

  async init(context: common.Context): Promise<void> {
    if (this.prefs !== null) {
      return;
    }
    try {
      const options: preferences.Options = { name: STORE_NAME };
      this.prefs = await preferences.getPreferences(context, options);

      this.recognizeLang = await this.readString(KEY_RECOGNIZE_LANG, 'zh-CN');
      this.speakLang = await this.readString(KEY_SPEAK_LANG, 'zh-CN');
      this.speakPerson = await this.readNumber(KEY_SPEAK_PERSON, 0);
      this.replyLang = await this.readString(KEY_REPLY_LANG, 'zh-CN');
      this.muted = await this.readBoolean(KEY_MUTED, false);

      hilog.info(0x0000, TAG, 'loaded: recognize=%{public}s speak=%{public}s reply=%{public}s muted=%{public}s',
        this.recognizeLang, this.speakLang, this.replyLang, this.muted.toString());
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'init failed: %{public}s', err.message);
    }
  }

  private async readString(key: string, def: string): Promise<string> {
    if (this.prefs === null) {
      return def;
    }
    const raw: preferences.ValueType = await this.prefs.get(key, def);
    return typeof raw === 'string' ? raw as string : def;
  }

  private async readNumber(key: string, def: number): Promise<number> {
    if (this.prefs === null) {
      return def;
    }
    const raw: preferences.ValueType = await this.prefs.get(key, def);
    return typeof raw === 'number' ? raw as number : def;
  }

  private async readBoolean(key: string, def: boolean): Promise<boolean> {
    if (this.prefs === null) {
      return def;
    }
    const raw: preferences.ValueType = await this.prefs.get(key, def);
    return typeof raw === 'boolean' ? raw as boolean : def;
  }

  private async write(key: string, value: preferences.ValueType): Promise<void> {
    if (this.prefs === null) {
      hilog.warn(0x0000, TAG, 'prefs not ready, %{public}s not persisted', key);
      return;
    }
    await this.prefs.put(key, value);
    await this.prefs.flush();
  }

  // ─────────── 语音识别语言 ───────────

  getRecognizeLanguage(): string {
    return this.recognizeLang;
  }

  async setRecognizeLanguage(code: string): Promise<void> {
    this.recognizeLang = code;
    await this.write(KEY_RECOGNIZE_LANG, code);
  }

  // ─────────── 播报语言与音色 ───────────

  getSpeakLanguage(): string {
    return this.speakLang;
  }

  getSpeakPerson(): number {
    return this.speakPerson;
  }

  async setSpeakVoice(language: string, person: number): Promise<void> {
    this.speakLang = language;
    this.speakPerson = person;
    await this.write(KEY_SPEAK_LANG, language);
    await this.write(KEY_SPEAK_PERSON, person);
  }

  // ─────────── 回复语言 ───────────

  getReplyLanguage(): string {
    return this.replyLang;
  }

  async setReplyLanguage(code: string): Promise<void> {
    this.replyLang = code;
    await this.write(KEY_REPLY_LANG, code);
  }

  /**
   * 给 prompt 用的语言指令。
   *
   * 这段会被拼在**本轮 user 消息的末尾**（见 AgentPrompts.buildUserContent），
   * 而不是 system —— 实测 system 里的语言指令会被中文对话历史压过去，
   * 放到离生成点最近的 user 消息尾部才生效。
   *
   * 措辞保持极简：短促的方括号指令实测比长句更稳。
   */
  getReplyLanguageDirective(): string {
    if (this.replyLang.startsWith('en')) {
      return '\n\n【Answer in English】';
    }
    return '';
  }

  /**
   * 全局静音偏好。TTSService 启动时读它，切换时写它。
   */
  isMuted(): boolean {
    return this.muted;
  }

  async setMuted(value: boolean): Promise<void> {
    this.muted = value;
    await this.write(KEY_MUTED, value);
  }

  /**
   * 把语言码翻译成人类可读的名字，用于界面显示
   */
  static labelOf(code: string): string {
    for (const option of LANGUAGE_OPTIONS) {
      if (option.code === code) {
        return option.label;
      }
    }
    return code;
  }
}
