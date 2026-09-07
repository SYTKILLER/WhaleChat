/**
 * CloudBackupService — 华为云空间备份管理服务
 *
 * 管理云备份开关状态和备份数据选择，通过 Preferences 持久化。
 * 实际备份由 BackupExtensionAbility + 系统备份框架自动执行，
 * 本服务控制 UI 层面的开关状态。
 */
import { storageService } from './StorageService'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x000A
const TAG = 'CloudBackupService'

/** 备份数据类型 */
export interface BackupDataSelection {
  conversations: boolean  // 对话列表
  memories: boolean       // 永久记忆
  settings: boolean       // 应用设置（主题色等）
  apiConfigs: boolean     // API 配置
}

/** 默认备份选择：全部开启 */
export const DEFAULT_BACKUP_SELECTION: BackupDataSelection = {
  conversations: true,
  memories: true,
  settings: true,
  apiConfigs: true
}

/** Preferences 存储键 */
const KEY_BACKUP_ENABLED = 'cloud_backup_enabled'
const KEY_BACKUP_SELECTION = 'cloud_backup_selection'

class CloudBackupService {
  private static instance: CloudBackupService | null = null
  private isInit: boolean = false

  static getInstance(): CloudBackupService {
    if (!CloudBackupService.instance) {
      CloudBackupService.instance = new CloudBackupService()
    }
    return CloudBackupService.instance
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.isInit) {
      return
    }
    await storageService.init(context)
    this.isInit = true
  }

  /**
   * 获取云备份是否启用。
   */
  async isBackupEnabled(): Promise<boolean> {
    if (!this.isInit) {
      return false
    }
    return storageService.getBoolean(KEY_BACKUP_ENABLED, false)
  }

  /**
   * 设置云备份开关。
   */
  async setBackupEnabled(enabled: boolean): Promise<void> {
    if (!this.isInit) {
      return
    }
    await storageService.setBoolean(KEY_BACKUP_ENABLED, enabled)
    hilog.info(DOMAIN, TAG, 'Cloud backup %{public}s', enabled ? 'enabled' : 'disabled')
  }

  /**
   * 获取备份数据选择。
   */
  async getBackupSelection(): Promise<BackupDataSelection> {
    if (!this.isInit) {
      return DEFAULT_BACKUP_SELECTION
    }
    const saved = await storageService.getString(KEY_BACKUP_SELECTION, '')
    if (saved.length > 0) {
      try {
        return JSON.parse(saved) as BackupDataSelection
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'Failed to parse backup selection, using defaults')
      }
    }
    return DEFAULT_BACKUP_SELECTION
  }

  /**
   * 保存备份数据选择。
   */
  async saveBackupSelection(selection: BackupDataSelection): Promise<void> {
    if (!this.isInit) {
      return
    }
    await storageService.setString(KEY_BACKUP_SELECTION, JSON.stringify(selection))
  }
}

export const cloudBackupService = CloudBackupService.getInstance()
