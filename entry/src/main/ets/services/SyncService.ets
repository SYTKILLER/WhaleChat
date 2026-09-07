/**
 * SyncService — Cloud Kit 端云同步服务 v3.0
 *
 * 替代 v2.0 的 distributedKVStore（局域网同步），
 * 直接调用 DatabaseHelper.cloudSync() 实现华为云空间云端同步。
 *
 * 同步时机：
 * - ConversationListPage.onPageShow()  → syncConversations()
 * - MemoryPage.onPageShow()            → syncMemories()
 * - ApiManagementPage.onPageShow()     → syncApiConfigs()
 */

import { hilog } from '@kit.PerformanceAnalysisKit'
import { relationalStore } from '@kit.ArkData'
import { dbHelper, getSyncStatusText } from './DatabaseHelper'

const TAG = 'SyncService'

class SyncService {
  private static instance: SyncService | null = null

  static getInstance(): SyncService {
    if (!SyncService.instance) {
      SyncService.instance = new SyncService()
    }
    return SyncService.instance
  }

  /** 获取最近一次云同步的状态描述文本 */
  getLastSyncMessage(): string {
    return getSyncStatusText(dbHelper.getLastSyncCode())
  }

  /**
   * 同步对话列表
   * Cloud Kit 会自动合并云端与本地数据，此处仅触发双向同步。
   * 调用方应在 cloudSync 完成后重新 loadConversations()。
   *
   * @returns 无需再关心合并结果，直接返回本地 JSON（调用方应重新从 RdbStore 读取）
   */
  async syncConversations(_localJson: string): Promise<string> {
    await this.doSync('CONVERSATIONS')
    return _localJson
  }

  async syncMemories(_localJson: string): Promise<string> {
    await this.doSync('MEMORIES')
    return _localJson
  }

  async syncApiConfigs(_localJson: string): Promise<string> {
    await this.doSync('APICONFIGS')
    return _localJson
  }

  /** 内部：触发指定表的 TIME_FIRST 云同步 */
  private async doSync(...tables: string[]): Promise<void> {
    await dbHelper.cloudSync(tables, relationalStore.SyncMode.SYNC_MODE_TIME_FIRST)
    hilog.info(0x0004, TAG, 'Cloud sync triggered for: %{public}s', tables.join(', '))
  }

  /**
   * 主动推送对话变更到云端
   */
  async pushConversations(): Promise<void> {
    await dbHelper.cloudSync(['CONVERSATIONS'],
      relationalStore.SyncMode.SYNC_MODE_TIME_FIRST)
    hilog.info(0x0004, TAG, 'Push conversations to cloud')
  }

  async pushMemories(): Promise<void> {
    await dbHelper.cloudSync(['MEMORIES'],
      relationalStore.SyncMode.SYNC_MODE_TIME_FIRST)
    hilog.info(0x0004, TAG, 'Push memories to cloud')
  }

  async pushApiConfigs(): Promise<void> {
    await dbHelper.cloudSync(['APICONFIGS'],
      relationalStore.SyncMode.SYNC_MODE_TIME_FIRST)
    hilog.info(0x0004, TAG, 'Push API configs to cloud')
  }
}

export const syncService = SyncService.getInstance()
