/**
 * 消息模型
 */

export interface Message {
  /** 消息唯一标识 */
  id: string
  /** 角色：user | assistant | system */
  role: 'user' | 'assistant' | 'system'
  /** 消息内容 */
  content: string
  /** 时间戳 */
  timestamp: number
  /** 是否为流式输出中（仅 assistant 消息） */
  isStreaming?: boolean
  /** 使用的模型名 */
  model?: string
}

/**
 * 生成唯一 ID
 */
export function generateId(): string {
  return `${Date.now()}_${Math.random().toString(36).substring(2, 9)}`
}

/**
 * 创建一条消息
 */
export function createMessage(role: Message['role'], content: string, model?: string): Message {
  return {
    id: generateId(),
    role,
    content,
    timestamp: Date.now(),
    model
  }
}
