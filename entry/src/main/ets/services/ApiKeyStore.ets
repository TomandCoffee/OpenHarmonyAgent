import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'ApiKeyStore';

const STORE_NAME = 'agent_config';
const KEY_API = 'deepseek_api_key';

/**
 * API Key 的本地存储（单例）
 *
 * 用 preferences 落盘，Key 只存在设备上，不进代码、不进版本库。
 * Context 由 EntryAbility.onCreate 注入 —— 服务层拿不到组件上下文，
 * 全局 getContext() 又已经在 API 18 废弃了，所以统一从这里取。
 */
export class ApiKeyStore {
  private static instance: ApiKeyStore | null = null;
  private prefs: preferences.Preferences | null = null;
  private apiKey: string = '';

  static getInstance(): ApiKeyStore {
    if (ApiKeyStore.instance === null) {
      ApiKeyStore.instance = new ApiKeyStore();
    }
    return ApiKeyStore.instance;
  }

  /**
   * 初始化并读出已保存的 Key。重复调用是安全的。
   */
  async init(context: common.Context): Promise<void> {
    if (this.prefs !== null) {
      return;
    }
    try {
      const options: preferences.Options = { name: STORE_NAME };
      this.prefs = await preferences.getPreferences(context, options);

      const raw: preferences.ValueType = await this.prefs.get(KEY_API, '');
      this.apiKey = typeof raw === 'string' ? raw as string : '';
      hilog.info(0x0000, TAG, 'ApiKeyStore ready, hasKey: %{public}s', (this.apiKey.length > 0).toString());
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'init failed: %{public}s', err.message);
    }
  }

  isReady(): boolean {
    return this.prefs !== null;
  }

  getApiKey(): string {
    return this.apiKey;
  }

  hasKey(): boolean {
    return this.apiKey.trim().length > 0;
  }

  /**
   * 生成用于界面显示的掩码，例如 sk-ab****cd12
   */
  maskKey(): string {
    const key: string = this.apiKey;
    if (key.length === 0) {
      return '';
    }
    if (key.length <= 12) {
      return '****';
    }
    return `${key.substring(0, 5)}****${key.substring(key.length - 4)}`;
  }

  async setApiKey(key: string): Promise<void> {
    this.apiKey = key.trim();
    if (this.prefs !== null) {
      await this.prefs.put(KEY_API, this.apiKey);
      await this.prefs.flush();
    }
  }

  async clearApiKey(): Promise<void> {
    this.apiKey = '';
    if (this.prefs !== null) {
      await this.prefs.put(KEY_API, '');
      await this.prefs.flush();
    }
  }
}
