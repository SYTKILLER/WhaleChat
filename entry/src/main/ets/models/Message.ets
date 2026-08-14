/**
 * 消息模型
 */

export interface Message {
  /** 消息唯一标识 */
  id: string
  /** 角色 */
  role: MessageRole
  /** 消息内容 */
  content: string
  /** 深度思考内容（DeepSeek reasoning_content） */
  thinkingContent: string
  /** 思考内容是否展开 */
  showThinking: boolean
  /** 时间戳 */
  timestamp: number
  /** 是否为流式输出中（仅 assistant 消息） */
  isStreaming: boolean
  /** 使用的模型名 */
  model: string
}

/** 消息角色类型 */
export type MessageRole = 'user' | 'assistant' | 'system'

/**
 * 生成唯一 ID
 */
export function generateId(): string {
  const rand = Math.floor(Math.random() * 10000000)
  return Date.now().toString() + '_' + rand.toString(36)
}

/**
 * 创建一条消息
 */
export function createMessage(role: MessageRole, content: string, model?: string): Message {
  return {
    id: generateId(),
    role: role,
    content: content,
    thinkingContent: '',
    showThinking: false,
    timestamp: Date.now(),
    isStreaming: false,
    model: model ?? ''
  }
}
