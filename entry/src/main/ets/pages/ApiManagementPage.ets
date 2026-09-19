/**
 * ApiManagementPage — API 配置管理页
 *
 * 卡片式展示所有已配置的 API，横滑支持重命名/编辑/删除，点击卡片设为当前使用。
 * 每个配置（服务商 + 密钥）下可维护多个模型条目（模型名 + 缩略显示名），
 * 模型条目存于 APIMODELS 表并与云端对象类型 APIMODELS 端云同步。
 */
import { router } from '@kit.ArkUI'
import { promptAction } from '@kit.ArkUI'
import { ManagedApiConfig, ApiModelEntry, buildModelEntry, normalizeBaseUrl, detectPlatform, resolveDisplayName } from '../models/ApiConfig'
import { storageService } from '../services/StorageService'
import { syncService } from '../services/SyncService'
import { LucideIcon, LucideIcons } from '../components/LucideIcon'
import { apiService } from '../services/ApiService'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0003
const TAG = 'ApiManagementPage'
// 列表边缘渐隐带占列表高度的比例，可按真机效果调整
const LIST_FADE_RATIO = 0.05

/** 模型编辑行（弹窗内临时状态；id 为空表示新增行） */
interface ModelRow {
  id: string
  modelId: string
  displayName: string
}

@Entry
@Component
struct ApiManagementPage {
  @State configs: ManagedApiConfig[] = []
  @State modelEntries: ApiModelEntry[] = []
  @State activeConfigId: string = ''
  @State balances: Record<string, string> = {}
  @State showTopFade: boolean = false
  @State showBottomFade: boolean = false
  @StorageLink('currentColorMode') currentColorMode: number = 0
  // 弹窗控制器
  private inputDialogController: CustomDialogController | null = null

  aboutToAppear(): void {
    this.loadConfigs()
  }

  async onPageShow(): Promise<void> {
    try {
      await syncService.syncApiConfigs('')
      await syncService.syncApiModels('')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'api configs/models sync failed: %{public}s', JSON.stringify(err))
    }
    await this.loadConfigs()
  }

  aboutToDisappear(): void {
    this.inputDialogController = null
  }

  async loadConfigs(): Promise<void> {
    await storageService.init(getContext(this))
    const data = await storageService.loadApiConfigs() as ManagedApiConfig[]
    this.configs = data
    this.modelEntries = await storageService.loadAllApiModels()
    const ctx = await storageService.loadActiveApiContext()
    this.activeConfigId = ctx.config ? ctx.config.id : ''
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

  /**
   * 保存配置 + 其模型条目（添加/编辑共用入口）
   */
  private async persistConfigWithModels(config: ManagedApiConfig, rows: ModelRow[]): Promise<void> {
    const idx = this.configs.findIndex(c => c.id === config.id)
    if (idx !== -1) {
      this.configs[idx] = config
    } else {
      this.configs.push(config)
    }
    this.configs = [...this.configs]
    await this.saveConfigs()

    const entries: ApiModelEntry[] = []
    for (let i = 0; i < rows.length; i++) {
      const modelId: string = rows[i].modelId.trim()
      if (modelId.length === 0) continue
      entries.push(buildModelEntry(rows[i].id, config.id, modelId, rows[i].displayName.trim(), i))
    }
    await storageService.saveApiModelsForConfig(config.id, entries)
    this.modelEntries = await storageService.loadAllApiModels()

    // 激活兜底：当前无激活配置时设为本配置
    const activeId = await storageService.getActiveConfigId()
    if (activeId.length === 0) {
      await storageService.setActiveConfigId(config.id)
      if (entries.length > 0) {
        await storageService.setActiveModelEntryId(entries[0].id)
      }
      this.activeConfigId = config.id
    }
  }

  // ——— 添加 API：弹出「名称 + BaseURL + 密钥 + 模型列表」弹窗 ———
  showAddDialog(): void {
    this.inputDialogController = new CustomDialogController({
      builder: ApiInputDialog({
        onSave: (name: string, baseUrl: string, apiKey: string, rows: ModelRow[]) => {
          const normalizedUrl: string = normalizeBaseUrl(baseUrl)
          const platform: string = detectPlatform(normalizedUrl)
          const newConfig: ManagedApiConfig = {
            id: `${platform}_${Date.now()}`,
            name: name || (platform === 'deepseek' ? 'DeepSeek' : platform === 'openai' ? 'OpenAI' : '自定义'),
            platform: platform,
            baseUrl: normalizedUrl,
            apiKey: apiKey,
            createdAt: Date.now()
          }
          this.persistConfigWithModels(newConfig, rows)
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.inputDialogController?.open()
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
    this.inputDialogController?.open()
  }

  // ——— 编辑弹窗（含模型列表） ———
  async showEditDialog(config: ManagedApiConfig): Promise<void> {
    const models = await storageService.loadApiModels(config.id)
    const rows: ModelRow[] = []
    for (let i = 0; i < models.length; i++) {
      const row: ModelRow = { id: models[i].id, modelId: models[i].modelId, displayName: models[i].displayName }
      rows.push(row)
    }
    this.inputDialogController = new CustomDialogController({
      builder: EditApiDialog({
        configName: config.name,
        currentBaseUrl: config.baseUrl,
        currentApiKey: config.apiKey,
        currentRows: rows,
        onSave: (baseUrl: string, apiKey: string, editRows: ModelRow[]) => {
          const idx = this.configs.findIndex(c => c.id === config.id)
          if (idx !== -1) {
            const updated: ManagedApiConfig = {
              id: config.id,
              name: this.configs[idx].name,
              platform: this.configs[idx].platform,
              baseUrl: normalizeBaseUrl(baseUrl),
              apiKey: apiKey,
              createdAt: this.configs[idx].createdAt
            }
            this.persistConfigWithModels(updated, editRows)
          }
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.inputDialogController?.open()
  }

  // ——— 删除 ———
  async deleteConfig(config: ManagedApiConfig): Promise<void> {
    this.configs = this.configs.filter(c => c.id !== config.id)
    await this.saveConfigs()
    this.modelEntries = this.modelEntries.filter(m => m.configId !== config.id)
    // 删除的是激活配置时清空激活键，后续进入对话页自动回退到最早配置
    if (this.activeConfigId === config.id) {
      await storageService.setActiveConfigId('')
      await storageService.setActiveModelEntryId('')
      const ctx = await storageService.loadActiveApiContext()
      this.activeConfigId = ctx.config ? ctx.config.id : ''
    }
  }

  // ——— 点击卡片：设为当前使用 ———
  async setActive(config: ManagedApiConfig): Promise<void> {
    if (this.activeConfigId === config.id) return
    const models = await storageService.loadApiModels(config.id)
    if (models.length === 0) {
      promptAction.showToast({ message: '该配置尚未添加模型，请先编辑添加', duration: 2000 })
      return
    }
    await storageService.setActiveConfigId(config.id)
    await storageService.setActiveModelEntryId(models[0].id)
    this.activeConfigId = config.id
    promptAction.showToast({ message: '已切换为当前使用的 API', duration: 1500 })
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

  /**
   * 配置的模型摘要（首个显示名 + 数量）
   */
  modelSummary(configId: string): string {
    const models = this.modelEntries.filter(m => m.configId === configId)
    if (models.length === 0) return '未配置模型'
    const first: string = resolveDisplayName(models[0])
    if (models.length === 1) return first
    return first + ' 等 ' + models.length.toString() + ' 个模型'
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
                  Row({ space: 6 }) {
                    Text(config.name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    if (this.activeConfigId === config.id) {
                      Text('使用中')
                        .fontSize(10)
                        .fontColor('#34C759')
                        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                        .borderRadius(4)
                        .border({ width: 1, color: '#34C759' })
                    }
                  }

                  Row({ space: 6 }) {
                    Text(this.platformLabel(config.platform))
                      .fontSize(11)
                      .fontColor(this.platformColor(config.platform))
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .borderRadius(4)
                      .border({ width: 1, color: this.platformColor(config.platform) })

                    Text(this.modelSummary(config.id))
                      .fontSize(12)
                      .fontColor(this.currentColorMode === 1 ? '#666666' : '#BBBBBB')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .margin({ top: 4 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Column() {
                  // 余额显示
                  if (this.balances[config.id]) {
                    Text(this.balances[config.id])
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.currentColorMode === 1 ? '#34C759' : '#30D158')
                  }
                }
                .margin({ left: 8 })
              }
              .width('100%')
              .height(64)
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .borderRadius(12)
              .backgroundColor(this.currentColorMode === 1 ? '#FFFFFF' : '#2A2A2A')
              .shadow({ radius: 4, color: '#10000000', offsetY: 1 })
              .onClick(() => { this.setActive(config) })
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
          }, (config: ManagedApiConfig) => config.id)

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
        .onScrollIndex((start: number, end: number) => {
          // 末位是 88vp 底部占位项：end 未到占位项索引，说明底边仍有卡片被裁剪
          this.showTopFade = start > 0
          this.showBottomFade = end < this.configs.length
        })
        // 官方配方：渐隐 overlay 必须直接挂在 List 上（挂包裹容器上混合不到列表内容）
        .overlay(this.EdgeFadeMask())
      }

      Text('点击卡片切换当前使用的 API；左滑编辑或删除')
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ top: 8, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentColorMode === 1 ? '#F2F2F2' : '#121212')
  }

  /**
   * 列表边缘渐隐遮罩（官方《常见列表操作》边缘模糊配方）：
   * overlay 直接挂在 List 上，全尺寸 Stack + linearGradient + BlendMode.DST_IN(OFFSCREEN)，
   * 遮罩透明处列表内容被抠除（渐隐）；色标由滚动位置动态驱动，无溢出的一侧为不透明停靠点
   */
  @Builder
  EdgeFadeMask() {
    Stack()
      .width('100%')
      .height('100%')
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: this.edgeFadeColors()
      })
      .blendMode(BlendMode.DST_IN, BlendApplyType.OFFSCREEN)
      .hitTestBehavior(HitTestMode.None)
  }

  /**
   * 遮罩色标：某侧有内容溢出视口时该侧边缘停靠点透明（出现渐隐带），否则不透明（恒等遮罩）
   */
  private edgeFadeColors(): Array<[ResourceColor, number]> {
    const topAlpha: number = this.showTopFade ? 0x00FFFFFF : 0xFFFFFFFF
    const bottomAlpha: number = this.showBottomFade ? 0x00FFFFFF : 0xFFFFFFFF
    return [
      [topAlpha, 0.0],
      [0xFFFFFFFF, LIST_FADE_RATIO],
      [0xFFFFFFFF, 1 - LIST_FADE_RATIO],
      [bottomAlpha, 1.0]
    ]
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
          message: `确定要删除配置「${config.name}」吗？其模型列表将一并删除，删除后无法恢复。`,
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

// ——— 添加 API 配置弹窗（名称 + BaseURL + 密钥 + 模型列表） ———
@CustomDialog
struct ApiInputDialog {
  controller?: CustomDialogController
  @StorageLink('currentColorMode') currentColorMode: number = 0
  onSave?: (name: string, baseUrl: string, apiKey: string, rows: ModelRow[]) => void = undefined
  @State configName: string = ''
  @State baseUrl: string = ''
  @State apiKey: string = ''
  @State modelRows: ModelRow[] = []

  aboutToAppear(): void {
    this.baseUrl = 'https://api.deepseek.com'
    this.configName = ''
    const first: ModelRow = { id: '', modelId: 'deepseek-v4-flash', displayName: '' }
    this.modelRows = [first]
  }

  addModelRow(): void {
    const row: ModelRow = { id: '', modelId: '', displayName: '' }
    this.modelRows = [...this.modelRows, row]
  }

  removeModelRow(index: number): void {
    if (this.modelRows.length <= 1) return
    this.modelRows = this.modelRows.filter((r: ModelRow, i: number) => i !== index)
  }

  /**
   * 校验并保存：名称可空（自动生成）、BaseURL/密钥/至少一个模型名必填
   */
  confirmSave(): void {
    if (this.baseUrl.trim().length === 0) {
      promptAction.showToast({ message: '请输入 Base URL', duration: 1500 })
      return
    }
    if (this.apiKey.trim().length === 0) {
      promptAction.showToast({ message: '请输入 API 密钥', duration: 1500 })
      return
    }
    let hasModel = false
    for (let i = 0; i < this.modelRows.length; i++) {
      if (this.modelRows[i].modelId.trim().length > 0) {
        hasModel = true
        break
      }
    }
    if (!hasModel) {
      promptAction.showToast({ message: '请至少填写一个模型名', duration: 1500 })
      return
    }
    if (this.onSave) this.onSave(this.configName.trim(), this.baseUrl.trim(), this.apiKey.trim(), this.modelRows)
    this.controller?.close()
  }

  build() {
    Column() {
      Text('添加 API 配置')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 16 })

      Scroll() {
        Column() {
          Text('名称')
            .fontSize(13)
            .fontColor($r('app.color.text_subtle'))
            .width('100%')
            .margin({ bottom: 6 })
          TextInput({ text: this.configName, placeholder: '输入配置名称（可留空自动识别）' })
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
            .margin({ top: 12, bottom: 6 })
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
            .margin({ top: 12, bottom: 6 })
          TextInput({ text: this.apiKey, placeholder: 'sk-...' })
            .width('100%')
            .height(40)
            .fontSize(15)
            .borderRadius(8)
            .backgroundColor($r('app.color.bg_input'))
            .type(InputType.Password)
            .onChange((value: string) => { this.apiKey = value })

          Text('模型列表（模型名必填，显示名可留空）')
            .fontSize(13)
            .fontColor($r('app.color.text_subtle'))
            .width('100%')
            .margin({ top: 12, bottom: 6 })

          ForEach(this.modelRows, (row: ModelRow, index: number) => {
            Row({ space: 6 }) {
              TextInput({ text: row.modelId, placeholder: '模型名，如 gpt-4o' })
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .borderRadius(8)
                .backgroundColor($r('app.color.bg_input'))
                .onChange((value: string) => { this.modelRows[index].modelId = value })

              TextInput({ text: row.displayName, placeholder: '显示名' })
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .borderRadius(8)
                .backgroundColor($r('app.color.bg_input'))
                .onChange((value: string) => { this.modelRows[index].displayName = value })

              Text('×')
                .fontSize(20)
                .fontColor($r('app.color.text_secondary'))
                .width(28)
                .textAlign(TextAlign.Center)
                .onClick(() => { this.removeModelRow(index) })
            }
            .width('100%')
            .margin({ bottom: 6 })
          }, (row: ModelRow, index: number) => row.id + '_' + index.toString())

          Text('+ 添加模型')
            .fontSize(13)
            .fontColor('#007AFF')
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 4, bottom: 4 })
            .onClick(() => { this.addModelRow() })
        }
        .width('100%')
      }
      .width('100%')
      .align(Alignment.Top)
      .constraintSize({ maxHeight: 360 })

      Row({ space: 12 }) {
        Button('取消')
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor($r('app.color.bg_input'))
          .fontColor(this.currentColorMode === 1 ? '#333333' : '#E0E0E0')
          .onClick(() => this.controller?.close())

        Button('保存')
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor('#007AFF')
          .fontColor('#FFFFFF')
          .onClick(() => { this.confirmSave() })
      }
      .width('100%')
      .margin({ top: 12 })
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
  controller?: CustomDialogController
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
          .onClick(() => this.controller?.close())

        Button('确定')
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor('#007AFF')
          .fontColor('#FFFFFF')
          .onClick(() => {
            if (this.onConfirm) this.onConfirm(this.name)
            this.controller?.close()
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

// ——— 编辑 BaseURL & 密钥 & 模型列表弹窗 ———
@CustomDialog
struct EditApiDialog {
  controller?: CustomDialogController
  @StorageLink('currentColorMode') currentColorMode: number = 0
  configName: string = ''
  currentBaseUrl: string = ''
  currentApiKey: string = ''
  currentRows: ModelRow[] = []
  onSave?: (baseUrl: string, apiKey: string, rows: ModelRow[]) => void = undefined
  @State baseUrl: string = ''
  @State apiKey: string = ''
  @State modelRows: ModelRow[] = []

  aboutToAppear(): void {
    this.baseUrl = this.currentBaseUrl
    this.apiKey = this.currentApiKey
    if (this.currentRows.length > 0) {
      this.modelRows = this.currentRows
    } else {
      const emptyRow: ModelRow = { id: '', modelId: '', displayName: '' }
      this.modelRows = [emptyRow]
    }
  }

  addModelRow(): void {
    const row: ModelRow = { id: '', modelId: '', displayName: '' }
    this.modelRows = [...this.modelRows, row]
  }

  removeModelRow(index: number): void {
    if (this.modelRows.length <= 1) return
    this.modelRows = this.modelRows.filter((r: ModelRow, i: number) => i !== index)
  }

  confirmSave(): void {
    if (this.baseUrl.trim().length === 0) {
      promptAction.showToast({ message: '请输入 Base URL', duration: 1500 })
      return
    }
    if (this.apiKey.trim().length === 0) {
      promptAction.showToast({ message: '请输入 API 密钥', duration: 1500 })
      return
    }
    let hasModel = false
    for (let i = 0; i < this.modelRows.length; i++) {
      if (this.modelRows[i].modelId.trim().length > 0) {
        hasModel = true
        break
      }
    }
    if (!hasModel) {
      promptAction.showToast({ message: '请至少填写一个模型名', duration: 1500 })
      return
    }
    if (this.onSave) this.onSave(this.baseUrl.trim(), this.apiKey.trim(), this.modelRows)
    this.controller?.close()
  }

  build() {
    Column() {
      Text(`编辑 ${this.configName}`)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 16 })

      Scroll() {
        Column() {
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
            .margin({ top: 12, bottom: 6 })
          TextInput({ text: this.apiKey, placeholder: 'sk-...' })
            .width('100%')
            .height(40)
            .fontSize(15)
            .borderRadius(8)
            .backgroundColor($r('app.color.bg_input'))
            .type(InputType.Password)
            .onChange((value: string) => { this.apiKey = value })

          Text('模型列表（模型名必填，显示名可留空）')
            .fontSize(13)
            .fontColor($r('app.color.text_subtle'))
            .width('100%')
            .margin({ top: 12, bottom: 6 })

          ForEach(this.modelRows, (row: ModelRow, index: number) => {
            Row({ space: 6 }) {
              TextInput({ text: row.modelId, placeholder: '模型名，如 gpt-4o' })
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .borderRadius(8)
                .backgroundColor($r('app.color.bg_input'))
                .onChange((value: string) => { this.modelRows[index].modelId = value })

              TextInput({ text: row.displayName, placeholder: '显示名' })
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .borderRadius(8)
                .backgroundColor($r('app.color.bg_input'))
                .onChange((value: string) => { this.modelRows[index].displayName = value })

              Text('×')
                .fontSize(20)
                .fontColor($r('app.color.text_secondary'))
                .width(28)
                .textAlign(TextAlign.Center)
                .onClick(() => { this.removeModelRow(index) })
            }
            .width('100%')
            .margin({ bottom: 6 })
          }, (row: ModelRow, index: number) => row.id + '_' + index.toString())

          Text('+ 添加模型')
            .fontSize(13)
            .fontColor('#007AFF')
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 4, bottom: 4 })
            .onClick(() => { this.addModelRow() })
        }
        .width('100%')
      }
      .width('100%')
      .align(Alignment.Top)
      .constraintSize({ maxHeight: 360 })

      Row({ space: 12 }) {
        Button('取消')
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor($r('app.color.bg_input'))
          .fontColor(this.currentColorMode === 1 ? '#333333' : '#E0E0E0')
          .onClick(() => this.controller?.close())

        Button('保存')
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor('#007AFF')
          .fontColor('#FFFFFF')
          .onClick(() => { this.confirmSave() })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('90%')
    .padding(20)
    .borderRadius(16)
    .backgroundColor('rgba(250,250,250,0.85)')
    .backgroundBlurStyle(BlurStyle.Regular)
  }
}
