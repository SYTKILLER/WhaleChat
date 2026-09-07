/**
 * 对话模型
 */

import { Message, generateId } from './Message'
import { DEFAULT_TEMPERATURE, DEFAULT_MAX_TOKENS, DEFAULT_TOP_P } from '../common/Constants'

export interface Conversation {
  /** 对话唯一标识 */
  id: string
  /** 对话标题 */
  title: string
  /** 消息列表 */
  messages: Message[]
  /** 创建时间 */
  createdAt: number
  /** 最后更新时间 */
  updatedAt: number
  /** 使用的模型 */
  model: string
  /** 自定义系统提示词（空则使用默认） */
  systemPrompt: string
  /** 温度参数 (0-2) */
  temperature: number
  /** 最大 Token 数 */
  maxTokens: number
  /** Top-P 采样 (0-1) */
  topP: number
  /** 深度思考开关 */
  deepThinking: boolean
  /** 是否在回收站中（软删除标记） */
  isDeleted?: boolean
}

export function createConversation(model: string, title?: string): Conversation {
  return {
    id: generateId(),
    title: title ?? '新对话',
    messages: [],
    createdAt: Date.now(),
    updatedAt: Date.now(),
    model,
    systemPrompt: '',
    temperature: DEFAULT_TEMPERATURE,
    maxTokens: DEFAULT_MAX_TOKENS,
    topP: DEFAULT_TOP_P,
    deepThinking: false
  }
}

/**
 * 根据对话内容自动生成标题
 */
export function generateConversationTitle(firstMessage: string): string {
  const trimmed = firstMessage.trim()
  // 截取首条消息作为标题
  const title = trimmed.length > 30 ? trimmed.substring(0, 30) + '…' : trimmed
  return title || '新对话'
}
