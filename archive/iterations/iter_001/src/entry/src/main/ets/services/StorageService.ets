/**
 * 存储服务 — 加密存储 API Key，管理本地数据持久化
 *
 * 使用 @kit.ArkData preferences 作为底层存储，
 * API Key 通过 @ohos.security.cryptoFramework 进行 AES-256-GCM 加密后存储。
 */

import { preferences } from '@kit.ArkData'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { util } from '@kit.ArkTS'
import { STORAGE_KEYS } from '../common/Constants'
import { ApiConfig, createDefaultApiConfig } from '../models/ApiConfig'
import { Conversation } from '../models/Conversation'
import { Memory } from '../models/Memory'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0001
const TAG = 'StorageService'

/** AES-256-GCM 密钥别名 */
const KEY_ALIAS = 'deepchat_encryption_key'
/** 固定 IV 前缀（实际生产环境应使用随机 IV） */
const IV_BYTES: number = 12
/** GCM Tag 长度 */
const TAG_LENGTH: number = 16

class StorageService {
  private dataPreferences: preferences.Preferences | null = null
  private encryptKey: cryptoFramework.SymKey | null = null
  private cipher: cryptoFramework.Cipher | null = null
  private initialized: boolean = false

  /**
   * 初始化存储服务
   */
  async init(context: Context): Promise<void> {
    if (this.initialized) {
      return
    }
    try {
      // 初始化 preferences
      this.dataPreferences = await preferences.getPreferences(context, 'deepchat_store')

      // 初始化加密模块
      await this.initEncryption()

      this.initialized = true
      hilog.info(DOMAIN, TAG, 'StorageService initialized')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'StorageService init failed: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 初始化 AES-256-GCM 加密
   * 使用固定应用密钥派生，生产环境应使用 HUKS 安全存储密钥。
   */
  private async initEncryption(): Promise<void> {
    try {
      // 从应用常量派生密钥材料（32 字节用于 AES-256）
      const keyMaterial = 'DeepChat_HarmonyOS_AES256_Key_Derivation_2024_v1.0'

      // 构建 SymKeyGenerator
      const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256')

      // 将派生密钥转换为 Uint8Array (取前 32 字节)
      const encoder = new util.TextEncoder()
      const keyBytes = encoder.encodeInto(keyMaterial)
      const aesKeyData = new Uint8Array(32)
      for (let i = 0; i < 32; i++) {
        aesKeyData[i] = i < keyBytes.length ? keyBytes[i] : 0
      }

      // 使用 SymKeyGenerator 转换密钥
      const keyBlob: cryptoFramework.DataBlob = { data: aesKeyData }
      this.encryptKey = symKeyGenerator.convertKey(keyBlob)

      // 创建 Cipher 实例
      this.cipher = cryptoFramework.createCipher('AES256|GCM|PKCS7')

      hilog.info(DOMAIN, TAG, 'Encryption initialized')
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Encryption init failed, using base64 fallback: %{public}s', JSON.stringify(err))
      // 加密初始化失败时，cipher/encryptKey 保持 null，后续走降级路径
    }
  }

  /**
   * 生成随机 IV
   */
  private generateIv(): Uint8Array {
    const iv = new Uint8Array(IV_BYTES)
    for (let i = 0; i < IV_BYTES; i++) {
      iv[i] = Math.floor(Math.random() * 256)
    }
    return iv
  }

  /**
   * 加密字符串 (AES-256-GCM)
   * 格式: "AES:" + Base64( IV(12) + 密文 + AuthTag(16) )
   * 降级: "B64:" + Base64(明文)
   */
  async encrypt(plaintext: string): Promise<string> {
    if (!this.cipher || !this.encryptKey) {
      // 降级：仅 Base64 编码
      const encoder = new util.TextEncoder()
      const bytes = encoder.encodeInto(plaintext)
      const base64Helper = new util.Base64Helper()
      return 'B64:' + base64Helper.encodeToStringSync(bytes)
    }

    try {
      const iv = this.generateIv()
      const ivBlob: cryptoFramework.DataBlob = { data: iv }

      // GCM 参数 — doFinal 后 authTag 会被自动填充
      const gcmParams: cryptoFramework.GcmParamsSpec = {
        algName: 'GcmParamsSpec',
        iv: ivBlob,
        aad: { data: new Uint8Array(0) },
        authTag: { data: new Uint8Array(TAG_LENGTH) }
      }

      await this.cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, this.encryptKey, gcmParams)

      const encoder = new util.TextEncoder()
      const plainData: cryptoFramework.DataBlob = { data: encoder.encodeInto(plaintext) }
      const encrypted = await this.cipher.doFinal(plainData)

      // 获取生成的真实 AuthTag
      const authTag = new Uint8Array(gcmParams.authTag.data)

      // 拼接: IV + 密文 + AuthTag，然后 Base64
      const combined = new Uint8Array(IV_BYTES + encrypted.data.length + TAG_LENGTH)
      combined.set(iv, 0)
      combined.set(encrypted.data, IV_BYTES)
      combined.set(authTag, IV_BYTES + encrypted.data.length)

      const base64Helper = new util.Base64Helper()
      return 'AES:' + base64Helper.encodeToStringSync(combined)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Encrypt failed, falling back: %{public}s', JSON.stringify(err))
      const encoder = new util.TextEncoder()
      const bytes = encoder.encodeInto(plaintext)
      const base64Helper = new util.Base64Helper()
      return 'B64:' + base64Helper.encodeToStringSync(bytes)
    }
  }

  /**
   * 解密字符串
   * 自动识别 "AES:" (加密) 和 "B64:" (降级) 格式
   */
  async decrypt(encryptedText: string): Promise<string> {
    // 降级格式
    if (encryptedText.startsWith('B64:')) {
      try {
        const base64Helper = new util.Base64Helper()
        const bytes = base64Helper.decodeSync(encryptedText.substring(4))
        const decoder = new util.TextDecoder()
        return decoder.decodeToString(bytes)
      } catch (e) {
        return ''
      }
    }

    // AES 加密格式
    const isAes = encryptedText.startsWith('AES:')
    const rawData = isAes ? encryptedText.substring(4) : encryptedText

    if (!this.cipher || !this.encryptKey || !isAes) {
      // 旧格式或加密不可用，尝试 Base64 解码
      try {
        const base64Helper = new util.Base64Helper()
        const bytes = base64Helper.decodeSync(rawData)
        const decoder = new util.TextDecoder()
        return decoder.decodeToString(bytes)
      } catch (e) {
        return ''
      }
    }

    try {
      const base64Helper = new util.Base64Helper()
      const combined = base64Helper.decodeSync(rawData)

      // 拆分: IV(12) + 密文(剩余-16) + AuthTag(16)
      const iv = combined.slice(0, IV_BYTES)
      const authTagStart = combined.length - TAG_LENGTH
      const ciphertext = combined.slice(IV_BYTES, authTagStart)
      const authTag = combined.slice(authTagStart)

      const ivBlob: cryptoFramework.DataBlob = { data: new Uint8Array(iv) }
      const cipherBlob: cryptoFramework.DataBlob = { data: new Uint8Array(ciphertext) }

      const gcmParams: cryptoFramework.GcmParamsSpec = {
        algName: 'GcmParamsSpec',
        iv: ivBlob,
        aad: { data: new Uint8Array(0) },
        authTag: { data: new Uint8Array(authTag) }
      }

      await this.cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, this.encryptKey, gcmParams)
      const decrypted = await this.cipher.doFinal(cipherBlob)

      const decoder = new util.TextDecoder()
      return decoder.decodeToString(decrypted.data)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'AES decrypt failed: %{public}s', JSON.stringify(err))
      // 尝试纯 Base64 降级
      try {
        const base64Helper = new util.Base64Helper()
        const bytes = base64Helper.decodeSync(rawData)
        const decoder = new util.TextDecoder()
        return decoder.decodeToString(bytes)
      } catch (e2) {
        return ''
      }
    }
  }

  // ========== API 配置 ==========

  /**
   * 保存 API 配置（API Key 加密存储）
   */
  async saveApiConfig(config: ApiConfig): Promise<void> {
    if (!this.dataPreferences) {
      hilog.error(DOMAIN, TAG, 'Preferences not initialized')
      return
    }
    try {
      const encryptedKey = await this.encrypt(config.apiKey)
      const configToStore = {
        ...config,
        apiKey: encryptedKey
      }
      await this.dataPreferences.put(STORAGE_KEYS.API_CONFIG, JSON.stringify(configToStore))
      await this.dataPreferences.flush()
      hilog.info(DOMAIN, TAG, 'API config saved')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Save API config failed: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 加载 API 配置（API Key 解密）
   */
  async loadApiConfig(): Promise<ApiConfig> {
    if (!this.dataPreferences) {
      return createDefaultApiConfig()
    }
    try {
      const json = await this.dataPreferences.get(STORAGE_KEYS.API_CONFIG, '') as string
      if (!json) {
        return createDefaultApiConfig()
      }
      const stored = JSON.parse(json) as ApiConfig & { apiKey: string }
      const decryptedKey = await this.decrypt(stored.apiKey)
      return {
        ...stored,
        apiKey: decryptedKey
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Load API config failed: %{public}s', JSON.stringify(err))
      return createDefaultApiConfig()
    }
  }

  // ========== 对话列表 ==========

  /**
   * 保存对话列表
   */
  async saveConversations(conversations: Conversation[]): Promise<void> {
    if (!this.dataPreferences) return
    try {
      await this.dataPreferences.put(STORAGE_KEYS.CONVERSATIONS, JSON.stringify(conversations))
      await this.dataPreferences.flush()
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Save conversations failed: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 加载对话列表
   */
  async loadConversations(): Promise<Conversation[]> {
    if (!this.dataPreferences) return []
    try {
      const json = await this.dataPreferences.get(STORAGE_KEYS.CONVERSATIONS, '[]') as string
      return JSON.parse(json) as Conversation[]
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Load conversations failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  // ========== 永久记忆 ==========

  /**
   * 保存记忆列表
   */
  async saveMemories(memories: Memory[]): Promise<void> {
    if (!this.dataPreferences) return
    try {
      await this.dataPreferences.put(STORAGE_KEYS.MEMORIES, JSON.stringify(memories))
      await this.dataPreferences.flush()
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Save memories failed: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 加载记忆列表
   */
  async loadMemories(): Promise<Memory[]> {
    if (!this.dataPreferences) return []
    try {
      const json = await this.dataPreferences.get(STORAGE_KEYS.MEMORIES, '[]') as string
      return JSON.parse(json) as Memory[]
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Load memories failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  // ========== 通用偏好 ==========

  /**
   * 保存是否已完成首次配置
   */
  async setHasLaunched(value: boolean): Promise<void> {
    if (!this.dataPreferences) return
    await this.dataPreferences.put(STORAGE_KEYS.HAS_LAUNCHED, value)
    await this.dataPreferences.flush()
  }

  /**
   * 获取是否已完成首次配置
   */
  async hasLaunched(): Promise<boolean> {
    if (!this.dataPreferences) return false
    try {
      return await this.dataPreferences.get(STORAGE_KEYS.HAS_LAUNCHED, false) as boolean
    } catch (err) {
      return false
    }
  }
}

/** 全局单例 */
export const storageService = new StorageService()
