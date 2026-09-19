/**
 * API 平台配置模型
 * 支持 DeepSeek、OpenAI 和自定义平台
 */

import { DEFAULT_TEMPERATURE, DEFAULT_MAX_TOKENS, DEFAULT_TOP_P } from '../common/Constants'

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
    temperature: DEFAULT_TEMPERATURE,
    maxTokens: DEFAULT_MAX_TOKENS,
    topP: DEFAULT_TOP_P,
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

/**
 * 模型条目：一个 API 配置（key）下的一个可用模型
 * 存储于 APIMODELS 表（端云同步），与 APICONFIGS 通过 configId 关联
 */
export interface ApiModelEntry {
  /** 条目唯一 ID */
  id: string
  /** 所属 API 配置 ID → APICONFIGS.id */
  configId: string
  /** OpenAI 格式模型名（请求体 model 参数） */
  modelId: string
  /** 缩略显示名（对话页 Select 收起时显示），空则回退 modelId */
  displayName: string
  /** 展示顺序（Select 展开按此排序） */
  sortOrder: number
  /** 创建时间戳 */
  createdAt: number
}

/**
 * 单次聊天请求的连接上下文（ApiService 请求参数化，
 * 由「激活配置 + 激活模型 + 对话页参数」组装）
 */
export interface ChatEndpoint {
  baseUrl: string
  apiKey: string
  modelId: string
  temperature: number
  maxTokens: number
  topP: number
}

/** 激活配置上下文（ChatPage 加载结果） */
export interface ActiveApiContext {
  config: ManagedApiConfig | null
  models: ApiModelEntry[]
  activeModel: ApiModelEntry | null
}

/**
 * 构造模型条目（id 为空时自动生成）
 */
export function buildModelEntry(id: string, configId: string, modelId: string,
  displayName: string, sortOrder: number): ApiModelEntry {
  return {
    id: id.length > 0 ? id : configId + '_' + Date.now().toString() + '_' + sortOrder.toString(),
    configId: configId,
    modelId: modelId,
    displayName: displayName,
    sortOrder: sortOrder,
    createdAt: Date.now()
  }
}

/**
 * 显示名回退：未配置显示名时显示模型名
 */
export function resolveDisplayName(entry: ApiModelEntry): string {
  return entry.displayName.length > 0 ? entry.displayName : entry.modelId
}

/**
 * 归一化 BaseURL：缺少协议前缀时补 https://
 */
export function normalizeBaseUrl(url: string): string {
  let result: string = url.trim()
  if (result.length === 0) return result
  if (!result.startsWith('http://') && !result.startsWith('https://')) {
    result = 'https://' + result
  }
  return result
}

/**
 * 根据 BaseURL 自动识别平台（deepseek / openai / custom）
 */
export function detectPlatform(baseUrl: string): string {
  const lower: string = baseUrl.toLowerCase()
  if (lower.includes('deepseek')) return 'deepseek'
  if (lower.includes('openai')) return 'openai'
  return 'custom'
}

/**
 * 由 BaseURL 构建 Chat Completions 完整 URL
 * 已以 /v1 结尾的地址不再重复追加（兼容 moonshot 等含 /v1 的 baseUrl）
 */
export function buildChatUrl(baseUrl: string): string {
  const base: string = baseUrl.trim().replace(/\/+$/, '')
  const lower: string = base.toLowerCase()
  if (lower.endsWith('/v1')) {
    return base + '/chat/completions'
  }
  return base + '/v1/chat/completions'
}
