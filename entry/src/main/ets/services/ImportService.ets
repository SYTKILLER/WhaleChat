/**
 * ImportService — 处理外部文件导入
 *
 * EntryAbility.onNewWant 接收文件 URI 后存入 AppStorage，
 * 由 Index/MainPage 检测并触发导入流程。
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { common } from '@kit.AbilityKit'
import { Conversation } from '../models/Conversation'
import { markdownToConversation, batchParseMarkdown } from '../utils/MarkdownConverter'
import { readFileFromUri } from '../utils/FileHelper'
import { storageService } from '../services/StorageService'

const DOMAIN = 0x0005
const TAG = 'ImportService'

// AppStorage 键
export const IMPORT_TRIGGER_KEY = 'whalechat_import_trigger'

/**
 * 将待导入的 URI 放入 AppStorage，等待 UI 层消费
 */
export function setPendingImportUri(uri: string): void {
  if (!uri) return
  hilog.info(DOMAIN, TAG, 'Pending import URI: %{public}s', uri)
  AppStorage.setOrCreate(IMPORT_TRIGGER_KEY, uri)
}

/**
 * 尝试执行导入
 * @returns 导入的对话列表，失败返回空数组
 */
export async function tryImportFromUri(context: common.Context, uri: string): Promise<Conversation[]> {
  if (!uri) return []
  try {
    const content: string = await readFileFromUri(context, uri)
    if (!content) {
      hilog.warn(DOMAIN, TAG, 'Empty file content')
      return []
    }

    const conversations: Conversation[] = batchParseMarkdown(content)
    if (conversations.length === 0) {
      // 尝试单文件解析
      const conv: Conversation | null = markdownToConversation(content)
      if (!conv) return []

      const existing: Conversation[] = await storageService.loadConversations()
      let isDuplicate = false
      for (let i = 0; i < existing.length; i++) {
        if (existing[i].id === conv.id) {
          isDuplicate = true
          break
        }
      }
      if (!isDuplicate) {
        const updated: Conversation[] = [conv].concat(existing)
        await storageService.saveConversations(updated)
        hilog.info(DOMAIN, TAG, 'Imported 1 conversation: %{public}s', conv.title)
        return [conv]
      }
      return []
    }

    // 批量解析 — 去重合并
    const existing: Conversation[] = await storageService.loadConversations()
    const result: Conversation[] = []
    for (let i = 0; i < conversations.length; i++) {
      let isDuplicate = false
      for (let j = 0; j < existing.length; j++) {
        if (existing[j].id === conversations[i].id) {
          isDuplicate = true
          break
        }
      }
      if (!isDuplicate) {
        result.push(conversations[i])
      }
    }

    const merged: Conversation[] = result.concat(existing)
    await storageService.saveConversations(merged)
    hilog.info(DOMAIN, TAG, 'Imported %{public}d conversations', result.length)
    return result
  } catch (err) {
    hilog.error(DOMAIN, TAG, 'Import failed: %{public}s', JSON.stringify(err))
    return []
  }
}
