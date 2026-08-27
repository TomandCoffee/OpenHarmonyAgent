/**
 * 应用常量定义
 */
export class Constants {
  // 应用配置
  static readonly APP_NAME = 'OpenHarmony Agent';
  static readonly APP_VERSION = '1.0.0';
  static readonly MIN_API_VERSION = 10;

  // 性能指标
  static readonly COLD_START_TARGET_MS = 3000;
  static readonly VOICE_RESPONSE_TARGET_MS = 2000;
  static readonly RAG_RETRIEVE_TARGET_MS = 500;

  // 存储路径
  static readonly STORAGE_PATH = '/data/local/tmp/OpenHarmonyAgent';
  static readonly RAG_STORAGE_PATH = '/data/local/tmp/OpenHarmonyAgent/rag';
  static readonly CACHE_PATH = '/data/local/tmp/OpenHarmonyAgent/cache';

  // 分布式会话
  static readonly DISTRIBUTED_SESSION_NAME = 'OpenHarmonyAgent_Session';
  static readonly DISTRIBUTED_OBJECT_NAME = 'OpenHarmonyAgent_Context';

  // 智能体配置
  static readonly MAX_CONTEXT_MESSAGES = 10;
  static readonly MAX_KNOWLEDGE_RESULTS = 5;
  static readonly SIMILARITY_THRESHOLD = 0.7;

  // 语音配置
  static readonly AUDIO_SAMPLE_RATE = 16000;
  static readonly AUDIO_CHANNELS = 1;
  static readonly MAX_RECORDING_TIME_SEC = 300;

  // 图像配置
  static readonly MAX_IMAGE_SIZE_MB = 10;
  static readonly IMAGE_COMPRESS_QUALITY = 80;

  // 颜色配置
  static readonly COLORS = {
    PRIMARY: '#007DFF',
    PRIMARY_DARK: '#0056CC',
    SUCCESS: '#52C41A',
    WARNING: '#FAAD14',
    ERROR: '#FF4D4F',
    LEARNING: '#1890FF',
    SCHEDULE: '#52C41A',
    DOCUMENT: '#722ED1'
  };

  // 路由
  static readonly ROUTES = {
    HOME: 'pages/Index',
    KNOWLEDGE: 'pages/KnowledgeBase',
    AGENTS: 'pages/Agents',
    SETTINGS: 'pages/Settings',
    CHAT_DETAIL: 'pages/ChatDetail'
  };

  // 事件类型
  static readonly EVENTS = {
    MESSAGE_SENT: 'message_sent',
    MESSAGE_RECEIVED: 'message_received',
    KNOWLEDGE_ADDED: 'knowledge_added',
    TASK_TRANSFERRED: 'task_transferred',
    AGENT_ACTIVATED: 'agent_activated'
  };
}
