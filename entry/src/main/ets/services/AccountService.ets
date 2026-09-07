/**
 * AccountService — 华为账号状态管理 + AGC 认证 SDK 延迟初始化
 *
 * 合规要求：AGC SDK 仅在用户同意隐私协议后才初始化。
 * ensureAuthInit() 幂等，LoginPage 点击"同意"后才触发首次 init。
 */
import auth from '@hw-agconnect/auth'
import { util } from '@kit.ArkTS'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0003
const TAG = 'AccountService'

/** AppStorage key，供 @StorageLink 绑定 */
export const ACCOUNT_LOGGED_IN: string = 'account_logged_in'
/** 华为账号 UnionID 的 AppStorage key（个人开发者可用，替代 phone 作为认证凭证） */
export const HUAWEI_UNION_ID: string = 'huawei_union_id'

class AccountService {
  private static instance: AccountService | null = null

  static getInstance(): AccountService {
    if (!AccountService.instance) {
      AccountService.instance = new AccountService()
    }
    return AccountService.instance
  }

  /**
   * 延迟初始化 AGC 认证 SDK（仅在用户同意隐私协议后调用）
   * 幂等操作，多次调用仅首次生效
   */
  async ensureAuthInit(context: Context): Promise<void> {
    if (AppStorage.get<boolean>('auth_initialized')) { return }
    try {
      const file = context.resourceManager.getRawFileContentSync('agconnect-services.json')
      const decoder = new util.TextDecoder('utf-8')
      const json: string = decoder.decodeToString(file, { stream: false })
      auth.init(context, json)
      AppStorage.setOrCreate('auth_initialized', true)
      hilog.info(DOMAIN, TAG, 'AGC auth initialized (lazy)')
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'AGC auth init failed: %{public}s', JSON.stringify(err))
    }
  }

  /** 退出华为账号。 */
  async logout(): Promise<void> {
    AppStorage.set(ACCOUNT_LOGGED_IN, false)
    hilog.info(DOMAIN, TAG, 'Logout')
  }
}

export const accountService = AccountService.getInstance()
