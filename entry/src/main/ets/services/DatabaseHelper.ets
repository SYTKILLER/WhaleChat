/**
 * DatabaseHelper — Cloud Kit RdbStore 初始化与管理
 *
 * 负责创建数据库、建表、设置分布式表（端云同步），
 * 并提供 cloudSync() 方法供页面触发同步。
 */

import { relationalStore, cloudData } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0002
const TAG = 'DatabaseHelper'

/** 云同步结果 */
export interface CloudSyncResult {
  /** 状态码：0=已同步 1=已暂停 2=网络错误 3=未开启 4=暂停将重试 5=超数据上限 6=空间不足 7=非WLAN暂停 */
  code: number
  /** 状态描述 */
  message: string
}

/** 将云同步进度码映射为可读文本 */
export function getSyncStatusText(code: number): string {
  switch (code) {
    case 0: return '已与云空间同步'
    case 1: return '与云空间同步已暂停'
    case 2: return '网络错误，与云空间同步已暂停'
    case 3: return '未开启同步'
    case 4: return '与云空间同步已暂停，稍后将自动重试'
    case 5: return '超出数据上限，与云空间同步已暂停'
    case 6: return '云空间存储空间不足'
    case 7: return '未连接WLAN，与云空间同步已暂停'
    default: return '状态未知(' + code.toString() + ')'
  }
}

/**
 * 数据库配置
 *
 * 云同步（cloudSync）依赖 SystemCapability.DistributedDataManager.CloudSync.Client，
 * 该能力仅在以下条件全部满足时可用：
 *   1. AGC 项目中已开通 Cloud Database 服务并创建云侧数据 zone
 *   2. 云侧表结构与本地 DDL 一致
 *   3. 设备已登录华为账号
 *   4. 应用使用正式（release）签名 —— debug 签名无权访问 Cloud Kit
 *
 * 若以上条件未满足，cloudSync 调用将返回 401（参数校验失败）。
 */
const DB_CONFIG: relationalStore.StoreConfig = {
  name: 'WhaleChat.db',
  securityLevel: relationalStore.SecurityLevel.S1
}

/** 数据库版本键（用于检测是否需要重建） */
const DB_VERSION_KEY = 'db_schema_version'
/** 当前数据库 schema 版本 */
const CURRENT_DB_VERSION = 3

/** 端云同步的分布式表名（与 AGC 云类型名称一致） */
export const CLOUD_TABLES: string[] = [
  'CONVERSATIONS',
  'MEMORIES',
  'SETTINGS',
  'APICONFIGS'
]

// ── DDL ──

const SQL_CONVERSATIONS: string = `
  CREATE TABLE IF NOT EXISTS CONVERSATIONS (
    id            TEXT PRIMARY KEY,
    title         TEXT,
    model         TEXT,
    preview       TEXT,
    date          TEXT,
    messages      TEXT,
    created_at    INTEGER,
    updated_at    INTEGER,
    system_prompt TEXT,
    temperature   REAL,
    max_tokens    INTEGER,
    top_p         REAL,
    thinking      INTEGER,
    is_deleted    INTEGER DEFAULT 0
  )
`

const SQL_MEMORIES: string = `
  CREATE TABLE IF NOT EXISTS MEMORIES (
    id         TEXT PRIMARY KEY,
    content    TEXT,
    date       TEXT,
    created_at INTEGER,
    updated_at INTEGER
  )
`

const SQL_SETTINGS: string = `
  CREATE TABLE IF NOT EXISTS SETTINGS (
    key   TEXT PRIMARY KEY,
    value TEXT
  )
`

const SQL_API_CONFIGS: string = `
  CREATE TABLE IF NOT EXISTS APICONFIGS (
    id         TEXT PRIMARY KEY,
    name       TEXT,
    platform   TEXT,
    base_url   TEXT,
    api_key    TEXT,
    created_at INTEGER
  )
`

/** 迁移标记表（标记是否完成 Preferences → RdbStore 迁移） */
const SQL_MIGRATION: string = `
  CREATE TABLE IF NOT EXISTS _MIGRATION (
    key   TEXT PRIMARY KEY,
    value TEXT
  )
`

class DatabaseHelper {
  private static instance: DatabaseHelper | null = null
  private rdb: relationalStore.RdbStore | null = null
  private readyPromise: Promise<void> | null = null
  private resolveReady: (() => void) | null = null
  /** 最近一次 cloudSync 的进度状态码 */
  private lastSyncCode: number = 0

  static getInstance(): DatabaseHelper {
    if (!DatabaseHelper.instance) {
      DatabaseHelper.instance = new DatabaseHelper()
    }
    return DatabaseHelper.instance
  }

  /** 获取 RdbStore 实例 */
  getStore(): relationalStore.RdbStore | null {
    return this.rdb
  }

  /**
   * 等待数据库就绪（供 storageService.init 调用，解决 EntryAbility 异步初始化的竞态问题）
   */
  async waitForReady(): Promise<void> {
    if (this.rdb) return
    if (!this.readyPromise) {
      this.readyPromise = new Promise<void>((resolve) => {
        this.resolveReady = resolve
      })
    }
    return this.readyPromise
  }

  /**
   * 初始化数据库（在 EntryAbility.onCreate 中调用一次）
   *
   * 自动检测旧版本数据库（v1：DISTRIBUTED_DEVICE 类型残留），
   * 发现后删除并重建，确保分布式表以 DISTRIBUTED_CLOUD 类型初始化。
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.rdb) return

    try {
      this.rdb = await relationalStore.getRdbStore(context, DB_CONFIG)

      // 建表
      await this.rdb.executeSql(SQL_CONVERSATIONS)
      await this.rdb.executeSql(SQL_MEMORIES)
      await this.rdb.executeSql(SQL_SETTINGS)
      await this.rdb.executeSql(SQL_API_CONFIGS)
      await this.rdb.executeSql(SQL_MIGRATION)

      // 增量迁移：按版本号补齐缺失列（绝不删库重建，避免数据丢失）
      await this.migrateSchema()

      // 表结构已就绪后，标记分布式表为云端同步模式
      const distConfig: relationalStore.DistributedConfig = {
        autoSync: true
      }
      try {
        await this.rdb.setDistributedTables(CLOUD_TABLES,
          relationalStore.DistributedType.DISTRIBUTED_CLOUD, distConfig)
        hilog.info(DOMAIN, TAG, 'setDistributedTables(DISTRIBUTED_CLOUD) OK')

        // 激活云端同步策略（未设置则默认 WIFI + 蜂窝网络，但显式调用确保服务启用）
        await cloudData.setCloudStrategy(cloudData.StrategyType.NETWORK,
          [cloudData.NetWorkStrategy.WIFI, cloudData.NetWorkStrategy.CELLULAR])
        hilog.info(DOMAIN, TAG, 'setCloudStrategy OK')
      } catch (distErr) {
        hilog.error(DOMAIN, TAG, 'setDistributedTables failed: %{public}s',
          JSON.stringify(distErr))
      }

      // 通知等待者数据库已就绪
      if (this.resolveReady) {
        this.resolveReady()
        this.resolveReady = null
      }

      hilog.info(DOMAIN, TAG, 'DatabaseHelper initialized, cloud tables: %{public}s',
        CLOUD_TABLES.join(', '))
    } catch (err) {
      // 通知等待者初始化失败
      if (this.resolveReady) {
        this.resolveReady()
        this.resolveReady = null
      }
      hilog.error(DOMAIN, TAG, 'DatabaseHelper init failed: %{public}s',
        (err instanceof Error ? err.message : JSON.stringify(err)))
      throw new Error('Database init failed')
    }
  }

  /**
   * 增量迁移：按版本号补齐缺失列。
   * 绝不 deleteRdbStore 全库重建，避免老用户数据丢失。
   */
  private async migrateSchema(): Promise<void> {
    if (!this.rdb) return
    let version: number = 0
    try {
      const predicates = new relationalStore.RdbPredicates('SETTINGS')
      predicates.equalTo('key', DB_VERSION_KEY)
      const result = await this.rdb.query(predicates)
      if (result.goToFirstRow()) {
        const val = result.getString(result.getColumnIndex('value'))
        version = val ? parseInt(val) : 0
      }
      result.close()
    } catch (err) {
      // 版本读取失败按 0 处理，走全量增量补齐
    }

    // v1 → v2：新增 is_deleted 软删除列（列已存在则静默忽略）
    if (version < 2) {
      try {
        await this.rdb.executeSql(
          'ALTER TABLE CONVERSATIONS ADD COLUMN is_deleted INTEGER DEFAULT 0')
        hilog.info(DOMAIN, TAG, 'Migration: added is_deleted column')
      } catch (_) {
        // 列已存在，忽略
      }
    }

    // （预留）v2 → v3：暂无新列

    await this.setVersion()
  }

  /**
   * 记录当前 schema 版本
   */
  private async setVersion(): Promise<void> {
    if (!this.rdb) return
    const vb: relationalStore.ValuesBucket = {
      'key': DB_VERSION_KEY,
      'value': CURRENT_DB_VERSION.toString()
    }
    await this.rdb.insert('SETTINGS', vb, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  }

  /**
   * 检查是否已完成 Preferences → RdbStore 迁移
   */
  async isMigrated(): Promise<boolean> {
    if (!this.rdb) return false
    try {
      const predicates = new relationalStore.RdbPredicates('_MIGRATION')
      predicates.equalTo('key', 'done')
      const result = await this.rdb.query(predicates)
      const rowCount = result.rowCount
      result.close()
      return rowCount > 0
    } catch (err) {
      return false
    }
  }

  /**
   * 标记迁移完成
   */
  async markMigrated(): Promise<void> {
    if (!this.rdb) return
    const valueBucket: relationalStore.ValuesBucket = {
      'key': 'done',
      'value': Date.now().toString()
    }
    try {
      await this.rdb.insert('_MIGRATION', valueBucket,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'markMigrated failed: %{public}s',
        JSON.stringify(err))
    }
  }

  /**
   * 手动触发端云同步（返回 Promise，便于调用方捕获错误）
   *
   * @param tables 需同步的表，默认全部
   * @param syncMode 同步模式
   * @returns 成功时 resolve({code, message})，失败时 reject 具体错误信息
   */
  cloudSync(
    tables: string[] = CLOUD_TABLES,
    syncMode: relationalStore.SyncMode = relationalStore.SyncMode.SYNC_MODE_TIME_FIRST
  ): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      if (!this.rdb) {
        reject('数据库未初始化')
        return
      }
      this.rdb.cloudSync(syncMode, tables,
        (progress: relationalStore.ProgressDetails) => {
          hilog.info(DOMAIN, TAG, 'Cloud sync progress: %{public}s',
            JSON.stringify(progress))
          if (progress.code !== undefined) {
            this.lastSyncCode = progress.code as number
          }
        },
        (err: BusinessError) => {
          if (err) {
            hilog.error(DOMAIN, TAG, 'Cloud sync error: %{public}s',
              err.message)
            reject(err.message || '云同步失败')
          } else {
            hilog.info(DOMAIN, TAG, 'Cloud sync completed')
            resolve()
          }
        }
      )
    })
  }

  /** 获取最近一次 cloudSync 的进度状态码 */
  getLastSyncCode(): number {
    return this.lastSyncCode
  }

  /**
   * 关闭数据库
   */
  async close(): Promise<void> {
    if (this.rdb) {
      await this.rdb.close()
      this.rdb = null
    }
  }
}

export const dbHelper = DatabaseHelper.getInstance()
