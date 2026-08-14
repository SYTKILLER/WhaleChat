/**
 * 永久记忆模型
 * 用户保存的长期记忆，每次 API 调用时作为 system message 注入
 */

import { generateId } from './Message'

export interface Memory {
  /** 记忆唯一标识 */
  id: string
  /** 记忆内容 */
  content: string
  /** 创建时间 */
  createdAt: number
  /** 更新时间 */
  updatedAt: number
}

/**
 * 创建一条记忆
 */
export function createMemory(content: string): Memory {
  return {
    id: generateId(),
    content,
    createdAt: Date.now(),
    updatedAt: Date.now()
  }
}

/**
 * 将多条记忆拼接为 System Prompt 片段
 */
export function formatMemoriesAsPrompt(memories: Memory[]): string {
  if (memories.length === 0) {
    return ''
  }
  const lines = memories.map(m => `- ${m.content}`)
  return `\n\n[用户提供的长期记忆]\n${lines.join('\n')}`
}
