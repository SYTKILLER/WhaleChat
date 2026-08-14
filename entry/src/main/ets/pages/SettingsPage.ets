/**
 * SettingsPage — 设置页面
 *
 * 主题切换、记忆管理、API 配置、导入导出入口
 */

import { router } from '@kit.ArkUI'
import { ConfigurationConstant, common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { util } from '@kit.ArkTS'
import { authentication } from '@kit.AccountKit'
import { Memory, createMemory } from '../models/Memory'
import { storageService } from '../services/StorageService'
import { LucideIcon, LucideIcons } from '../components/LucideIcon'
import { ROUTES, APP_INFO, THEME_COLORS, DEFAULT_THEME_COLOR, ThemeColorItem, STORAGE_KEYS } from '../common/Constants'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { picker } from '@kit.CoreFileKit'
import { saveConversations } from '../utils/ExportHelper'
import { tryImportFromUri } from '../services/ImportService'
import { readFileFromUri } from '../utils/FileHelper'
import { Conversation } from '../models/Conversation'
import { accountService, ACCOUNT_LOGGED_IN, HUAWEI_UNION_ID } from '../services/AccountService'
import { cloudBackupService, BackupDataSelection, DEFAULT_BACKUP_SELECTION } from '../services/CloudBackupService'
import { syncService } from '../services/SyncService'
import auth from '@hw-agconnect/auth'

const DOMAIN = 0x0006
const TAG = 'SettingsPage'

@Preview({ title: '设置页 - 浅色', width: 390, height: 844 })
@Preview({ title: '设置页 - 深色', width: 390, height: 844, colorMode: 'dark' })
@Entry
@Component
export struct SettingsPage {
  @State memories: Memory[] = []
  @State colorModeIndex: number = 0
  @StorageLink('themeColor') themeColor: string = DEFAULT_THEME_COLOR
  @StorageLink('currentColorMode') currentColorMode: number = 0
  @State showCustomColor: boolean = false
  @State themeColorExpanded: boolean = false
  @State customColorInput: string = ''
  @State showExportDialog: boolean = false
  @State exportCandidates: Conversation[] = []
  @State exportChecked: boolean[] = []
  // 账号与云同步
  @StorageLink(ACCOUNT_LOGGED_IN) accountLoggedIn: boolean = false
  @State backupEnabled: boolean = false
  @State showAccountTip: boolean = false
  @State showBackupTip: boolean = false
  @State showBackupSelect: boolean = false
  @State backupSelection: BackupDataSelection = DEFAULT_BACKUP_SELECTION
  // 记忆更新信号 — MemoryPage 增删后触发，绕过 onPageShow 依赖
  @StorageLink('memoryUpdateKey') @Watch('reloadMemories') memoryUpdateKey: string = ''
  // 华为账号头像与昵称
  @StorageLink('huaweiNickname') huaweiNickname: string = ''
  @StorageLink('huaweiAvatarUrl') huaweiAvatarUrl: string = ''
  @StorageLink(HUAWEI_UNION_ID) huaweiUnionId: string = ''

  aboutToAppear(): void {
    this.loadData()
  }

  /** 从 MemoryPage 返回时刷新 */
  onPageShow(): void {
    this.loadData()
  }

  /** 记忆增删信号触发 — 仅刷新计数，不打完整 loadData */
  reloadMemories(): void {
    storageService.init(getContext(this)).then(() => {
      storageService.loadMemories().then(m => { this.memories = m })
    })
  }

  async loadData(): Promise<void> {
    try {
      await storageService.init(getContext(this))
      this.memories = await storageService.loadMemories()

      // 通过 AGC SDK 验证真实登录会话
      try {
        await accountService.ensureAuthInit(getContext(this))
        const currentUser = await auth.getCurrentUser()
        if (currentUser) {
          AppStorage.set(ACCOUNT_LOGGED_IN, true)
        }
        // AGC 先写，AccountKit 后续补充
        if (currentUser && currentUser.getDisplayName()) {
          AppStorage.set('huaweiNickname', currentUser.getDisplayName() ?? '')
        }
        if (currentUser && currentUser.getPhotoUrl()) {
          AppStorage.set('huaweiAvatarUrl', currentUser.getPhotoUrl() ?? '')
        }
        // 个人开发者无 phone scope，不再存储手机号（认证凭证改用 UnionID）
      } catch (_) {}
      await this.checkLoginStatus()

      // 加载云备份状态
      await cloudBackupService.init(getContext(this) as common.UIAbilityContext)
      this.backupEnabled = await cloudBackupService.isBackupEnabled()

      // 加载颜色模式选择（0=跟随系统 1=浅色 2=深色），持久化并同步到云端 SETTINGS
      const modeStr = await storageService.getString(STORAGE_KEYS.THEME_MODE, '0')
      this.colorModeIndex = parseInt(modeStr)
      this.applyColorMode(this.colorModeIndex)

    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Load failed')
    }
  }

  private applyColorMode(index: number): void {
    const ctx = getContext(this)
    if (index === 0) {
      ctx.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    } else if (index === 1) {
      ctx.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
      AppStorage.setOrCreate('currentColorMode', ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
    } else {
      ctx.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
      AppStorage.setOrCreate('currentColorMode', ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
    }
  }

  /**
   * 静默检测华为账号是否已登录（不弹窗）
   */
  private async checkLoginStatus(): Promise<void> {
    try {
      const provider = new authentication.HuaweiIDProvider()
      const loginRequest = provider.createLoginWithHuaweiIDRequest()
      loginRequest.forceLogin = false
      loginRequest.state = util.generateRandomUUID()

      const controller = new authentication.AuthenticationController(
        this.getUIContext().getHostContext()
      )

      await new Promise<void>((resolve, reject) => {
        controller.executeRequest(loginRequest, (err: Error, data: Object) => {
          if (err) {
            reject(err)
            return
          }
          const loginResp = data as authentication.LoginWithHuaweiIDResponse
          if (loginResp?.data) {
            // 存储 UnionID（个人开发者可用，替代 phone 作为认证凭证）
            this.huaweiUnionId = loginResp.data.unionID || ''
            console.info(`Silent login OK, unionID: ${loginResp.data.unionID}`)
          }
          resolve()
        })
      })

      // 静默获取头像与昵称
      await this.fetchProfileSilently()
    } catch (err) {
      console.info('Silent login: user not logged in')
      // 静默检测不改变登录状态
    }
  }
  private async fetchProfileSilently(): Promise<void> {
    try {
      const provider = new authentication.HuaweiIDProvider()
      const authReq: authentication.AuthorizationWithHuaweiIDRequest =
        provider.createAuthorizationWithHuaweiIDRequest()
      authReq.scopes = ['openid', 'profile']
      authReq.forceAuthorization = false
      authReq.state = util.generateRandomUUID()

      const controller = new authentication.AuthenticationController(
        this.getUIContext().getHostContext()
      )

      await new Promise<void>((resolve, reject) => {
        controller.executeRequest(authReq, (err: Error, data: Object) => {
          if (err) {
            reject(err)
            return
          }
          const resp = data as authentication.AuthorizationWithHuaweiIDResponse
          if (resp?.data) {
            if (!this.huaweiNickname) { this.huaweiNickname = resp.data.nickName || '' }
            if (!this.huaweiAvatarUrl) { this.huaweiAvatarUrl = resp.data.avatarUri || '' }
            if (!this.huaweiUnionId) { this.huaweiUnionId = resp.data.unionID || '' }
          }
          resolve()
        })
      })
    } catch (err) {
      // 静默失败：用户可能尚未授权 profile scope
    }
  }

  /**
   * 华为账号一键登录 — 弹出系统对话框并获取头像昵称
   */
  private async handleLogin(): Promise<void> {
    try {
      const provider = new authentication.HuaweiIDProvider()
      const authReq: authentication.AuthorizationWithHuaweiIDRequest =
        provider.createAuthorizationWithHuaweiIDRequest()
      authReq.scopes = ['openid', 'profile']
      authReq.forceAuthorization = true // 弹出系统确认对话框
      authReq.state = util.generateRandomUUID()

      const controller = new authentication.AuthenticationController(
        this.getUIContext().getHostContext()
      )

      await new Promise<void>((resolve, reject) => {
        controller.executeRequest(authReq, (err: Error, data: Object) => {
          if (err) {
            reject(err)
            return
          }
          const resp = data as authentication.AuthorizationWithHuaweiIDResponse
          if (resp?.state && resp.state !== authReq.state) {
            reject(new Error('State mismatch'))
            return
          }
          const cred = resp?.data
          if (cred) {
            this.huaweiNickname = cred.nickName || ''
            this.huaweiAvatarUrl = cred.avatarUri || ''
            this.huaweiUnionId = cred.unionID || ''
            AppStorage.set(ACCOUNT_LOGGED_IN, true)
            storageService.setString('account_logged_in', 'true')
            promptAction.showToast({ message: '登录成功' })
            resolve()
          } else {
            reject(new Error('No credential in response'))
          }
        })
      })
    } catch (err) {
      const errStr = JSON.stringify(err)
      console.error('Login failed: ' + errStr)
      const bizErr = err as Record<string, Object>
      const code = bizErr['code'] as number | undefined
      const msg = (bizErr['message'] as string) ?? errStr
      const displayMsg = code ? `[${code}] ${msg}` : msg
      promptAction.showToast({ message: '登录失败: ' + displayMsg, duration: 3000 })
    }
  }

  /**
   * 华为账号退出
   */
  private async handleLogout(): Promise<void> {
    // 清除 AGC 认证服务本地 token 缓存
    try { await auth.signOut() } catch (_) {}
    await accountService.logout()
    this.huaweiNickname = ''
    this.huaweiAvatarUrl = ''
    this.huaweiUnionId = ''
    this.backupEnabled = false
    await cloudBackupService.setBackupEnabled(false)
  }

  /**
   * 切换云备份开关
   */
  private async toggleBackup(): Promise<void> {
    if (!this.accountLoggedIn) {
      this.showAccountTip = true
      return
    }
    if (!this.backupEnabled) {
      // 首次开启时显示隐私提示
      this.showBackupTip = true
    } else {
      this.backupEnabled = false
      await cloudBackupService.setBackupEnabled(false)
    }
  }

  /**
   * 确认开启云备份（从半模态面板确认后）
   */
  private async confirmEnableBackup(): Promise<void> {
    this.showBackupTip = false
    this.backupEnabled = true
    await cloudBackupService.setBackupEnabled(true)
  }

  /**
   * 手动立即备份：根据用户选择的备份内容触发 Cloud Kit 云同步
   */
  private async handleManualBackup(): Promise<void> {
    if (!this.backupEnabled || !this.accountLoggedIn) {
      promptAction.showToast({ message: '请先开启云备份并登录华为账号' })
      return
    }
    try {
      const selection: BackupDataSelection =
        await cloudBackupService.getBackupSelection()
      let count: number = 0
      const errors: string[] = []
      if (selection.conversations) {
        try {
          await syncService.pushConversations()
          count++
        } catch (err) {
          const msg: string = typeof err === 'string' ? err : JSON.stringify(err)
          errors.push('对话: ' + msg)
        }
      }
      if (selection.memories) {
        try {
          await syncService.pushMemories()
          count++
        } catch (err) {
          const msg: string = typeof err === 'string' ? err : JSON.stringify(err)
          errors.push('记忆: ' + msg)
        }
      }
      // 同步后刷新记忆计数
      storageService.loadMemories().then(m => { this.memories = m })
      if (selection.apiConfigs) {
        try {
          await syncService.pushApiConfigs()
          count++
        } catch (err) {
          const msg: string = typeof err === 'string' ? err : JSON.stringify(err)
          errors.push('API配置: ' + msg)
        }
      }
      if (errors.length > 0) {
        const errText: string = errors.join('；')
        if (errText.includes('401')) {
          promptAction.showToast({
            message: '云同步未授权(401)：请确认 AGC 云侧已正确配置、设备已登录华为账号且应用使用正式签名',
            duration: 4000
          })
        } else {
          promptAction.showToast({ message: '部分失败: ' + errText, duration: 3000 })
        }
      } else if (count > 0) {
        const statusMsg: string = syncService.getLastSyncMessage()
        promptAction.showToast({
          message: '已备份 ' + count.toString() + ' 项: ' + statusMsg,
          duration: 2000
        })
        this.loadData()
      } else {
        promptAction.showToast({ message: '未选择任何备份内容' })
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Manual backup failed: %{public}s', JSON.stringify(err))
      promptAction.showToast({ message: '备份失败: ' + JSON.stringify(err) })
    }
  }

  /**
   * 保存备份数据选择
   */
  private async saveBackupSelection(): Promise<void> {
    await cloudBackupService.saveBackupSelection(this.backupSelection)
    this.showBackupSelect = false
  }

  /**
   * 显示导出选择弹窗
   */
  private async showExportPicker(): Promise<void> {
    try {
      const conversations: Conversation[] = await storageService.loadConversations()
      if (conversations.length === 0) {
        return
      }
      this.exportCandidates = conversations
      this.exportChecked = new Array<boolean>(conversations.length).fill(true)
      animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
        this.showExportDialog = true
      })
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Load for export failed: ${err}`)
    }
  }

  /**
   * 关闭导出弹窗
   */
  private closeExportDialog(): void {
    animateTo({ duration: 200, curve: Curve.EaseIn }, () => {
      this.showExportDialog = false
    })
  }

  /**
   * 导出选中的对话为 MD 文件
   */
  private async exportSelectedConversations(): Promise<void> {
    try {
      const selected: Conversation[] = []
      for (let i = 0; i < this.exportCandidates.length; i++) {
        if (this.exportChecked[i]) {
          selected.push(this.exportCandidates[i])
        }
      }
      if (selected.length === 0) return

      await saveConversations(getContext(this) as common.UIAbilityContext, selected)
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Export failed: ${err}`)
    }
  }

  /**
   * 全选 / 取消全选
   */
  private toggleSelectAll(): void {
    const allChecked: boolean = this.exportChecked.every((v: boolean) => v)
    for (let i = 0; i < this.exportChecked.length; i++) {
      this.exportChecked[i] = !allChecked
    }
  }

  /**
   * 格式化导出列表中的日期
   */
  private formatExportDate(timestamp: number): string {
    if (!timestamp) return ''
    try {
      const d = new Date(timestamp)
      const m = (d.getMonth() + 1).toString().padStart(2, '0')
      const day = d.getDate().toString().padStart(2, '0')
      const h = d.getHours().toString().padStart(2, '0')
      const min = d.getMinutes().toString().padStart(2, '0')
      return `${m}-${day} ${h}:${min}`
    } catch (e) {
      return ''
    }
  }

  /**
   * 从 MD 文件导入对话
   */
  private async importConversations(): Promise<void> {
    try {
      const documentPicker = new picker.DocumentViewPicker()
      const selectOptions = new picker.DocumentSelectOptions()
      selectOptions.maxSelectNumber = 10
      selectOptions.selectMode = picker.DocumentSelectMode.FILE
      const selectResult: string[] = await documentPicker.select(selectOptions)

      if (selectResult.length === 0) return

      let importedCount: number = 0
      for (let i = 0; i < selectResult.length; i++) {
        const uri: string = selectResult[i]
        const convs: Conversation[] = await tryImportFromUri(getContext(this), uri)
        importedCount += convs.length
      }

      if (importedCount > 0) {
        AppStorage.setOrCreate('convListRefreshKey', `settings_import_${Date.now()}`)
        hilog.info(DOMAIN, TAG, `Imported ${importedCount} conversations`)
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Import failed: ${err}`)
    }
  }

  build() {
    Stack() {
    Column() {
      Row() {
        Text('设置')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(112)
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: this.currentColorMode === 1 ?
          [['rgba(242, 242, 242, 1.0)', 0.0], ['rgba(242, 242, 242, 0.3)', 1.0]] :
          [['rgba(18, 18, 18, 1.0)', 0.0], ['rgba(18, 18, 18, 0.3)', 1.0]]
      })
      .backgroundBlurStyle(BlurStyle.Regular)
      .padding({ left: 20, right: 20, top: 48, bottom: 16 })
      .borderWidth({ bottom: 0.5 })
      .borderColor(this.currentColorMode === 1 ? '#E0E0E0' : '#444444')

      List() {
        // ── 账号 ──
        ListItemGroup({ header: this.SectionHeaderGroup('账号') }) {
          // 华为账号状态
          ListItem() {
            Row() {
              // 登录后显示头像，否则显示图标
              if (this.accountLoggedIn && this.huaweiAvatarUrl) {
                Image(this.huaweiAvatarUrl)
                  .width(36)
                  .height(36)
                  .borderRadius(18)
                  .objectFit(ImageFit.Cover)
                  .margin({ right: 12 })
              } else {
                LucideIcon({ icon: LucideIcons.USER, iconSize: 20,
                  color: this.accountLoggedIn ? this.themeColor : (this.currentColorMode === 1 ? '#6B6B6B' : '#AAAAAA') })
                  .margin({ right: 12 })
              }
              Column() {
                Text(this.accountLoggedIn
                  ? (this.huaweiNickname || '华为账号已登录')
                  : '未登录华为账号')
                  .fontSize(15)
                  .fontColor(this.currentColorMode === 1 ? '#333333' : '#EEEEEE')
                if (this.accountLoggedIn) {
                  Text(this.huaweiUnionId ? '已认证' : '多设备同步已可用')
                    .fontSize(12)
                    .fontColor(this.currentColorMode === 1 ? '#6B6B6B' : '#AAAAAA')
                    .margin({ top: 2 })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Button(this.accountLoggedIn ? '退出' : '登录')
                .fontSize(13)
                .type(ButtonType.Capsule)
                .backgroundColor(this.accountLoggedIn ? '#FF3B30' : this.themeColor)
                .onClick(() => {
                  if (this.accountLoggedIn) {
                    this.handleLogout()
                  } else {
                    router.pushUrl({ url: 'pages/LoginPage' })
                  }
                })
                .borderRadius(16)
                .height(32)
                .padding({ left: 16, right: 16 })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          }

        }
        .divider({ strokeWidth: 0.5, startMargin: 16, endMargin: 16, color: this.currentColorMode === 1 ? '#E0E0E0' : '#444444' })

        // 组间间距
        ListItem() {
          Row().height(8).width('100%')
            .backgroundColor(Color.Transparent)
        }

        // ── API 配置 ──
        ListItemGroup({ header: this.SectionHeaderGroup('API 配置') }) {
          ListItem() {
            this.SettingItem('API 平台配置', '管理多个 API 配置',
              () => { router.pushUrl({ url: ROUTES.API_MANAGEMENT }) })
          }
        }
        .divider({ strokeWidth: 0.5, startMargin: 16, endMargin: 16, color: this.currentColorMode === 1 ? '#E0E0E0' : '#444444' })

        // 组间间距
        ListItem() {
          Row().height(8).width('100%')
            .backgroundColor(Color.Transparent)
        }

        // ── 外观 ──
        ListItemGroup({ header: this.SectionHeaderGroup('外观') }) {
          ListItem() {
            Row() {
              Text('深色模式').fontSize(15).layoutWeight(1)
              Select([{ value: '跟随系统' }, { value: '浅色' }, { value: '深色' }])
                .selected(this.colorModeIndex)
                .value(this.colorModeIndex === 0 ? '跟随系统' : this.colorModeIndex === 1 ? '浅色' : '深色')
                .font({ size: 13 })
                .fontColor($r('app.color.text_secondary'))
                .onSelect((index: number) => {
                  this.colorModeIndex = index
                  storageService.setString(STORAGE_KEYS.THEME_MODE, index.toString())
                  this.applyColorMode(index)
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          }
          ListItem() {
            Column() {
              Row() {
                Text('主题颜色').fontSize(15)
                Blank()
                LucideIcon({
                  icon: this.themeColorExpanded ? LucideIcons.CHEVRON_UP : LucideIcons.CHEVRON_DOWN,
                  iconSize: 16,
                  color: this.currentColorMode === 1 ? '#6B6B6B' : '#999999'
                })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: this.themeColorExpanded ? 8 : 12 })
              .onClick(() => {
                this.themeColorExpanded = !this.themeColorExpanded
              })

              if (this.themeColorExpanded) {

              // 预设色块
              Row() {
                ForEach(THEME_COLORS, (item: ThemeColorItem, index: number) => {
                  Column() {
                    Column()
                      .width(36)
                      .height(36)
                      .borderRadius(18)
                      .backgroundColor(item.value)
                      .border({
                        width: this.themeColor === item.value ? 3 : 0,
                        color: this.themeColor === item.value ? item.value : '#00000000'
                      })
                  }
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor(this.themeColor === item.value ? item.value + '30' : '#00000000')
                  .onClick(() => {
                    this.themeColor = item.value
                    this.showCustomColor = false
                    storageService.saveThemeColor(item.value)
                  })
                })

                // 自定义颜色按钮
                Column() {
                  LucideIcon({
                    icon: LucideIcons.PLUS,
                    color: this.showCustomColor ? this.themeColor : (this.currentColorMode === 1 ? '#6B6B6B' : '#AAAAAA'),
                    iconSize: 20
                  })
                }
                .width(36)
                .height(36)
                .borderRadius(18)
                .border({ width: 1, color: this.currentColorMode === 1 ? '#CCCCCC' : '#999999' })
                .justifyContent(FlexAlign.Center)
                .onClick(() => {
                  this.showCustomColor = !this.showCustomColor
                })
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 8 })

              // 自定义 HEX 输入
              if (this.showCustomColor) {
                Row() {
                  TextInput({ text: this.customColorInput, placeholder: '#007DFF' })
                    .fontSize(14)
                    .layoutWeight(1)
                    .height(40)
                    .backgroundColor($r('app.color.bg_input'))
                    .borderRadius(8)
                    .padding({ left: 12, right: 12 })
                    .onChange((value: string) => {
                      this.customColorInput = value
                    })
                  Button('应用')
                    .fontSize(13)
                    .height(40)
                    .padding({ left: 16, right: 16 })
                    .backgroundColor(this.themeColor)
                    .fontColor(Color.White)
                    .borderRadius(8)
                    .margin({ left: 8 })
                    .onClick(() => {
                      const hex = this.customColorInput.trim()
                      if (hex.length > 0 && hex.startsWith('#')) {
                        this.themeColor = hex
                        storageService.saveThemeColor(hex)
                      }
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 16, bottom: 12 })
              }
              }
            }
          }
        }
        .divider({ strokeWidth: 0.5, startMargin: 16, endMargin: 16, color: this.currentColorMode === 1 ? '#E0E0E0' : '#444444' })

        // 组间间距
        ListItem() {
          Row().height(8).width('100%')
            .backgroundColor(Color.Transparent)
        }

        // ── 云备份 ──
        ListItemGroup({ header: this.SectionHeaderGroup('云备份') }) {
          // 云备份开关
          ListItem() {
            Row() {
              LucideIcon({ icon: LucideIcons.CLOUD, iconSize: 20,
                color: this.backupEnabled ? this.themeColor :
                  (this.currentColorMode === 1 ? '#6B6B6B' : '#AAAAAA') })
                .margin({ right: 12 })
              Column() {
                Text('云空间备份')
                  .fontSize(15)
                  .fontColor(this.currentColorMode === 1 ? '#333333' : '#EEEEEE')
                Text('备份数据到您的华为云空间，仅您可见')
                  .fontSize(12)
                  .fontColor(this.currentColorMode === 1 ? '#6B6B6B' : '#AAAAAA')
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.backupEnabled })
                .onClick(() => { this.toggleBackup() })
                .bindSheet($$this.showBackupTip, this.BackupTipSheet, {
                  height: SheetSize.MEDIUM,
                  showClose: false,
                  backgroundColor: this.currentColorMode === 1 ? Color.White : '#2A2A2A'
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          }

          // 备份数据选择
          ListItem() {
            Row() {
              LucideIcon({ icon: LucideIcons.BACKUP, iconSize: 20,
                color: this.backupEnabled ? this.themeColor :
                  (this.currentColorMode === 1 ? '#6B6B6B' : '#AAAAAA') })
                .margin({ right: 12 })
              Text('备份内容选择')
                .fontSize(15)
                .fontColor(this.currentColorMode === 1 ? '#333333' : '#EEEEEE')
                .layoutWeight(1)
              LucideIcon({ icon: LucideIcons.CHEVRON_RIGHT, iconSize: 18, color: this.currentColorMode === 1 ? '#6B6B6B' : '#AAAAAA' })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .onClick(async () => {
              this.backupSelection = await cloudBackupService.getBackupSelection()
              this.showBackupSelect = true
            })
            .bindSheet($$this.showBackupSelect, this.BackupSelectSheet, {
              height: SheetSize.MEDIUM,
              showClose: true,
              backgroundColor: this.currentColorMode === 1 ? Color.White : '#2A2A2A'
            })
          }

          // 立即备份按钮
          ListItem() {
            Row() {
              LucideIcon({ icon: LucideIcons.ARROW_UP, iconSize: 20,
                color: this.backupEnabled ? this.themeColor :
                  (this.currentColorMode === 1 ? '#6B6B6B' : '#AAAAAA') })
                .margin({ right: 12 })
              Text('立即同步')
                .fontSize(15)
                .fontColor(this.currentColorMode === 1 ? '#333333' : '#EEEEEE')
                .layoutWeight(1)
              Button('同步')
                .fontSize(13)
                .type(ButtonType.Capsule)
                .backgroundColor(this.backupEnabled ? this.themeColor : (this.currentColorMode === 1 ? '#6B6B6B' : '#AAAAAA'))
                .borderRadius(16)
                .height(32)
                .padding({ left: 16, right: 16 })
                .enabled(this.backupEnabled)
                .onClick(() => { this.handleManualBackup() })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 12 })
          }
        }
        .divider({ strokeWidth: 0.5, startMargin: 16, endMargin: 16, color: this.currentColorMode === 1 ? '#E0E0E0' : '#444444' })

        // 组间间距
        ListItem() {
          Row().height(8).width('100%')
            .backgroundColor(Color.Transparent)
        }

        // ── 永久记忆 ──
        ListItemGroup({ header: this.SectionHeaderGroup('永久记忆') }) {
          ListItem() {
            Row() {
              Text('记忆管理').fontSize(15).layoutWeight(1)
              Text(this.memories.length.toString() + ' 条')
                .fontSize(13).fontColor($r('app.color.text_secondary')).margin({ right: 8 })
              LucideIcon({ icon: LucideIcons.CHEVRON_RIGHT,
              color: this.currentColorMode === 1 ? '#CCCCCC' : '#999999', iconSize: 24 })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .onClick(() => { router.pushUrl({ url: 'pages/MemoryPage' }) })
          }
        }
        .divider({ strokeWidth: 0.5, startMargin: 16, endMargin: 16, color: this.currentColorMode === 1 ? '#E0E0E0' : '#444444' })

        // 组间间距
        ListItem() {
          Row().height(8).width('100%')
            .backgroundColor(Color.Transparent)
        }

        // ── 数据管理 ──
        ListItemGroup({ header: this.SectionHeaderGroup('数据管理') }) {
          ListItem() {
            this.SettingItem('回收站', '查看和恢复已删除的对话',
              () => {
                router.pushUrl({ url: ROUTES.RECYCLE_BIN })
              })
          }
          ListItem() {
            this.SettingItem('导出对话 (txt)', '选择特定对话导出为 txt 文件',
              () => { this.showExportPicker() })
          }
          ListItem() {
            this.SettingItem('导入对话 (txt)', '从 txt 文件导入对话',
              () => { this.importConversations() })
          }
        }
        .divider({ strokeWidth: 0.5, startMargin: 16, endMargin: 16, color: this.currentColorMode === 1 ? '#E0E0E0' : '#444444' })

        // 组间间距
        ListItem() {
          Row().height(8).width('100%')
            .backgroundColor(Color.Transparent)
        }

        // ── 关于 ──
        ListItemGroup({ header: this.SectionHeaderGroup('关于') }) {
          ListItem() {
            Row() {
              Text('版本').fontSize(15).layoutWeight(1)
              Text(APP_INFO.VERSION).fontSize(13).fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          }
          ListItem() {
            Text(APP_INFO.DESCRIPTION)
              .fontSize(13).fontColor($r('app.color.text_secondary'))
              .width('100%').textAlign(TextAlign.Center)
              .padding({ top: 12, bottom: 24 })
          }
        }

        ListItem() {
          Row()
            .height(88)
            .width('100%')
            .backgroundColor(Color.Transparent)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(Color.Transparent)
    }

    // ── 导出选择弹窗 ──
    if (this.showExportDialog) {
      Column() {
        Column().width('100%').height('100%').backgroundColor('#00000040')
          .onClick(() => { this.closeExportDialog() })
      }
      .width('100%').height('100%')
      .transition(TransitionEffect.opacity(0).animation({ duration: 200 }))

      this.ExportDialog()
    }
  }
    .height('100%')
    .backgroundColor(Color.Transparent)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder SectionHeaderGroup(title: string) {
    Text(title)
      .fontSize(12)
      .fontColor($r('app.color.text_secondary'))
      .fontWeight(FontWeight.Medium)
      .width('100%')
      .padding({ left: 16, top: 16, bottom: 8, right: 16 })
  }

  @Builder ExportDialog() {
    Column() {
      // 标题栏
      Row() {
        Text('选择要导出的对话')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
        Blank()
        Row() {
          Text(this.exportChecked.every((v: boolean) => v) ? '取消全选' : '全选')
            .fontSize(13)
            .fontColor(this.themeColor)
        }
        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
        .onClick(() => { this.toggleSelectAll() })
      }
      .width('100%')
      .padding({ left: 20, right: 16, top: 20, bottom: 12 })

      // 列表区域
      List() {
        ForEach(this.exportCandidates, (conv: Conversation, index: number) => {
          ListItem() {
            Row() {
              Checkbox()
                .select(this.exportChecked[index])
                .onChange((checked: boolean) => {
                  this.exportChecked[index] = checked
                })
              Column() {
                Text(conv.title)
                  .fontSize(15)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.formatExportDate(conv.createdAt))
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 2 })
              }
              .layoutWeight(1)
              .margin({ left: 12 })
            }
            .width('100%')
            .padding({ left: 20, right: 16, top: 10, bottom: 10 })
          }
        }, (conv: Conversation) => conv.id)
      }
      .height(320)
      .divider({ strokeWidth: 0.5, color: this.currentColorMode === 1 ? '#E5E5E5' : '#444444' })

      Divider().strokeWidth(0.5).color(this.currentColorMode === 1 ? '#E5E5E5' : '#444444')

      // 底部按钮
      Row() {
        Button('取消')
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.bg_page'))
          .layoutWeight(1)
          .height(42)
          .onClick(() => { this.closeExportDialog() })
        Column().width(12)
        Button('导出')
          .fontSize(15)
          .fontColor('#FFFFFF')
          .backgroundColor(this.themeColor)
          .layoutWeight(1)
          .height(42)
          .enabled(this.exportChecked.some((v: boolean) => v))
          .onClick(() => {
            this.closeExportDialog()
            this.exportSelectedConversations()
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 16 })
    }
    .width('90%')
    .borderRadius(16)
    .backgroundColor('rgba(250,250,250,0.85)')
    .backgroundBlurStyle(BlurStyle.Regular)
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.scale({ x: 0.9, y: 0.9 })
        .combine(TransitionEffect.opacity(0))
        .animation({ duration: 250, curve: Curve.EaseOut }),
      TransitionEffect.scale({ x: 0.95, y: 0.95 })
        .combine(TransitionEffect.opacity(0))
        .animation({ duration: 150, curve: Curve.EaseIn })
    ))
  }

  @Builder SettingItem(title: string, description: string, onClick: () => void) {
    Row() {
      Column() {
        Text(title).fontSize(15)
        Text(description).fontSize(12).fontColor($r('app.color.text_secondary')).margin({ top: 2 })
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
      LucideIcon({ icon: LucideIcons.CHEVRON_RIGHT, color: this.currentColorMode === 1 ? '#CCCCCC' : '#999999', iconSize: 24 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick(onClick)
  }

  /** 账号半模态提示 — 未登录华为账号时弹出 */
  @Builder AccountTipSheet() {
    Column() {
      Text('登录华为账号')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ top: 20, bottom: 4 })

      Text('登录华为账号后，您可以：')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ bottom: 10 })

      Row() {
        SymbolGlyph($r('sys.symbol.checkmark_shield'))
          .fontSize(16)
          .margin({ right: 8 })
          .fontColor([this.themeColor])
        Text('多设备间同步对话列表').fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }.width('100%').margin({ top: 4 })

      Row() {
        SymbolGlyph($r('sys.symbol.icloud'))
          .fontSize(16)
          .margin({ right: 8 })
          .fontColor([this.themeColor])
        Text('数据通过华为云空间安全备份').fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }.width('100%').margin({ top: 10 })

      Row() {
        SymbolGlyph($r('sys.symbol.person_shield'))
          .fontSize(16)
          .margin({ right: 8 })
          .fontColor([this.themeColor])
        Text('您的数据仅存储在您的华为账号下').fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }.width('100%').margin({ top: 10 })

      Blank().height(12)

      Button('登录华为账号')
        .width('100%')
        .height(40)
        .fontSize(15)
        .backgroundColor(this.themeColor)
        .fontColor(Color.White)
        .onClick(() => {
          this.showAccountTip = false
          setTimeout(() => { router.pushUrl({ url: 'pages/LoginPage' }) }, 350)
        })

      Button('暂不登录')
        .width('100%')
        .height(40)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.bg_button_secondary'))
        .margin({ top: 10, bottom: 24 })
        .onClick(() => { this.showAccountTip = false })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  /** 云备份隐私提示 — 首次开启备份时弹出 */
  @Builder BackupTipSheet() {
    Column() {
      Text('开启云空间备份')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ top: 20, bottom: 4 })

      Text('我们绝不会上传您的数据到我们的服务器。您的对话记录、设置和记忆将通过华为云空间直接备份到您自己的华为账号下，只有您能访问。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ bottom: 12 })

      Row() {
        SymbolGlyph($r('sys.symbol.key_horizontal'))
          .fontSize(16)
          .margin({ right: 8 })
          .fontColor([this.themeColor])
        Text('端到端加密传输').fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }.width('100%').margin({ top: 4 })

      Row() {
        SymbolGlyph($r('sys.symbol.icloud'))
          .fontSize(16)
          .margin({ right: 8 })
          .fontColor([this.themeColor])
        Text('备份到您的华为云空间').fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }.width('100%').margin({ top: 10 })

      Row() {
        SymbolGlyph($r('sys.symbol.externaldrive'))
          .fontSize(16)
          .margin({ right: 8 })
          .fontColor([this.themeColor])
        Text('换机后自动恢复数据').fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }.width('100%').margin({ top: 10 })

      Blank().height(8)

      Button('确认开启')
        .width('100%')
        .height(40)
        .fontSize(15)
        .backgroundColor(this.themeColor)
        .fontColor(Color.White)
        .onClick(() => { this.confirmEnableBackup() })

      Button('暂不开启')
        .width('100%')
        .height(40)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.bg_button_secondary'))
        .margin({ top: 10, bottom: 24 })
        .onClick(() => {
          this.showBackupTip = false
          this.backupEnabled = false
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  /** 备份数据选择弹窗 */
  @Builder BackupSelectSheet() {
    Column() {
      Text('选择备份内容')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ top: 20, bottom: 16 })

      Row() {
        Text('对话列表')
          .fontSize(15)
          .fontColor(this.currentColorMode === 1 ? '#333333' : '#EEEEEE')
          .layoutWeight(1)
        Toggle({ type: ToggleType.Checkbox, isOn: this.backupSelection.conversations })
          .onChange((isOn: boolean) => { this.backupSelection.conversations = isOn })
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })

      Row() {
        Text('永久记忆')
          .fontSize(15)
          .fontColor(this.currentColorMode === 1 ? '#333333' : '#EEEEEE')
          .layoutWeight(1)
        Toggle({ type: ToggleType.Checkbox, isOn: this.backupSelection.memories })
          .onChange((isOn: boolean) => { this.backupSelection.memories = isOn })
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })

      Row() {
        Text('应用设置（主题色等）')
          .fontSize(15)
          .fontColor(this.currentColorMode === 1 ? '#333333' : '#EEEEEE')
          .layoutWeight(1)
        Toggle({ type: ToggleType.Checkbox, isOn: this.backupSelection.settings })
          .onChange((isOn: boolean) => { this.backupSelection.settings = isOn })
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })

      Row() {
        Text('API 配置')
          .fontSize(15)
          .fontColor(this.currentColorMode === 1 ? '#333333' : '#EEEEEE')
          .layoutWeight(1)
        Toggle({ type: ToggleType.Checkbox, isOn: this.backupSelection.apiConfigs })
          .onChange((isOn: boolean) => { this.backupSelection.apiConfigs = isOn })
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })

      Blank().height(8)

      Button('保存')
        .width('100%')
        .height(40)
        .fontSize(15)
        .backgroundColor(this.themeColor)
        .fontColor(Color.White)
        .margin({ bottom: 24 })
        .onClick(() => { this.saveBackupSelection() })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .alignItems(HorizontalAlign.Start)
  }
}
