/**
 * LoginPage — 华为账号登录页面
 *
 * 严格按照华为账号开放登录规范：
 * - 红底白字「华为账号登录」按钮（无 Symbol）
 * - 隐私协议勾选后方可点击
 */
import { router } from '@kit.ArkUI'
import auth from '@hw-agconnect/auth'
import { promptAction } from '@kit.ArkUI'
import { ACCOUNT_LOGGED_IN, accountService } from '../services/AccountService'
import { storageService } from '../services/StorageService'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0000
const TAG = 'LoginPage'

@Entry
@Component
struct LoginPage {
  @State agreed: boolean = false
  @State loggingIn: boolean = false
  @StorageLink('currentColorMode') currentColorMode: number = 0
  @StorageLink('themeColor') themeColor: string = '#007DFF'

  build() {
    Column() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([this.currentColorMode === 1 ? '#333333' : '#CCCCCC'])
        }
        .width(40).height(40).backgroundColor('#00000000')
        .onClick(() => { router.back() })
      }
      .width('100%').height(96)
      .padding({ left: 8, top: 40 })

      Column() {
        // App Logo
        Column() {
          Image($r('app.media.WhaleChatLogo'))
            .width(64).height(64)
            .borderRadius(16)
        }
        .width(80).height(80).borderRadius(20)
        .backgroundColor(this.currentColorMode === 1 ? '#F0F0F0' : '#333333')
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 24 })

        Text('欢迎使用 WhaleChat')
          .fontSize(24).fontWeight(FontWeight.Bold)
          .fontColor(this.currentColorMode === 1 ? '#333333' : '#E0E0E0')
          .margin({ bottom: 8 })

        Text('登录华为账号以开启云同步和备份')
          .fontSize(14)
          .fontColor(this.currentColorMode === 1 ? '#6B6B6B' : '#AAAAAA')
          .margin({ bottom: 40 })

        // 隐私协议
        Row() {
          Checkbox()
            .select(this.agreed)
            .selectedColor(this.themeColor)
            .onChange((value: boolean) => { this.agreed = value })
            .width(20).height(20)

          Text('我已阅读并同意')
            .fontSize(13)
            .fontColor(this.currentColorMode === 1 ? '#6B6B6B' : '#AAAAAA')

          Text('《隐私协议》')
            .fontSize(13)
            .fontColor(this.themeColor)
        }
        .width('100%').margin({ bottom: 24 })
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Center)

        // 华为账号登录按钮 — 严格按照官方规范：红底白字，无 Symbol
        Button('华为账号登录')
          .fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .width('80%').height(48)
          .backgroundColor(this.agreed && !this.loggingIn ? '#CF0A2C' :
            (this.currentColorMode === 1 ? '#CCCCCC' : '#444444'))
          .borderRadius(24)
          .enabled(this.agreed && !this.loggingIn)
          .onClick(() => { this.doLogin() })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      Text('登录即表示您同意 WhaleChat 的服务条款')
        .fontSize(11)
        .fontColor(this.currentColorMode === 1 ? '#AAAAAA' : '#888888')
        .padding({ bottom: 32 })
    }
    .width('100%').height('100%')
    .backgroundColor(this.currentColorMode === 1 ? '#FFFFFF' : '#1A1A1A')
  }

  /**
   * 华为账号一键登录（AGC 认证服务）
   * 错误 "invalid authCode or clientInfo null" 通常表示：
   * 1. agconnect-services.json 未正确配置或未加载
   * 2. 应用签名与 AGC 平台注册的指纹不匹配
   */
  private async doLogin(): Promise<void> {
    if (!this.agreed || this.loggingIn) return
    this.loggingIn = true
    try {
      // 延迟初始化：仅用户勾选隐私协议后才调用
      await accountService.ensureAuthInit(getContext(this))
      // 清除可能残留的旧会话
      try { await auth.signOut() } catch (_) {}
      const result = await auth.signIn({
        autoCreateUser: true,
        credentialInfo: { kind: 'hwid' }
      })
      const user = result.getUser()
      AppStorage.set(ACCOUNT_LOGGED_IN, true)
      AppStorage.set('justLoggedIn', 'true')
      if (user) {
        AppStorage.set('huaweiNickname', user.getDisplayName() ?? '')
        AppStorage.set('huaweiAvatarUrl', user.getPhotoUrl() ?? '')
        // 个人开发者无 phone scope，不再存储手机号；UnionID 由 AccountKit 静默检测获取
      }
      promptAction.showToast({ message: '登录成功' })
      router.back()
    } catch (err) {
      const errStr = JSON.stringify(err)
      hilog.error(DOMAIN, TAG, 'AGC login failed: %{public}s', errStr)
      let displayMsg = errStr
      try {
        const bizErr = err as BusinessError
        let msg: string = bizErr.message
        if (!msg) { msg = errStr }
        displayMsg = msg
      } catch (_) {}
      promptAction.showToast({ message: '登录失败: ' + displayMsg, duration: 3000 })
    } finally {
      this.loggingIn = false
    }
  }
}
