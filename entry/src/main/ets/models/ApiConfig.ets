/**
 * API 平台配置模型
 * 支持 DeepSeek、OpenAI 和自定义平台
 */

export interface ApiProvider {
  /** 平台唯一标识 */
  id: string
  /** 显示名称 */
  name: string
  /** API 基础地址 */
  baseUrl: string
  /** Chat Completions 路径（DeepSeek: /chat/completions, OpenAI: /v1/chat/completions） */
  chatPath: string
  /** Models 列表路径 */
  modelsPath: string
  /** 默认模型列表 */
  defaultModels: string[]
  /** 是否为预设平台 */
  isPreset: boolean
}

export interface ApiConfig {
  /** 当前选中的平台 ID */
  providerId: string
  /** API 密钥（加密存储） */
  apiKey: string
  /** 自定义 Base URL（providerId 为 'custom' 时使用） */
  customBaseUrl: string
  /** 自定义模型名 */
  customModel: string
  /** 当前选用的模型 */
  selectedModel: string
  /** 温度参数 (0-2) */
  temperature: number
  /** 最大 Token 数 */
  maxTokens: number
  /** Top-P 采样 (0-1) */
  topP: number
  /** 是否已配置完成 */
  isConfigured: boolean
}

/**
 * 预设平台列表
 */
export const PRESET_PROVIDERS: ApiProvider[] = [
  {
    id: 'deepseek',
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com',
    chatPath: '/v1/chat/completions',
    modelsPath: '/v1/models',
    defaultModels: ['deepseek-v4-flash', 'deepseek-v4-pro'],
    isPreset: true
  },
  {
    id: 'openai',
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com',
    chatPath: '/v1/chat/completions',
    modelsPath: '/v1/models',
    defaultModels: ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'o1', 'o1-mini'],
    isPreset: true
  }
]

/**
 * 创建默认 API 配置
 * 流程简化后 providerId 固定为 custom，地址默认 DeepSeek，用户可编辑为任意 OpenAI 兼容地址
 */
export function createDefaultApiConfig(): ApiConfig {
  return {
    providerId: CUSTOM_PROVIDER_ID,
    apiKey: '',
    customBaseUrl: 'https://api.deepseek.com',
    customModel: 'deepseek-v4-flash',
    selectedModel: 'deepseek-v4-flash',
    temperature: 0.8,
    maxTokens: 393216,
    topP: 1.0,
    isConfigured: false
  }
}

/**
 * 自定义平台标识
 */
export const CUSTOM_PROVIDER_ID = 'custom'

/**
 * 根据 providerId 获取平台信息
 */
export function getProvider(providerId: string): ApiProvider | undefined {
  if (providerId === CUSTOM_PROVIDER_ID) {
    return {
      id: CUSTOM_PROVIDER_ID,
      name: '自定义',
      baseUrl: '',
      chatPath: '/v1/chat/completions',
      modelsPath: '/v1/models',
      defaultModels: [],
      isPreset: false
    }
  }
  return PRESET_PROVIDERS.find(p => p.id === providerId)
}

/**
 * 获取当前生效的 Base URL
 */
export function getEffectiveBaseUrl(config: ApiConfig): string {
  if (config.providerId === CUSTOM_PROVIDER_ID) {
    return config.customBaseUrl
  }
  const provider = getProvider(config.providerId)
  return provider?.baseUrl ?? config.customBaseUrl
}

/**
 * 获取 Chat Completions 完整 URL
 */
export function getChatCompletionsUrl(config: ApiConfig): string {
  const base: string = getEffectiveBaseUrl(config).trim().replace(/\/+$/, '')
  const provider = getProvider(config.providerId)
  const path: string = provider?.chatPath ?? '/v1/chat/completions'
  return base + path
}

/**
 * 获取 Models 列表完整 URL
 */
export function getModelsUrl(config: ApiConfig): string {
  const base: string = getEffectiveBaseUrl(config).trim().replace(/\/+$/, '')
  const provider = getProvider(config.providerId)
  const path: string = provider?.modelsPath ?? '/v1/models'
  return base + path
}

/**
 * 获取当前生效的模型名
 */
export function getEffectiveModel(config: ApiConfig): string {
  if (config.providerId === CUSTOM_PROVIDER_ID) {
    return config.customModel
  }
  return config.selectedModel
}

/**
 * 管理页面的 API 配置项（支持多配置存储）
 */
export interface ManagedApiConfig {
  /** 唯一标识 */
  id: string
  /** 用户自定义名称 */
  name: string
  /** 平台: deepseek | openai | custom */
  platform: string
  /** API 基础地址 */
  baseUrl: string
  /** API 密钥 */
  apiKey: string
  /** 创建时间戳 */
  createdAt: number
}
