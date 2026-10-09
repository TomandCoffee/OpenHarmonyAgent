import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ApiKeyStore } from './ApiKeyStore';
import {
  ChatMessage,
  ChatRequestBody,
  ChatResponse,
  ThinkingConfig,
  SSEChunk,
  SSEDelta,
  APIErrorBody
} from '../models/LLM';

const TAG = 'LLMService';

const CHAT_URL = 'https://api.deepseek.com/chat/completions';
const MODEL = 'deepseek-flash';
const MAX_TOKENS = 2048;
const CONNECT_TIMEOUT = 15000;
const READ_TIMEOUT = 90000;

/**
 * 一次流式请求的结果。
 * 不抛异常 —— 无论成功失败，调用方手里总要有点东西能显示到聊天气泡里。
 */
export interface StreamOutcome {
  /** 已经收到的正文（可能为空） */
  content: string;
  /** 空字符串表示成功；非空则是给用户看的提示 */
  errorMessage: string;
}

/**
 * 把网络分片拼成完整的 SSE 事件流。
 *
 * 两个必须做对的地方：
 *   1. 必须用 TextDecoder 的 stream 模式解码 —— 一个中文字符占 3 字节，
 *      会被 TCP 分片切开，用 String.fromCharCode 之类的做法必然乱码。
 *   2. 必须按 \n\n 只切「完整事件」，半截的留在 buffer 里等下一个分片 ——
 *      一个 JSON 帧同样可能被切成两半。
 */
class SSEParser {
  private decoder: util.TextDecoder = new util.TextDecoder('utf-8');
  private buffer: string = '';
  /** 收到的全部原始文本，用于非 200 时解析错误体 */
  rawText: string = '';
  /** 是否收到了 data: [DONE] */
  sawDone: boolean = false;

  /**
   * 喂入一个网络分片，返回本次解析出的全部文本增量
   */
  feed(chunk: ArrayBuffer): string[] {
    const deltas: string[] = [];

    let text: string = this.decoder.decodeToString(new Uint8Array(chunk), { stream: true });
    // SSE 的行终止符可能是 \r\n，也可能是 \n。JSON 里的换行都是转义序列，
    // 不会出现裸的 \r 字节，所以直接抹掉是安全的。
    text = text.replace(/\r/g, '');
    this.rawText += text;
    this.buffer += text;

    let idx: number = this.buffer.indexOf('\n\n');
    while (idx >= 0) {
      const event: string = this.buffer.substring(0, idx);
      this.buffer = this.buffer.substring(idx + 2);

      const delta: string = this.parseEvent(event);
      if (delta.length > 0) {
        deltas.push(delta);
      }
      idx = this.buffer.indexOf('\n\n');
    }

    return deltas;
  }

  /**
   * 解析一个完整事件，返回其中的文本增量（没有则返回空串）
   */
  private parseEvent(event: string): string {
    const lines: string[] = event.split('\n');
    let payload: string = '';

    for (const line of lines) {
      const trimmed: string = line.trim();
      if (trimmed.startsWith('data:')) {
        payload += trimmed.substring(5).trim();
      }
    }

    if (payload.length === 0) {
      return '';
    }
    if (payload === '[DONE]') {
      this.sawDone = true;
      return '';
    }

    try {
      const chunk: SSEChunk = JSON.parse(payload) as SSEChunk;
      if (chunk.choices !== undefined && chunk.choices.length > 0) {
        const delta: SSEDelta | undefined = chunk.choices[0].delta;
        if (delta !== undefined && delta.content !== undefined && delta.content.length > 0) {
          return delta.content;
        }
      }
    } catch (err) {
      // 解析失败说明这一帧不是预期格式（比如服务端的错误帧），跳过即可
      hilog.warn(0x0000, TAG, 'SSE frame parse failed: %{public}s', payload.substring(0, 120));
    }
    return '';
  }
}

/**
 * DeepSeek 客户端（单例）
 *
 * 只用到了 OpenAI 兼容的两个接口：
 *   - chatStream：流式对话，边收边回调
 *   - ping：非流式的一次最小请求，给设置页的「测试连接」用
 */
export class LLMService {
  private static instance: LLMService | null = null;

  static getInstance(): LLMService {
    if (LLMService.instance === null) {
      LLMService.instance = new LLMService();
    }
    return LLMService.instance;
  }

  /**
   * Key 只从 ApiKeyStore 读，避免两处状态不一致
   */
  private currentKey(): string {
    return ApiKeyStore.getInstance().getApiKey();
  }

  isConfigured(): boolean {
    return ApiKeyStore.getInstance().hasKey();
  }

  /**
   * 流式对话。每收到一段增量就回调 onDelta，全部结束后返回完整结果。
   */
  async chatStream(messages: ChatMessage[], onDelta: (delta: string) => void): Promise<StreamOutcome> {
    const key: string = this.currentKey();
    if (key.trim().length === 0) {
      return { content: '', errorMessage: '还没设置 API Key。请点右上角齿轮进「AI 模型」填一个 DeepSeek Key。' };
    }

    const parser: SSEParser = new SSEParser();
    const request = http.createHttp();
    let fullContent: string = '';

    const dataCallback = (chunk: ArrayBuffer): void => {
      const deltas: string[] = parser.feed(chunk);
      for (const delta of deltas) {
        fullContent += delta;
        onDelta(delta);
      }
    };

    try {
      request.on('dataReceive', dataCallback);

      const body: ChatRequestBody = {
        model: MODEL,
        messages: messages,
        thinking: { type: 'disabled' } as ThinkingConfig,
        stream: true,
        max_tokens: MAX_TOKENS
      };

      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'Authorization': `Bearer ${key}`
      };

      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(body),
        connectTimeout: CONNECT_TIMEOUT,
        readTimeout: READ_TIMEOUT
      };

      const code: number = await request.requestInStream(CHAT_URL, options);

      if (code !== 200) {
        return {
          content: fullContent,
          errorMessage: LLMService.describeError(code, parser.rawText)
        };
      }

      // 正常结束但没看到 [DONE]，多半是中途被断开了
      if (!parser.sawDone && fullContent.length > 0) {
        return { content: fullContent + '\n\n(回答中断)', errorMessage: '' };
      }

      return { content: fullContent, errorMessage: '' };
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'chatStream failed: %{public}s', err.message);

      if (fullContent.length > 0) {
        // 已经吐了一部分内容，保留它，末尾标注中断
        return { content: fullContent + '\n\n(回答中断)', errorMessage: '' };
      }
      return { content: '', errorMessage: `网络请求失败：${err.message}` };
    } finally {
      request.off('dataReceive', dataCallback);
      request.destroy();
    }
  }

  /**
   * 用给定的 Key 发一次最小请求，验证 Key 是否可用。
   * 返回空字符串表示成功，否则是错误提示。
   */
  async ping(apiKey: string): Promise<string> {
    const trimmed: string = apiKey.trim();
    if (trimmed.length === 0) {
      return '请先填入 API Key。';
    }

    const request = http.createHttp();
    try {
      const body: ChatRequestBody = {
        model: MODEL,
        messages: [{ role: 'user', content: 'ok' } as ChatMessage],
        thinking: { type: 'disabled' } as ThinkingConfig,
        stream: false,
        max_tokens: 1
      };

      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${trimmed}`
      };

      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(body),
        connectTimeout: CONNECT_TIMEOUT,
        readTimeout: 30000
      };

      const response: http.HttpResponse = await request.request(CHAT_URL, options);
      const code: number = response.responseCode as number;
      const text: string = typeof response.result === 'string' ? response.result as string : '';

      if (code === 200) {
        // 顺便确认返回体里确实是我们认识的格式
        try {
          const parsed: ChatResponse = JSON.parse(text) as ChatResponse;
          if (parsed.choices !== undefined && parsed.choices.length > 0) {
            return '';
          }
          return '连接成功，但返回格式不符合预期。';
        } catch (parseErr) {
          return '连接成功，但返回内容无法解析。';
        }
      }
      return LLMService.describeError(code, text);
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'ping failed: %{public}s', err.message);
      return `网络请求失败：${err.message}`;
    } finally {
      request.destroy();
    }
  }

  /**
   * 把 HTTP 状态码翻译成用户能看懂的话
   */
  private static describeError(code: number, body: string): string {
    if (code === 401) {
      return 'API Key 无效，请到「设置 → 模型设置」检查。';
    }
    if (code === 402) {
      return 'DeepSeek 账户余额不足，请先充值。';
    }
    if (code === 429) {
      return '请求太频繁了，稍等一会儿再试。';
    }
    if (code === 400) {
      return '请求格式有误，可能是模型名或参数不对。';
    }
    if (code >= 500) {
      return `DeepSeek 服务端错误（HTTP ${code}），稍后再试。`;
    }

    try {
      const errBody: APIErrorBody = JSON.parse(body) as APIErrorBody;
      if (errBody.error !== undefined && errBody.error.message !== undefined
        && errBody.error.message.length > 0) {
        return `请求失败（HTTP ${code}）：${errBody.error.message}`;
      }
    } catch (parseErr) {
      // body 不是 JSON，走下面的兜底
    }
    return `请求失败（HTTP ${code}）。`;
  }
}
