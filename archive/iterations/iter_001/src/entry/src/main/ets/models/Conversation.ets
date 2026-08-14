/**
 * 对话模型
 */

import { Message, generateId } from './Message'

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
}

/**
 * 创建新对话
 */
export function createConversation(model: string, title?: string): Conversation {
  return {
    id: generateId(),
    title: title ?? '新对话',
    messages: [],
    createdAt: Date.now(),
    updatedAt: Date.now(),
    model
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
