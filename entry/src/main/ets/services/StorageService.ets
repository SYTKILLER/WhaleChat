/**
 * 存储服务 — Cloud Kit RdbStore CRUD
 *
 * 使用 RdbStore（Cloud Kit 端云同步）替代 Preferences。
 * 数据库初始化由 DatabaseHelper 在 EntryAbility 中完成，
 * 本服务仅提供业务 CRUD 接口。
 */

import { relationalStore } from '@kit.ArkData'
import { dbHelper } from './DatabaseHelper'
import { Conversation } from '../models/Conversation'
import { Memory } from '../models/Memory'
import { ApiConfig, ManagedApiConfig, createDefaultApiConfig } from '../models/ApiConfig'
import { STORAGE_KEYS } from '../common/Constants'
import { syncService } from './SyncService'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0001
const TAG = 'StorageService'

class StorageService {
  private initPromise: Promise<void> | null = null

  /** 等待数据库就绪（阻塞直到 dbHelper.init 完成） */
  async init(_context?: Context): Promise<void> {
    if (this.initPromise) return this.initPromise
    this.initPromise = dbHelper.waitForReady()
    return this.initPromise
  }

  private getStore(): relationalStore.RdbStore | null {
    return dbHelper.getStore()
  }

  private safeGetReal(result: relationalStore.ResultSet, col: string, def: number): number {
    try {
      const v = result.getDouble(result.getColumnIndex(col))
      return (v != undefined && !isNaN(v)) ? v : def
    } catch (_) { return def }
  }

  private safeGetLong(result: relationalStore.ResultSet, col: string, def: number): number {
    try {
      const v = result.getLong(result.getColumnIndex(col))
      return (v != undefined) ? v : def
    } catch (_) { return def }
  }

  // ════════════ 设置（Settings 表）════════════

  async getString(key: string, def: string = ''): Promise<string> {
    const store = this.getStore()
    if (!store) return def
    try {
      const pred = new relationalStore.RdbPredicates('SETTINGS')
      pred.equalTo('key', key)
      const result = await store.query(pred)
      if (result.goToFirstRow()) {
        const val = result.getString(result.getColumnIndex('value'))
        result.close()
        return val ?? def
      }
      result.close()
      return def
    } catch (err) {
      return def
    }
  }

  async setString(key: string, value: string): Promise<void> {
    const store = this.getStore()
    if (!store) return
    try {
      const vb: relationalStore.ValuesBucket = { 'key': key, 'value': value }
      await store.insert('SETTINGS', vb, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'setString failed: %{public}s', JSON.stringify(err))
    }
  }

  async getBoolean(key: string, def: boolean = false): Promise<boolean> {
    const val = await this.getString(key, def ? 'true' : 'false')
    return val === 'true'
  }

  async setBoolean(key: string, value: boolean): Promise<void> {
    await this.setString(key, value ? 'true' : 'false')
  }

  // ════════════ 对话（Conversations 表）════════════

  async saveConversations(convs: Conversation[]): Promise<void> {
    const store = this.getStore()
    if (!store) return
    try {
      // 全量替换：删除旧数据 → 批量插入
      await store.executeSql('DELETE FROM CONVERSATIONS')
      for (const c of convs) {
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
          'created_at': c.createdAt,
          'updated_at': c.updatedAt,
          'system_prompt': c.systemPrompt || '',
          'temperature': c.temperature,
          'max_tokens': c.maxTokens,
          'top_p': c.topP,
          'thinking': c.deepThinking ? 1 : 0,
          'is_deleted': c.isDeleted ? 1 : 0
        }
        await store.insert('CONVERSATIONS', vb)
        if (c.isDeleted) {
          hilog.info(DOMAIN, TAG, 'Saving deleted conv: id=%{public}s, is_deleted=1', c.id)
        }
      }
      // 主动推送变更到云端
      syncService.pushConversations().then(() => {
        hilog.info(DOMAIN, TAG, 'Push conversations OK')
      }).catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'Push conversations failed: %{public}s', JSON.stringify(err))
      })
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'saveConversations failed: %{public}s', JSON.stringify(err))
    }
  }

  async loadConversations(): Promise<Conversation[]> {
    const store = this.getStore()
    if (!store) return []
    try {
      const pred = new relationalStore.RdbPredicates('CONVERSATIONS')
      pred.orderByDesc('updated_at')
      const result = await store.query(pred)
      const convs: Conversation[] = []
      while (result.goToNextRow()) {
        const msgJson = result.getString(result.getColumnIndex('messages'))
        convs.push({
          id: result.getString(result.getColumnIndex('id'))!,
          title: result.getString(result.getColumnIndex('title')) ?? '',
          model: result.getString(result.getColumnIndex('model')) ?? '',
          messages: msgJson ? JSON.parse(msgJson) : [],
          createdAt: result.getLong(result.getColumnIndex('created_at')),
          updatedAt: result.getLong(result.getColumnIndex('updated_at')),
          systemPrompt: result.getString(result.getColumnIndex('system_prompt')) ?? '',
          temperature: this.safeGetReal(result, 'temperature', 0.8),
          maxTokens: this.safeGetLong(result, 'max_tokens', 393216),
          topP: this.safeGetReal(result, 'top_p', 1.0),
          deepThinking: (this.safeGetLong(result, 'thinking', 0) === 1),
          isDeleted: (this.safeGetLong(result, 'is_deleted', 0) === 1)
        })
      }
      result.close()
      return convs
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'loadConversations failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  /** 加载活跃对话（排除回收站中的对话） */
  async loadActiveConversations(): Promise<Conversation[]> {
    const all = await this.loadConversations()
    return all.filter(c => !c.isDeleted)
  }

  /** 加载回收站对话 */
  async loadRecycleBin(): Promise<Conversation[]> {
    const all = await this.loadConversations()
    return all.filter(c => c.isDeleted === true)
  }

  // ════════════ 记忆（Memories 表）════════════

  async saveMemories(memories: Memory[]): Promise<void> {
    const store = this.getStore()
    if (!store) return
    try {
      await store.executeSql('DELETE FROM MEMORIES')
      for (const m of memories) {
        const date: string = new Date(m.updatedAt).toLocaleDateString()
        const vb: relationalStore.ValuesBucket = {
          'id': m.id,
          'content': m.content,
          'date': date,
          'created_at': m.createdAt,
          'updated_at': m.updatedAt
        }
        await store.insert('MEMORIES', vb)
      }
      // 主动推送变更到云端
      syncService.pushMemories().catch(() => {})
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'saveMemories failed: %{public}s', JSON.stringify(err))
    }
  }

  async loadMemories(): Promise<Memory[]> {
    const store = this.getStore()
    if (!store) return []
    try {
      const pred = new relationalStore.RdbPredicates('MEMORIES')
      pred.orderByDesc('created_at')
      const result = await store.query(pred)
      const memories: Memory[] = []
      while (result.goToNextRow()) {
        memories.push({
          id: result.getString(result.getColumnIndex('id'))!,
          content: result.getString(result.getColumnIndex('content')) ?? '',
          createdAt: result.getLong(result.getColumnIndex('created_at')),
          updatedAt: result.getLong(result.getColumnIndex('updated_at'))
        })
      }
      result.close()
      return memories
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'loadMemories failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  // ════════════ API 配置（APICONFIGS 表 - 管理页多配置）════════════

  async saveApiConfigs(configs: ManagedApiConfig[]): Promise<void> {
    const store = this.getStore()
    if (!store) return
    try {
      await store.executeSql('DELETE FROM APICONFIGS')
      for (const cfg of configs) {
        const vb: relationalStore.ValuesBucket = {
          'id': cfg.id,
          'name': cfg.name,
          'platform': cfg.platform,
          'base_url': cfg.baseUrl,
          'api_key': cfg.apiKey,
          'created_at': cfg.createdAt
        }
        await store.insert('APICONFIGS', vb)
      }
      // 主动推送变更到云端
      syncService.pushApiConfigs().catch(() => {})
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'saveApiConfigs failed: %{public}s', JSON.stringify(err))
    }
  }

  async loadApiConfigs(): Promise<ManagedApiConfig[]> {
    const store = this.getStore()
    if (!store) return []
    try {
      const pred = new relationalStore.RdbPredicates('APICONFIGS')
      pred.orderByDesc('created_at')
      const result = await store.query(pred)
      const configs: ManagedApiConfig[] = []
      while (result.goToNextRow()) {
        configs.push({
          id: result.getString(result.getColumnIndex('id'))!,
          name: result.getString(result.getColumnIndex('name')) ?? '',
          platform: result.getString(result.getColumnIndex('platform')) ?? 'custom',
          baseUrl: result.getString(result.getColumnIndex('base_url')) ?? '',
          apiKey: result.getString(result.getColumnIndex('api_key')) ?? '',
          createdAt: result.getLong(result.getColumnIndex('created_at'))
        })
      }
      result.close()
      return configs
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'loadApiConfigs failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  // ════════════ 单 API 配置（兼容旧 Settings 表）════════════

  async saveApiConfig(config: ApiConfig): Promise<void> {
    const store = this.getStore()
    if (!store) return
    try {
      // 1. 写入 SETTINGS 表（兼容旧版单配置读取）
      const pairs: Record<string, string> = {
        'providerId': config.providerId,
        'apiKey': config.apiKey,
        'customBaseUrl': config.customBaseUrl,
        'customModel': config.customModel,
        'selectedModel': config.selectedModel,
        'temperature': String(config.temperature),
        'maxTokens': String(config.maxTokens),
        'topP': String(config.topP)
      }
      const keys = Object.keys(pairs)
      for (let i = 0; i < keys.length; i++) {
        const k = keys[i]
        const v = pairs[k]
        const vb: relationalStore.ValuesBucket = { 'key': k, 'value': v }
        await store.insert('SETTINGS', vb,
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
      }

      // 2. 同时写入 APICONFIGS 表（供 loadApiConfigs 检查，防止首次使用死循环）
      const baseUrl: string = config.providerId === 'custom'
        ? config.customBaseUrl
        : (config.providerId === 'deepseek' ? 'https://api.deepseek.com'
          : config.providerId === 'openai' ? 'https://api.openai.com' : config.customBaseUrl)
      const cfgVb: relationalStore.ValuesBucket = {
        'id': config.providerId + '_default',
        'name': config.providerId === 'deepseek' ? 'DeepSeek'
          : config.providerId === 'openai' ? 'OpenAI' : config.providerId,
        'platform': config.providerId,
        'base_url': baseUrl,
        'api_key': config.apiKey,
        'created_at': Date.now()
      }
      await store.insert('APICONFIGS', cfgVb,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'saveApiConfig failed: %{public}s', JSON.stringify(err))
    }
  }

  async loadApiConfig(): Promise<ApiConfig | null> {
    const store = this.getStore()
    if (!store) return null
    try {
      const providerId = await this.getString('providerId', 'deepseek')
      if (!providerId) {
        return null
      }
      const config: ApiConfig = {
        providerId: providerId,
        apiKey: '',
        customBaseUrl: '',
        customModel: '',
        selectedModel: 'gpt-4o',
        temperature: 0.7,
        maxTokens: 393216,
        topP: 1,
        isConfigured: false
      }
      config.apiKey = await this.getString('apiKey', '')
      config.customBaseUrl = await this.getString('customBaseUrl', '')
      config.customModel = await this.getString('customModel', '')
      config.selectedModel = await this.getString('selectedModel', 'gpt-4o')
      config.temperature = parseFloat(await this.getString('temperature', '0.7'))
      config.maxTokens = parseInt(await this.getString('maxTokens', '393216'))
      config.topP = parseFloat(await this.getString('topP', '1'))
      return config
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'loadApiConfig failed: %{public}s', JSON.stringify(err))
      return null
    }
  }

  // ════════════ 启动标记 ════════════

  async hasLaunched(): Promise<boolean> {
    return await this.getBoolean(STORAGE_KEYS.HAS_LAUNCHED, false)
  }

  async setLaunched(): Promise<void> {
    await this.setBoolean(STORAGE_KEYS.HAS_LAUNCHED, true)
  }

  // ════════════ 主题 ════════════

  async saveThemeColor(color: string): Promise<void> {
    await this.setString(STORAGE_KEYS.THEME_COLOR, color)
  }

  async loadThemeColor(): Promise<string> {
    return await this.getString(STORAGE_KEYS.THEME_COLOR, '')
  }

  // ════════════ 记忆 ID 管理（兼容旧版） ════════════

  async saveMemoryId(id: string): Promise<void> {
    await this.setString('memory_id', id)
  }

  async loadMemoryId(): Promise<string> {
    return await this.getString('memory_id', '')
  }
}

export const storageService = new StorageService()
