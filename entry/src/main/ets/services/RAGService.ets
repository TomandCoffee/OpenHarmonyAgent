import { hilog } from '@kit.PerformanceAnalysisKit';
import { KnowledgeItem } from '../models/Message';

const TAG = 'RAGService';

/**
 * 知识库统计信息
 */
export interface KnowledgeStats {
  total: number;
  types: Record<string, number>;
}

/**
 * RAG 知识库服务
 *
 * 当前实现：端侧内存索引 + 关键词打分检索，不依赖任何系统 AI 能力，手机 / 平板 / PC 都能跑。
 *
 * TODO（第二阶段 · 接入鸿蒙端侧检索能力）：
 *   使用 @kit.DataAugmentationKit 的 retrieval 子模块替换本文件里的内存索引：
 *     const retriever = await retrieval.getRetriever({ channelConfigs: [...] });  // 需要 Context
 *     const records = await retriever.retrieveRdb(query, condition);
 *   入库侧用 knowledgeProcessor.getKnowledgeProcessor(context, config)。
 *   注意：该 Kit 的 rag / localChatModel 子模块仅支持 PC/2in1 设备，
 *   手机与平板不可用（SystemCapability.DataAugmentation.RAG 不在平板的 syscap 里），
 *   所以平板上的"回答"这一步需要自行接入大模型。
 */
export class RAGService {
  private isInitialized: boolean = false;
  private knowledgeIndex: Map<string, KnowledgeItem> = new Map();

  /**
   * 初始化 RAG 引擎
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      // TODO: 第二阶段在这里初始化 retrieval 检索器并加载已持久化的知识
      this.isInitialized = true;
      hilog.info(0x0000, TAG, 'RAGService initialized (memory index)');
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'Failed to initialize RAGService: %{public}s', err.message);
    }
  }

  /**
   * 添加知识条目
   */
  async addKnowledge(item: KnowledgeItem): Promise<boolean> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    try {
      this.knowledgeIndex.set(item.id, item);
      hilog.info(0x0000, TAG, 'Knowledge added: %{public}s', item.id);
      return true;
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'Failed to add knowledge: %{public}s', err.message);
      return false;
    }
  }

  /**
   * 检索相关知识
   */
  async retrieve(query: string, topK: number = 5): Promise<KnowledgeItem[]> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    const queryTokens: string[] = this.tokenize(query);
    if (queryTokens.length === 0) {
      return [];
    }

    const scored: KnowledgeItem[] = [];
    const scores: number[] = [];

    this.knowledgeIndex.forEach((item: KnowledgeItem) => {
      const score: number = this.score(queryTokens, item);
      if (score > 0) {
        scored.push(item);
        scores.push(score);
      }
    });

    // 按得分从高到低排序（item 与 score 同步交换）
    for (let i = 0; i < scores.length; i++) {
      for (let j = i + 1; j < scores.length; j++) {
        if (scores[j] > scores[i]) {
          const tmpScore: number = scores[i];
          scores[i] = scores[j];
          scores[j] = tmpScore;

          const tmpItem: KnowledgeItem = scored[i];
          scored[i] = scored[j];
          scored[j] = tmpItem;
        }
      }
    }

    const result: KnowledgeItem[] = scored.slice(0, topK);
    hilog.info(0x0000, TAG, 'Retrieved %{public}d knowledge items', result.length);
    return result;
  }

  /**
   * 语义问答
   */
  async questionAnswering(question: string): Promise<string> {
    const relevantKnowledge: KnowledgeItem[] = await this.retrieve(question, 3);

    if (relevantKnowledge.length === 0) {
      return '抱歉，我的知识库中暂时没有相关信息。你可以添加新的知识条目来帮助我学习。';
    }

    let context: string = '';
    for (let i = 0; i < relevantKnowledge.length; i++) {
      context += `[${i + 1}] ${relevantKnowledge[i].content}\n\n`;
    }

    // TODO: 第二阶段接入大模型后，把 context 作为提示词发给模型生成回答
    return `根据我的知识库：

${context}**检索到以上 ${relevantKnowledge.length} 条相关内容**。
（当前为本地关键词检索，接入大模型后这里会给出生成式回答。）`;
  }

  /**
   * 获取全部知识（供知识库页面展示）
   */
  getAllKnowledge(): KnowledgeItem[] {
    const all: KnowledgeItem[] = [];
    this.knowledgeIndex.forEach((item: KnowledgeItem) => {
      all.push(item);
    });
    // 按时间倒序，最新的排在前面
    all.sort((a: KnowledgeItem, b: KnowledgeItem) => b.timestamp - a.timestamp);
    return all;
  }

  /**
   * 删除知识条目
   */
  async removeKnowledge(id: string): Promise<boolean> {
    try {
      const removed: boolean = this.knowledgeIndex.delete(id);
      hilog.info(0x0000, TAG, 'Knowledge removed: %{public}s', id);
      return removed;
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, TAG, 'Failed to remove knowledge: %{public}s', err.message);
      return false;
    }
  }

  /**
   * 获取知识库统计
   */
  getKnowledgeStats(): KnowledgeStats {
    const types: Record<string, number> = {};
    this.knowledgeIndex.forEach((item: KnowledgeItem) => {
      const current: number = types[item.type] ?? 0;
      types[item.type] = current + 1;
    });

    return { total: this.knowledgeIndex.size, types: types };
  }

  /**
   * 批量添加知识
   */
  async batchAddKnowledge(items: KnowledgeItem[]): Promise<number> {
    let successCount: number = 0;
    for (const item of items) {
      const ok: boolean = await this.addKnowledge(item);
      if (ok) {
        successCount++;
      }
    }
    return successCount;
  }

  /**
   * 清空知识库
   */
  async clearKnowledgeBase(): Promise<void> {
    this.knowledgeIndex.clear();
    hilog.info(0x0000, TAG, 'Knowledge base cleared');
  }

  /**
   * 把查询/内容切成可比较的词元。
   * 英文和数字按单词切，中日韩字符按 2-gram 切（中文没有空格，二元组是最省事的近似）。
   */
  private tokenize(text: string): string[] {
    const tokens: string[] = [];
    const lower: string = text.toLowerCase();

    let latinRun: string = '';
    let cjkRun: string = '';

    for (let i = 0; i < lower.length; i++) {
      const ch: string = lower.charAt(i);
      const code: number = lower.charCodeAt(i);
      const isLatin: boolean = (code >= 0x30 && code <= 0x39) || (code >= 0x61 && code <= 0x7a);
      const isCjk: boolean = code >= 0x4e00 && code <= 0x9fff;

      if (isLatin) {
        if (cjkRun.length > 0) {
          this.pushCjkTokens(tokens, cjkRun);
          cjkRun = '';
        }
        latinRun += ch;
      } else if (isCjk) {
        if (latinRun.length > 0) {
          tokens.push(latinRun);
          latinRun = '';
        }
        cjkRun += ch;
      } else {
        if (latinRun.length > 0) {
          tokens.push(latinRun);
          latinRun = '';
        }
        if (cjkRun.length > 0) {
          this.pushCjkTokens(tokens, cjkRun);
          cjkRun = '';
        }
      }
    }

    if (latinRun.length > 0) {
      tokens.push(latinRun);
    }
    if (cjkRun.length > 0) {
      this.pushCjkTokens(tokens, cjkRun);
    }

    return tokens;
  }

  private pushCjkTokens(tokens: string[], run: string): void {
    if (run.length === 1) {
      tokens.push(run);
      return;
    }
    for (let i = 0; i + 2 <= run.length; i++) {
      tokens.push(run.substring(i, i + 2));
    }
  }

  /**
   * 计算某条知识与查询词的重合度（命中词元占比，0~1）
   */
  private score(queryTokens: string[], item: KnowledgeItem): number {
    let haystack: string = item.content.toLowerCase();
    for (const tag of item.tags) {
      haystack += ` ${tag.toLowerCase()}`;
    }

    let hits: number = 0;
    for (const token of queryTokens) {
      if (haystack.includes(token)) {
        hits++;
      }
    }
    return hits / queryTokens.length;
  }
}
