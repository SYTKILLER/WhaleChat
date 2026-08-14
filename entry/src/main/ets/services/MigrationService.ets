/**
 * MigrationService — Preferences → Cloud Kit RdbStore 数据迁移
 *
 * 在首次启动（或升级后）将旧 Preferences 数据迁移到 RdbStore，
 * 迁移完成后标记 _MIGRATION.done = 'true'，后续启动跳过。
 * 旧 Preferences 数据保留不删除，作为只读备份。
 */

import { preferences, relationalStore } from '@kit.ArkData'
import { dbHelper } from './DatabaseHelper'
import { Conversation } from '../models/Conversation'
import { Memory } from '../models/Memory'
import { ManagedApiConfig } from '../models/ApiConfig'
import { STORAGE_KEYS } from '../common/Constants'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0003
const TAG = 'MigrationService'

class MigrationService {
  private static instance: MigrationService | null = null

  static getInstance(): MigrationService {
    if (!MigrationService.instance) {
      MigrationService.instance = new MigrationService()
    }
    return MigrationService.instance
  }

  /**
   * 执行数据迁移。幂等：已迁移则跳过。
   */
  async run(context: Context): Promise<void> {
    const store = dbHelper.getStore()
    if (!store) {
      hilog.warn(DOMAIN, TAG, 'RdbStore not ready, skip migration')
      return
    }

    try {
      if (await dbHelper.isMigrated()) {
        hilog.info(DOMAIN, TAG, 'Already migrated, skipping')
        return
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Migration check failed, attempting anyway')
    }

    let prefs: preferences.Preferences | null = null
    try {
      prefs = await preferences.getPreferences(context, 'whalechat_store')
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Cannot open Preferences, skip migration')
      await dbHelper.markMigrated()
      return
    }

    try {
      let migratedCount = 0

      // ── 1. 对话 ──
      try {
        const convsJson = await prefs.get(STORAGE_KEYS.CONVERSATIONS, '') as string
        if (convsJson) {
          const conversations: Conversation[] = JSON.parse(convsJson)
          for (const c of conversations) {
            const lastMsg = c.messages.length > 0
              ? c.messages[c.messages.length - 1].content
              : ''
            const preview: string = typeof lastMsg === 'string'
              ? lastMsg.substring(0, 100)
              : ''
            const date: string = new Date(c.updatedAt).toLocaleDateString()
            const vb: relationalStore.ValuesBucket = {
              'id': c.id,
              'title': c.title,
              'model': c.model || '',
              'preview': preview,
              'date': date,
              'messages': JSON.stringify(c.messages),
              'memory_id': '',
              'created_at': c.createdAt,
              'updated_at': c.updatedAt
            }
            await store.insert('CONVERSATIONS', vb,
              relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
          }
          migratedCount += conversations.length
          hilog.info(DOMAIN, TAG, 'Migrated %{public}d conversations', conversations.length)
        }
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Skip conversations migration: %{public}s', JSON.stringify(err))
      }

      // ── 2. 记忆 ──
      try {
        const memJson = await prefs.get(STORAGE_KEYS.MEMORIES, '') as string
        if (memJson) {
          const memories: Memory[] = JSON.parse(memJson)
          for (const m of memories) {
            const date: string = new Date(m.updatedAt).toLocaleDateString()
            const vb: relationalStore.ValuesBucket = {
              'id': m.id,
              'content': m.content,
              'date': date,
              'created_at': m.createdAt,
              'updated_at': m.updatedAt
            }
            await store.insert('MEMORIES', vb,
              relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
          }
          migratedCount += memories.length
          hilog.info(DOMAIN, TAG, 'Migrated %{public}d memories', memories.length)
        }
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Skip memories migration: %{public}s', JSON.stringify(err))
      }

      // ── 3. API 配置 ──
      try {
        const apisJson = await prefs.get(STORAGE_KEYS.API_CONFIGS, '') as string
        if (apisJson) {
          const configs: ManagedApiConfig[] = JSON.parse(apisJson)
          for (const cfg of configs) {
            const vb: relationalStore.ValuesBucket = {
              'id': cfg.id,
              'name': cfg.name,
              'platform': cfg.platform,
              'base_url': cfg.baseUrl,
              'api_key': cfg.apiKey,
              'created_at': cfg.createdAt
            }
            await store.insert('APICONFIGS', vb,
              relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
          }
          migratedCount += configs.length
          hilog.info(DOMAIN, TAG, 'Migrated %{public}d API configs', configs.length)
        }
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Skip API configs migration: %{public}s', JSON.stringify(err))
      }

      // ── 4. 设置项 ──
      try {
        const settingsKeys: string[] = [
          STORAGE_KEYS.THEME_MODE,
          STORAGE_KEYS.THEME_COLOR,
          STORAGE_KEYS.HAS_LAUNCHED,
          'cloud_backup_enabled',
          'cloud_backup_selection'
        ]
        for (let i = 0; i < settingsKeys.length; i++) {
          const key = settingsKeys[i]
          const value = await prefs.get(key, '') as string
          if (value) {
            const vb: relationalStore.ValuesBucket = {
              'key': key,
              'value': value
            }
            await store.insert('SETTINGS', vb,
              relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
          }
        }
        hilog.info(DOMAIN, TAG, 'Settings migrated')
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Skip settings migration: %{public}s', JSON.stringify(err))
      }

      await dbHelper.markMigrated()
      hilog.info(DOMAIN, TAG, 'Migration completed (%{public}d records)', migratedCount)

    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Migration failed: %{public}s', JSON.stringify(err))
    }
  }
}

export const migrationService = MigrationService.getInstance()
