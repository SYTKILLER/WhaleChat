/**
 * 通用工具函数
 */

/**
 * 格式化时间戳为可读字符串
 */
export function formatTimestamp(timestamp: number): string {
  const date = new Date(timestamp)
  const now = new Date()
  const diff = now.getTime() - date.getTime()
  const oneDay = 24 * 60 * 60 * 1000

  // 今天
  if (diff < oneDay && date.getDate() === now.getDate()) {
    return formatTime(date)
  }

  // 昨天
  const yesterday = new Date(now.getTime() - oneDay)
  if (date.getDate() === yesterday.getDate()) {
    return `昨天 ${formatTime(date)}`
  }

  // 今年内
  if (date.getFullYear() === now.getFullYear()) {
    return `${date.getMonth() + 1}/${date.getDate()}`
  }

  // 更早
  return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`
}

/**
 * 格式化时间（时:分）
 */
export function formatTime(date: Date): string {
  const hours = date.getHours().toString().padStart(2, '0')
  const minutes = date.getMinutes().toString().padStart(2, '0')
  return `${hours}:${minutes}`
}

/**
 * 截断文本
 */
export function truncateText(text: string, maxLength: number): string {
  if (text.length <= maxLength) {
    return text
  }
  return text.substring(0, maxLength) + '…'
}

/**
 * 深拷贝对象（JSON 安全类型）
 */
export function deepClone<T>(obj: T): T {
  return JSON.parse(JSON.stringify(obj)) as T
}

/**
 * 可合并项接口（需要 id、updatedAt 和可选的 isDeleted 字段）。
 */
export interface MergeableItem {
  id: string
  updatedAt: number
  isDeleted?: boolean
}

/**
 * 合并两个数组，以 ID 为唯一键。
 * - 保留两者中都存在的项，取 updatedAt 较新的版本
 * - 保留仅存在于一方的项
 * - 支持软删除：若 item.isDeleted === true，合并后过滤掉
 */
export function mergeConversations<T extends MergeableItem>(local: T[], remote: T[]): T[] {
  const map = new Map<string, T>()

  for (const item of local) {
    map.set(item.id, item)
  }

  for (const item of remote) {
    const existing = map.get(item.id)
    if (!existing || item.updatedAt > existing.updatedAt) {
      map.set(item.id, item)
    }
  }

  return Array.from(map.values())
    .filter(item => !item.isDeleted)
    .sort((a, b) => b.updatedAt - a.updatedAt)
}
