/**
 * 应用常量
 * 注意：ArkTS 不支持 as const 和匿名对象字面量作为类型，需使用显式接口
 */

/** 存储 Key 接口 */
interface StorageKeys {
  API_CONFIG: string
  API_CONFIGS: string
  CONVERSATIONS: string
  MEMORIES: string
  THEME_MODE: string
  HAS_LAUNCHED: string
  THEME_COLOR: string
  CONV_REFRESH_KEY: string
}

export const STORAGE_KEYS: StorageKeys = {
  API_CONFIG: 'whalechat_api_config',
  API_CONFIGS: 'whalechat_api_configs',
  CONVERSATIONS: 'whalechat_conversations',
  MEMORIES: 'whalechat_memories',
  THEME_MODE: 'whalechat_theme_mode',
  HAS_LAUNCHED: 'whalechat_has_launched',
  THEME_COLOR: 'whalechat_theme_color',
  CONV_REFRESH_KEY: 'whalechat_conv_refresh',
}

/** API 常量接口 */
interface ApiConstants {
  DEFAULT_TIMEOUT: number
  STREAM_TIMEOUT: number
  USER_AGENT: string
  MAX_CONTEXT_TOKENS: number
}

export const API: ApiConstants = {
  DEFAULT_TIMEOUT: 60000,
  STREAM_TIMEOUT: 300000,
  USER_AGENT: 'WhaleChat-HarmonyOS/1.0',
  MAX_CONTEXT_TOKENS: 1000000
}

/** 路由常量接口 */
interface RouteConstants {
  INDEX: string
  API_CONFIG: string
  API_MANAGEMENT: string
  MAIN: string
  CHAT: string
  CONVERSATION_LIST: string
  SETTINGS: string
  RECYCLE_BIN: string
}

export const ROUTES: RouteConstants = {
  INDEX: 'pages/Index',
  API_CONFIG: 'pages/ApiConfigPage',
  API_MANAGEMENT: 'pages/ApiManagementPage',
  MAIN: 'pages/MainPage',
  CHAT: 'pages/ChatPage',
  CONVERSATION_LIST: 'pages/ConversationListPage',
  SETTINGS: 'pages/SettingsPage',
  RECYCLE_BIN: 'pages/RecycleBinPage'
}

/** 应用信息接口 */
interface AppInfoConstants {
  NAME: string
  VERSION: string
  DESCRIPTION: string
}

export const APP_INFO: AppInfoConstants = {
  NAME: '鲸语',
  VERSION: '1.0.0',
  DESCRIPTION: '鲸歌万里，一语相通'
}

/** 主题颜色预设 */
export interface ThemeColorItem {
  name: string
  value: string
}

export const THEME_COLORS: ThemeColorItem[] = [
  { name: '蔚蓝', value: '#007DFF' },
  { name: '翠绿', value: '#34C759' },
  { name: '橙金', value: '#FF9500' },
  { name: '紫罗兰', value: '#AF52DE' },
  { name: '玫红', value: '#FF375F' },
  { name: '石墨', value: '#8E8E93' }
]

export const DEFAULT_THEME_COLOR: string = '#007DFF'
