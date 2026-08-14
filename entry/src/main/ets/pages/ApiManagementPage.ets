/**
 * ApiManagementPage — API 配置管理页
 *
 * 卡片式展示所有已配置的 API，横滑支持重命名/编辑/删除。
 * 添加新 API 通过单步弹窗：直接输入名称 + BaseURL + 密钥，BaseURL 缺协议自动补全并按地址识别平台。
 */
import { router } from '@kit.ArkUI'
import { ManagedApiConfig } from '../models/ApiConfig'
import { storageService } from '../services/StorageService'
import { LucideIcon, LucideIcons } from '../components/LucideIcon'
import { apiService } from '../services/ApiService'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0003
const TAG = 'ApiManagementPage'

@Entry
@Component
struct ApiManagementPage {
  @State configs: ManagedApiConfig[] = []
  @State balances: Record<string, string> = {}
  @StorageLink('currentColorMode') currentColorMode: number = 0
  // 弹窗控制器
  private inputDialogController: CustomDialogController | null = null

  aboutToAppear(): void {
    this.loadConfigs()
  }

  async loadConfigs(): Promise<void> {
    const data = await storageService.loadApiConfigs() as ManagedApiConfig[]
    this.configs = data
    // 为 DeepSeek 配置拉取余额
    this.fetchBalances()
  }

  async fetchBalances(): Promise<void> {
    const newBalances: Record<string, string> = {}
    for (let i = 0; i < this.configs.length; i++) {
      const cfg = this.configs[i]
      if (cfg.platform === 'deepseek' && cfg.apiKey.length > 0) {
        try {
          const result = await apiService.checkBalance(cfg)
          if (result.totalBalance !== '--') {
            const symbol: string = result.currency === 'USD' ? '$' : '¥'
            newBalances[cfg.id] = symbol + result.totalBalance
          }
        } catch (err) {
          hilog.error(DOMAIN, TAG, 'balance fetch failed for %{public}s', cfg.name)
        }
      }
    }
    this.balances = newBalances
  }

  async saveConfigs(): Promise<void> {
    await storageService.saveApiConfigs(this.configs)
  }

  // ——— 添加 API：直接弹出「名称 + BaseURL + 密钥」弹窗 ———
  showAddDialog(): void {
    this.inputDialogController = new CustomDialogController({
      builder: ApiInputDialog({
        defaultBaseUrl: 'https://api.deepseek.com',
        onSave: (name: string, baseUrl: string, apiKey: string) => {
          const normalizedUrl: string = this.normalizeBaseUrl(baseUrl)
          const platform: string = this.detectPlatform(normalizedUrl)
          const newConfig: ManagedApiConfig = {
            id: `${platform}_${Date.now()}`,
            name: name || (platform === 'deepseek' ? 'DeepSeek' : '自定义'),
            platform: platform,
            baseUrl: normalizedUrl,
            apiKey: apiKey,
            createdAt: Date.now()
          }
          this.configs = [...this.configs, newConfig]
          this.saveConfigs()
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.inputDialogController.open()
  }

  /**
   * 归一化 BaseURL：缺少协议前缀时补 https://
   */
  private normalizeBaseUrl(url: string): string {
    let result: string = url.trim()
    if (result.length === 0) return result
    if (!result.startsWith('http://') && !result.startsWith('https://')) {
      result = 'https://' + result
    }
    return result
  }

  /**
   * 根据 BaseURL 自动识别平台（deepseek / custom）
   */
  private detectPlatform(baseUrl: string): string {
    if (baseUrl.toLowerCase().includes('deepseek')) {
      return 'deepseek'
    }
    return 'custom'
  }

  // ——— 重命名弹窗 ———
  showRenameDialog(config: ManagedApiConfig): void {
    this.inputDialogController = new CustomDialogController({
      builder: RenameDialog({
        currentName: config.name,
        onConfirm: (newName: string) => {
          const idx = this.configs.findIndex(c => c.id === config.id)
          if (idx !== -1) {
            this.configs[idx].name = newName
            this.configs = [...this.configs]
            this.saveConfigs()
          }
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.inputDialogController.open()
  }

  // ——— 编辑弹窗 ———
  showEditDialog(config: ManagedApiConfig): void {
    this.inputDialogController = new CustomDialogController({
      builder: EditApiDialog({
        configName: config.name,
        currentBaseUrl: config.baseUrl,
        currentApiKey: config.apiKey,
        onSave: (baseUrl: string, apiKey: string) => {
          const idx = this.configs.findIndex(c => c.id === config.id)
          if (idx !== -1) {
            this.configs[idx].baseUrl = baseUrl
            this.configs[idx].apiKey = apiKey
            this.configs = [...this.configs]
            this.saveConfigs()
          }
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.inputDialogController.open()
  }

  // ——— 删除 ———
  deleteConfig(config: ManagedApiConfig): void {
    this.configs = this.configs.filter(c => c.id !== config.id)
    this.saveConfigs()
  }

  // ——— 平台标签色 ———
  platformColor(platform: string): string {
    switch (platform) {
      case 'deepseek': return '#4A9CFF'
      case 'openai': return '#10A37F'
      default: return '#AAAAAA'
    }
  }

  platformLabel(platform: string): string {
    switch (platform) {
      case 'deepseek': return 'DeepSeek'
      case 'openai': return 'OpenAI'
      default: return '自定义'
    }
  }

  build() {
    Column() {
      // ——— 二级标题栏 ———
      Row() {
        Button() {
          LucideIcon({ icon: LucideIcons.ARROW_LEFT, color: this.currentColorMode === 1 ? '#333333' : '#E0E0E0', iconSize: 22 })
        }
        .width(36).height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => router.back())

        Text('API 管理')
          .fontSize(19)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 添加按钮
        Button() {
          LucideIcon({ icon: LucideIcons.PLUS, color: this.currentColorMode === 1 ? '#333333' : '#E0E0E0', iconSize: 22 })
        }
        .width(36).height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.showAddDialog())
      }
      .width('100%')
      .height(96)
      .backgroundColor(this.currentColorMode === 1 ? '#F2F2F2' : '#121212')
      .padding({ left: 12, right: 12, top: 40, bottom: 8 })
      .borderWidth({ bottom: 0.5 })
      .borderColor(this.currentColorMode === 1 ? '#E0E0E0' : '#444444')

      // ——— 配置列表 ———
      if (this.configs.length === 0) {
        Column() {
          SymbolGlyph($r('sys.symbol.rectangle_on_rectangle'))
            .fontSize(48)
            .fontColor([$r('app.color.text_secondary')])
          Text('暂无 API 配置')
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 12 })
          Text('点击右上角 + 添加')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 3 }) {
          ForEach(this.configs, (config: ManagedApiConfig) => {
            ListItem() {
              Row() {
                Column() {
                  Text(config.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Row({ space: 6 }) {
                    Text(this.platformLabel(config.platform))
                      .fontSize(11)
                      .fontColor(this.platformColor(config.platform))
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .borderRadius(4)
                      .border({ width: 1, color: this.platformColor(config.platform) })

                    Text(this.maskedKey(config.apiKey))
                      .fontSize(12)
                      .fontColor($r('app.color.text_secondary'))
                      .maxLines(1)
                  }
                  .margin({ top: 4 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                // 余额显示
                if (this.balances[config.id]) {
                  Text(this.balances[config.id])
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.currentColorMode === 1 ? '#34C759' : '#30D158')
                    .margin({ left: 8 })
                }
              }
              .width('100%')
              .height(64)
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .borderRadius(12)
              .backgroundColor(this.currentColorMode === 1 ? '#FFFFFF' : '#2A2A2A')
              .shadow({ radius: 4, color: '#10000000', offsetY: 1 })
            }
            .margin({ left: 16, right: 16 })
            .swipeAction({
              end: {
                builder: () => {
                  this.SwipeActions(config)
                },
                actionAreaDistance: 170
              }
            })
          })

          // 底部占位
          ListItem() {
            Row()
              .height(88)
              .width('100%')
              .backgroundColor(Color.Transparent)
          }
        }
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentColorMode === 1 ? '#F2F2F2' : '#121212')
  }

  // ——— 横滑操作按钮 ———
  @Builder
  SwipeActions(config: ManagedApiConfig) {
    Row() {
      // 重命名 — 绿底
      Button() {
        LucideIcon({ icon: LucideIcons.RENAME, color: '#FFFFFF', iconSize: 20 })
      }
      .width(40).height(40).borderRadius(20)
      .backgroundColor('#34C759')
      .onClick(() => this.showRenameDialog(config))

      Column().width(8)

      // 编辑 — 蓝底
      Button() {
        LucideIcon({ icon: LucideIcons.SQUARE_AND_PENCIL, color: '#FFFFFF', iconSize: 20 })
      }
      .width(40).height(40).borderRadius(20)
      .backgroundColor('#007AFF')
      .onClick(() => this.showEditDialog(config))

      Column().width(8)

      // 删除 — 红底
      Button() {
        LucideIcon({ icon: LucideIcons.TRASH, color: '#FFFFFF', iconSize: 20 })
      }
      .width(40).height(40).borderRadius(20)
      .backgroundColor('#FF3B30')
      .onClick(() => {
        this.getUIContext().showAlertDialog({
          title: '确认删除',
          message: `确定要删除配置「${config.name}」吗？删除后无法恢复。`,
          primaryButton: {
            value: '删除',
            fontColor: '#FF3B30',
            action: () => { this.deleteConfig(config) }
          },
          secondaryButton: {
            value: '取消',
            action: () => {}
          }
        })
      })
    }
    .padding({ left: 16, right: 16 })
    .height('100%')
    .alignItems(VerticalAlign.Center)
  }

  // ——— 辅助：密钥脱敏显示 ———
  maskedKey(key: string): string {
    if (!key) return '未设置密钥'
    if (key.length <= 8) return key.substring(0, 4) + '****'
    return key.substring(0, 4) + '****' + key.substring(key.length - 4)
  }
}

// ═══════════════════════════════════════════
//  弹窗组件
// ═══════════════════════════════════════════

// ——— 输入 BaseURL & 密钥弹窗 ———
@CustomDialog
struct ApiInputDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: ApiInputDialog() })
  @StorageLink('currentColorMode') currentColorMode: number = 0
  defaultBaseUrl: string = ''
  onSave?: (name: string, baseUrl: string, apiKey: string) => void = undefined
  @State configName: string = ''
  @State baseUrl: string = ''
  @State apiKey: string = ''

  aboutToAppear(): void {
    this.baseUrl = this.defaultBaseUrl
    this.configName = ''
  }

  build() {
    Column() {
      Text('添加 API 配置')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 20 })

      Text('名称')
        .fontSize(13)
        .fontColor($r('app.color.text_subtle'))
        .width('100%')
        .margin({ bottom: 6 })
      TextInput({ text: this.configName, placeholder: '输入配置名称' })
        .width('100%')
        .height(40)
        .fontSize(15)
        .borderRadius(8)
        .backgroundColor($r('app.color.bg_input'))
        .onChange((value: string) => { this.configName = value })

      Text('Base URL')
        .fontSize(13)
        .fontColor($r('app.color.text_subtle'))
        .width('100%')
        .margin({ top: 16, bottom: 6 })
      TextInput({ text: this.baseUrl, placeholder: 'https://api.example.com' })
        .width('100%')
        .height(40)
        .fontSize(15)
        .borderRadius(8)
        .backgroundColor($r('app.color.bg_input'))
        .onChange((value: string) => { this.baseUrl = value })

      Text('API 密钥')
        .fontSize(13)
        .fontColor($r('app.color.text_subtle'))
        .width('100%')
        .margin({ top: 16, bottom: 6 })
      TextInput({ text: this.apiKey, placeholder: 'sk-...' })
        .width('100%')
        .height(40)
        .fontSize(15)
        .borderRadius(8)
        .backgroundColor($r('app.color.bg_input'))
        .type(InputType.Password)
        .onChange((value: string) => { this.apiKey = value })

      Row({ space: 12 }) {
        Button('取消')
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor($r('app.color.bg_input'))
          .fontColor(this.currentColorMode === 1 ? '#333333' : '#E0E0E0')
          .onClick(() => this.controller.close())

        Button('保存')
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor('#007AFF')
          .fontColor('#FFFFFF')
          .onClick(() => {
            if (this.onSave) this.onSave(this.configName, this.baseUrl, this.apiKey)
            this.controller.close()
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width('90%')
    .padding(20)
    .borderRadius(16)
    .backgroundColor('rgba(250,250,250,0.85)')
    .backgroundBlurStyle(BlurStyle.Regular)
  }
}

// ——— 重命名弹窗 ———
@CustomDialog
struct RenameDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: RenameDialog() })
  @StorageLink('currentColorMode') currentColorMode: number = 0
  currentName: string = ''
  onConfirm?: (name: string) => void = undefined
  @State name: string = ''

  aboutToAppear(): void {
    this.name = this.currentName
  }

  build() {
    Column() {
      Text('重命名')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 20 })

      TextInput({ text: this.name, placeholder: '输入新名称' })
        .width('100%')
        .height(40)
        .fontSize(15)
        .borderRadius(8)
        .backgroundColor($r('app.color.bg_input'))
        .onChange((value: string) => { this.name = value })

      Row({ space: 12 }) {
        Button('取消')
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor($r('app.color.bg_input'))
          .fontColor(this.currentColorMode === 1 ? '#333333' : '#E0E0E0')
          .onClick(() => this.controller.close())

        Button('确定')
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor('#007AFF')
          .fontColor('#FFFFFF')
          .onClick(() => {
            if (this.onConfirm) this.onConfirm(this.name)
            this.controller.close()
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width('90%')
    .padding(20)
    .borderRadius(16)
    .backgroundColor('rgba(250,250,250,0.85)')
    .backgroundBlurStyle(BlurStyle.Regular)
  }
}

// ——— 编辑 BaseURL & 密钥弹窗 ———
@CustomDialog
struct EditApiDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: EditApiDialog() })
  @StorageLink('currentColorMode') currentColorMode: number = 0
  configName: string = ''
  currentBaseUrl: string = ''
  currentApiKey: string = ''
  onSave?: (baseUrl: string, apiKey: string) => void = undefined
  @State baseUrl: string = ''
  @State apiKey: string = ''

  aboutToAppear(): void {
    this.baseUrl = this.currentBaseUrl
    this.apiKey = this.currentApiKey
  }

  build() {
    Column() {
      Text(`编辑 ${this.configName}`)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 20 })

      Text('Base URL')
        .fontSize(13)
        .fontColor($r('app.color.text_subtle'))
        .width('100%')
        .margin({ bottom: 6 })
      TextInput({ text: this.baseUrl, placeholder: 'https://api.example.com' })
        .width('100%')
        .height(40)
        .fontSize(15)
        .borderRadius(8)
        .backgroundColor($r('app.color.bg_input'))
        .onChange((value: string) => { this.baseUrl = value })

      Text('API 密钥')
        .fontSize(13)
        .fontColor($r('app.color.text_subtle'))
        .width('100%')
        .margin({ top: 16, bottom: 6 })
      TextInput({ text: this.apiKey, placeholder: 'sk-...' })
        .width('100%')
        .height(40)
        .fontSize(15)
        .borderRadius(8)
        .backgroundColor($r('app.color.bg_input'))
        .type(InputType.Password)
        .onChange((value: string) => { this.apiKey = value })

      Row({ space: 12 }) {
        Button('取消')
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor($r('app.color.bg_input'))
          .fontColor(this.currentColorMode === 1 ? '#333333' : '#E0E0E0')
          .onClick(() => this.controller.close())

        Button('保存')
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor('#007AFF')
          .fontColor('#FFFFFF')
          .onClick(() => {
            if (this.onSave) this.onSave(this.baseUrl, this.apiKey)
            this.controller.close()
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width('90%')
    .padding(20)
    .borderRadius(16)
    .backgroundColor('rgba(250,250,250,0.85)')
    .backgroundBlurStyle(BlurStyle.Regular)
  }
}
