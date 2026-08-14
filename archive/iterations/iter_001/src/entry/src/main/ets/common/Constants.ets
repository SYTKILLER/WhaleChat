/**
 * 应用常量
 */

/** 存储 Key 前缀 */
export const STORAGE_KEYS = {
  API_CONFIG: 'deepchat_api_config',
  CONVERSATIONS: 'deepchat_conversations',
  MEMORIES: 'deepchat_memories',
  THEME_MODE: 'deepchat_theme_mode',
  HAS_LAUNCHED: 'deepchat_has_launched'
} as const

/** API 相关 */
export const API = {
  /** 默认超时时间（毫秒） */
  DEFAULT_TIMEOUT: 60000,
  /** SSE 流式超时 */
  STREAM_TIMEOUT: 300000,
  /** 用户 Agent 标识 */
  USER_AGENT: 'DeepChat-HarmonyOS/1.0'
} as const

/** 页面路由 */
export const ROUTES = {
  INDEX: 'pages/Index',
  API_CONFIG: 'pages/ApiConfigPage',
  MAIN: 'pages/MainPage',
  CHAT: 'pages/ChatPage',
  CONVERSATION_LIST: 'pages/ConversationListPage',
  SETTINGS: 'pages/SettingsPage'
} as const

/** 应用信息 */
export const APP_INFO = {
  NAME: 'DeepChat',
  VERSION: '1.0.0',
  DESCRIPTION: 'AI 对话助手'
} as const
