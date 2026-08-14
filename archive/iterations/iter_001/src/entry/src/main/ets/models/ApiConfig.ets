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
    defaultModels: ['deepseek-chat', 'deepseek-reasoner'],
    isPreset: true
  },
  {
    id: 'openai',
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com',
    defaultModels: ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'o1', 'o1-mini'],
    isPreset: true
  }
]

/**
 * 创建默认 API 配置
 */
export function createDefaultApiConfig(): ApiConfig {
  return {
    providerId: 'deepseek',
    apiKey: '',
    customBaseUrl: '',
    customModel: '',
    selectedModel: 'deepseek-chat',
    temperature: 0.8,
    maxTokens: 4096,
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
 * 获取当前生效的模型名
 */
export function getEffectiveModel(config: ApiConfig): string {
  if (config.providerId === CUSTOM_PROVIDER_ID) {
    return config.customModel
  }
  return config.selectedModel
}
