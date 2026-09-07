/**
 * ChatPage — 对话页面
 *
 * 核心聊天界面，支持：
 * - 流式输出 (SSE)
 * - Markdown 渲染
 * - 模型切换
 * - 上下文对话
 */

import { router } from '@kit.ArkUI'
import { Message, createMessage, generateId } from '../models/Message'
import { Conversation, createConversation, generateConversationTitle } from '../models/Conversation'
import { ApiConfig, getEffectiveModel, PRESET_PROVIDERS } from '../models/ApiConfig'
import { Memory } from '../models/Memory'
import { storageService } from '../services/StorageService'
import { apiService, ChatResult, StreamCallbacks, UsageStats } from '../services/ApiService'
import { ChatBubble } from '../components/ChatBubble'
import { MessageInput } from '../components/MessageInput'
import { LucideIcon, LucideIcons } from '../components/LucideIcon'
import { RenameDialog } from '../components/RenameDialog'
import { ROUTES, API } from '../common/Constants'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0004
const TAG = 'ChatPage'

/** ChatPage 路由参数 */
interface ChatRouteParams {
  conversationId: string
}

@Preview({ title: '聊天页 - 浅色', width: 390, height: 844 })
@Preview({ title: '聊天页 - 深色', width: 390, height: 844, colorMode: 'dark' })
@Entry
@Component
struct ChatPage {
  @State conversation: Conversation = createConversation('')
  @State @Watch('scrollToBottom') messages: Message[] = []
  @State isLoading: boolean = false
  @State streamingContent: string = ''
  @State streamingThinking: string = ''
  @State apiConfig: ApiConfig | null = null
  @State memories: Memory[] = []
  @State deepThinking: boolean = false
  @State @Watch('onOptionsClosed') showOptions: boolean = false
  @State showPromptEditor: boolean = false
  @State stats: UsageStats = { requestCount: 0, failedCount: 0, lastPromptTokens: 0, lastCompletionTokens: 0, totalTokens: 0 }
  @State localTemperature: number = 0.8
  @State localMaxTokens: number = 393216
  @State localTopP: number = 1.0
  @State localSystemPrompt: string = ''
  @State renameText: string = ''
  private renameDialogController: CustomDialogController | null = null
  @StorageLink('currentColorMode') currentColorMode: number = 0
  @StorageLink('themeColor') themeColor: string = '#007DFF'
  private scroller: Scroller = new Scroller()
  private conversationId: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as ChatRouteParams
    if (params && params.conversationId) {
      this.conversationId = params.conversationId
    }
    this.initPage()
  }

  onPageShow(): void {
    // 返回时保持滚动位置，不重新加载
  }

  aboutToDisappear(): void {
    this.renameDialogController = null
  }

  async initPage(): Promise<void> {
    try {
      await storageService.init(getContext(this))

      // 加载 API 配置
      this.apiConfig = await storageService.loadApiConfig()
      if (this.apiConfig) {
        this.localTemperature = this.apiConfig.temperature
        this.localMaxTokens = this.apiConfig.maxTokens
        this.localTopP = this.apiConfig.topP
      }

      // 加载记忆
      this.memories = await storageService.loadMemories()

      // 加载对话
      if (this.conversationId) {
        const conversations = await storageService.loadConversations()
        const found = conversations.find(c => c.id === this.conversationId)
        if (found) {
          this.conversation = found
          this.messages = [...found.messages]
          // 进入对话时默认隐藏所有深度思考内容
          for (let i = 0; i < this.messages.length; i++) {
            if (this.messages[i].thinkingContent.length > 0) {
              this.messages[i].showThinking = false
            }
          }
          // 使用对话中存储的模型参数，修复旧版 4096 过时默认值
          this.localTemperature = found.temperature
          this.localMaxTokens = found.maxTokens >= 393216 ? found.maxTokens : 393216
          this.localTopP = found.topP
          this.deepThinking = found.deepThinking
          this.localSystemPrompt = found.systemPrompt || ''
          hilog.info(DOMAIN, TAG, 'Loaded conversation: %{public}s', found.title)
          return
        }
      }

      // 创建新对话
      const model = this.apiConfig ? getEffectiveModel(this.apiConfig) : 'deepseek-v4-flash'
      this.conversation = createConversation(model)
      this.messages = []
      hilog.info(DOMAIN, TAG, 'Created new conversation')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Init page failed: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 消息列表变化时自动滚动到底部
   */
  scrollToBottom(): void {
    this.scroller.scrollEdge(Edge.Bottom)
  }

  build() {
    Column() {
      // 顶部导航栏
      this.TopBar()

      // 消息列表
      List({ initialIndex: this.messages.length > 0 ? this.messages.length - 1 : 0, scroller: this.scroller }) {
        // 空状态
        if (this.messages.length === 0 && !this.isLoading) {
          ListItem() {
            this.EmptyState()
          }
        }

        // 消息列表
        ForEach(this.messages, (msg: Message, index: number) => {
          ListItem() {
            ChatBubble({ message: msg })
          }
        }, (msg: Message) => msg.id)

        // 流式输出中的临时消息
        if (this.isLoading && (this.streamingContent || this.streamingThinking)) {
          ListItem() {
            ChatBubble({
              message: {
                id: 'streaming',
                role: 'assistant',
                content: this.streamingContent,
                thinkingContent: this.streamingThinking,
                showThinking: true,
                timestamp: Date.now(),
                isStreaming: true,
                model: this.apiConfig ? getEffectiveModel(this.apiConfig) : ''
              }
            })
          }
        } else if (this.isLoading && !this.streamingContent && !this.streamingThinking) {
          ListItem() {
            Row() {
              Column() {
                Text('AI')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
              }
              .width(32)
              .height(32)
              .borderRadius(16)
              .backgroundColor($r('app.color.bg_avatar'))
              .justifyContent(FlexAlign.Center)

              LoadingProgress()
                .width(16)
                .height(16)
                .color($r('app.color.bg_avatar'))
                .margin({ left: 8 })
              Blank()
            }
            .width('100%')
            .padding({ left: 16, top: 8, bottom: 8 })
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor(Color.Transparent)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      // 底部输入区域（毛玻璃质感）
      this.InputArea()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentColorMode === 1 ? '#FFFFFF' : '#1A1A1A')
  }

  @Builder
  InputArea() {
    Column() {
      // 顶部分隔线
      Row().width('92%').height(0.5)
        .backgroundColor(this.currentColorMode === 1 ? '#1A182431' : '#1AFFFFFF')
        .margin({ top: 0 })

      // 深度思考开关
      if (this.apiConfig) {
        Row() {
          Text('深度思考')
            .fontSize(13)
            .fontColor(this.deepThinking ? this.themeColor :
              (this.currentColorMode === 1 ? '#6B6B6B' : '#AAAAAA'))
          Toggle({ type: ToggleType.Switch, isOn: this.deepThinking })
            .selectedColor(this.themeColor).margin({ left: 8 })
            .onChange((isOn: boolean) => { this.deepThinking = isOn })
        }
        .width('100%').height(32)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)
      }

      // 输入框 + 发送按钮
      MessageInput({
        disabled: this.isLoading,
        onSend: (text: string) => { this.handleSend(text) }
      })
    }
    .width('100%')
    // 毛玻璃背景
    .backgroundColor(this.currentColorMode === 1 ? '#F0FFFFFF' : '#F0182431')
    .backgroundBlurStyle(BlurStyle.Regular)
    // 顶部圆角
    .borderRadius({ topLeft: 20, topRight: 20 })
    .padding({ bottom: 16 })
  }

  @Builder
  TopBar() {
    Row() {
      // 返回按钮 — 沉浸光感材质，带阴影
      Button() {
        LucideIcon({
          icon: LucideIcons.ARROW_LEFT,
          color: this.currentColorMode === 1 ? '#333333' : '#CCCCCC',
          iconSize: 22
        })
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(this.currentColorMode === 1 ?
        'rgba(250, 250, 250, 0.55)' : 'rgba(34, 34, 34, 0.55)')
      .backgroundBlurStyle(BlurStyle.Regular)
      .shadow({ radius: 8, color: '#18000000', offsetY: 2 })
      .onClick(() => {
        this.saveAndGoBack()
      })

      // 标题
      Text(this.conversation.title)
        .fontSize(19)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 8 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .onClick(() => {
          this.renameText = this.conversation.title
          if (this.renameDialogController === null) {
            this.renameDialogController = new CustomDialogController({
              builder: RenameDialog({
                titleText: $renameText,
                confirm: () => { this.confirmRename() }
              }),
              autoCancel: true,
              alignment: DialogAlignment.Center,
              customStyle: false
            })
          }
          this.renameDialogController?.open()
        })

      Blank()

      // 模型选择器（仅预设平台显示；custom 固定使用 customModel，隐藏切换）
      if (this.apiConfig && this.apiConfig.providerId !== 'custom') {
        Select(this.buildModelOptions())
          .selected(this.apiConfig.selectedModel === 'deepseek-v4-flash' ? 0 : 1)
          .value(this.modelShortName(this.apiConfig.selectedModel))
          .font({ size: 13 })
          .fontColor(this.themeColor)
          .width(86)
          .margin({ right: 8 })
          .onSelect((index: number) => {
            const config = this.apiConfig
            if (config) {
              const models = PRESET_PROVIDERS.find(p => p.id === config.providerId)?.defaultModels ?? []
              if (index < models.length) {
              config.selectedModel = models[index]
              this.apiConfig = config
                storageService.saveApiConfig(config)
              }
            }
          })
      }

      // 选项按钮 — 沉浸光感材质，带阴影
      Button() {
        LucideIcon({
          icon: LucideIcons.DOT_GRID_2X2,
          color: this.currentColorMode === 1 ? '#333333' : '#CCCCCC',
          iconSize: 22
        })
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(this.currentColorMode === 1 ?
        'rgba(250, 250, 250, 0.55)' : 'rgba(34, 34, 34, 0.55)')
      .backgroundBlurStyle(BlurStyle.Regular)
      .shadow({ radius: 8, color: '#18000000', offsetY: 2 })
      .onClick(() => {
        this.stats = apiService.getStats()
        this.showOptions = true
      })
      .bindSheet($$this.showOptions, this.OptionsSheetBuilder, {
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        showClose: true,
        title: this.SheetTitleBuilder,
        dragBar: true,
        scrollSizeMode: ScrollSizeMode.CONTINUOUS,
        backgroundColor: this.currentColorMode === 1 ? '#FFFFFF' : '#1A1A1A',
        onDisappear: () => { this.showOptions = false; this.saveParams() }
      })
    }
    .width('100%')
    .height(96)
    .padding({ left: 8, right: 8, top: 40 })
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: this.currentColorMode === 1 ?
        [['rgba(250, 250, 250, 1.0)', 0.0], ['rgba(250, 250, 250, 0.3)', 1.0]] :
        [['rgba(34, 34, 34, 1.0)', 0.0], ['rgba(34, 34, 34, 0.3)', 1.0]]
    })
    .backgroundBlurStyle(BlurStyle.Regular)
    .borderWidth({ bottom: 0.5 })
    .borderColor(this.currentColorMode === 1 ? '#E0E0E0' : '#444444')
  }

  @Builder
  OptionsSheetBuilder() {
    List() {
      ListItem() {
    Column() {
      // 数据概览
      Column() {
        Text('数据概览')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .padding({ left: 16, bottom: 12 })

        // 命中率
        Row() {
          Text('命中率')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
          Blank()
          Text(this.stats.requestCount > 0 ?
            Math.round((this.stats.requestCount - this.stats.failedCount) * 100 / this.stats.requestCount).toString() + '%' :
            '--')
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .padding({ left: 16, right: 16 })

        // 请求次数
        Row() {
          Text('请求次数')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
          Blank()
          Text(this.stats.requestCount.toString() + ' 次')
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })

        Row() {
          Text('Token 消耗')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
          Blank()
          Text(this.formatTokens(this.stats.totalTokens))
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })

        // 上下文长度
        Row() {
          Text('上下文长度')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
          Blank()
          Text(this.formatTokens(this.stats.lastPromptTokens) + ' / ' +
            this.formatTokens(API.MAX_CONTEXT_TOKENS))
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 4 })

        Progress({
          value: this.stats.lastPromptTokens,
          total: API.MAX_CONTEXT_TOKENS,
          type: ProgressType.Linear
        })
          .width('100%')
          .padding({ left: 16, right: 16 })
          .color(this.themeColor)

        Row() {
          Text(this.formatTokens(this.stats.lastPromptTokens))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          Blank()
          Text(Math.round(this.stats.lastPromptTokens * 100 / API.MAX_CONTEXT_TOKENS).toString() + '%')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4 })
      }
      .width('100%')
      .padding({ top: 4, bottom: 8 })

      // 温度
      Row() {
        Text('温度 (Temperature)')
          .fontSize(14).fontColor($r('app.color.text_primary')).layoutWeight(1)
        Text(this.localTemperature.toFixed(1))
          .fontSize(14).fontColor($r('app.color.text_secondary'))
      }
      .width('100%').padding({ left: 16, right: 16 })
      Slider({ value: this.localTemperature, min: 0, max: 2, step: 0.1 })
        .width('100%').padding({ left: 16, right: 16 })
        .onChange((value: number) => { this.localTemperature = value })

      // 最大 Tokens
      Row() {
        Text('最大 Tokens')
          .fontSize(14).fontColor($r('app.color.text_primary')).layoutWeight(1)
        Text(this.localMaxTokens.toString())
          .fontSize(14).fontColor($r('app.color.text_secondary'))
      }
      .width('100%').padding({ left: 16, right: 16, top: 18 })
      Slider({ value: this.localMaxTokens, min: 256, max: 393216, step: 256 })
        .width('100%').padding({ left: 16, right: 16 })
        .onChange((value: number) => { this.localMaxTokens = value })

      // Top-P
      Row() {
        Text('Top-P')
          .fontSize(14).fontColor($r('app.color.text_primary')).layoutWeight(1)
        Text(this.localTopP.toFixed(1))
          .fontSize(14).fontColor($r('app.color.text_secondary'))
      }
      .width('100%').padding({ left: 16, right: 16, top: 18 })
      Slider({ value: this.localTopP, min: 0, max: 1, step: 0.05 })
        .width('100%').padding({ left: 16, right: 16 })
        .onChange((value: number) => { this.localTopP = value })

      // 编辑默认提示词
      Row() {
        Text(this.localSystemPrompt.length > 0 ?
          '提示词(' + this.localSystemPrompt.length.toString() + '字)' : '编辑默认提示词')
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Button('编辑')
          .fontSize(13)
          .type(ButtonType.Capsule)
          .backgroundColor(this.themeColor)
          .borderRadius(16)
          .height(32)
          .padding({ left: 16, right: 16 })
          .onClick(() => { this.showPromptEditor = true })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 4 })
      .bindSheet($$this.showPromptEditor, this.PromptEditorSheet, {
        height: SheetSize.MEDIUM,
        showClose: true,
        backgroundColor: this.currentColorMode === 1 ? '#FFFFFF' : '#1A1A1A'
      })

    }
    .width('100%')
      }
    }
    .width('100%')
    .nestedScroll({
      scrollForward: NestedScrollMode.SELF_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
  }

  @Builder
  SheetTitleBuilder() {
    Row() {
      Text('数据概览与参数')
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, top: 4 })
  }

  @Builder
  PromptEditorSheet() {
    Column() {
      Text('编辑默认提示词')
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .padding({ left: 16, top: 24, bottom: 16 })
        .width('100%')
        .textAlign(TextAlign.Start)

      TextArea({ text: this.localSystemPrompt, placeholder: '自定义系统提示词，留空则使用默认提示词' })
        .fontSize(14)
        .height(200)
        .backgroundColor(this.currentColorMode === 1 ? '#F5F5F5' : '#333333')
        .borderRadius(8)
        .padding(12)
        .width('100%')
        .margin({ left: 16, right: 16 })
        .onChange((value: string) => { this.localSystemPrompt = value })

      Button('确定')
        .fontSize(14)
        .width('90%')
        .height(40)
        .backgroundColor(this.themeColor)
        .fontColor(Color.White)
        .borderRadius(10)
        .margin({ top: 16 })
        .onClick(() => {
          this.showPromptEditor = false
        })
    }
    .width('100%')
    .padding({ bottom: 24 })
  }

  @Builder
  EmptyState() {
    Column() {
      // Logo/图标区域
      Column() {
        SymbolGlyph($r('sys.symbol.ellipsis_message'))
          .fontSize(48)
          .fontColor([this.currentColorMode === 1 ? '#333333' : '#E0E0E0'])
      }
      .width(80)
      .height(80)
      .borderRadius(40)
      .backgroundColor(this.currentColorMode === 1 ? '#F0F0F0' : '#333333')
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 16 })

      Text('WhaleChat')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .padding({ bottom: 8 })

      Text('使用 DeepSeek / OpenAI 驱动')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .padding({ bottom: 4 })

      Text('在下方输入消息开始对话')
        .fontSize(13)
        .fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .padding({ top: 80 })
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * 发送消息
   */
  private async handleSend(text: string): Promise<void> {
    if (!this.apiConfig || !text.trim()) return

    // 添加用户消息
    const userMsg = createMessage('user', text, getEffectiveModel(this.apiConfig))
    this.messages.push(userMsg)

    // 新对话自动生成标题
    if (this.messages.length === 1) {
      this.conversation.title = generateConversationTitle(text)
    }

    // 清空流式内容缓冲区
    this.streamingContent = ''
    this.streamingThinking = ''
    this.isLoading = true

    // 获取所有消息历史（包括刚添加的）
    const allMessages: Message[] = []
    for (let i = 0; i < this.messages.length; i++) {
      allMessages.push(this.messages[i])
    }

    // 流式发送请求
    apiService.chatStream(
      this.apiConfig,
      allMessages,
      this.memories,
      this.deepThinking,
      this.localSystemPrompt,
      {
        onThinkingChunk: (thinking: string) => {
          this.streamingThinking += thinking
          this.scroller.scrollEdge(Edge.Bottom)
        },
        onChunk: (content: string) => {
          this.streamingContent += content
          this.scroller.scrollEdge(Edge.Bottom)
        },
        onDone: (fullContent: string, thinkingContent: string) => {
          if (fullContent || thinkingContent) {
            const aiMsg = createMessage('assistant', fullContent + '\n\n---\n内容由AI生成，仅供参考', getEffectiveModel(this.apiConfig!))
            aiMsg.thinkingContent = thinkingContent
            // 发送完成保持折叠（与问题4流式自动折叠衔接，用户可手动展开）
            aiMsg.showThinking = false
            this.messages.push(aiMsg)
          }
          this.streamingContent = ''
          this.streamingThinking = ''
          this.isLoading = false
          this.saveConversation()
        },
        onError: (error: string) => {
          const errorMsg = createMessage('assistant', '请求出错: ' + error, '')
          this.messages.push(errorMsg)
          this.streamingContent = ''
          this.streamingThinking = ''
          this.isLoading = false
          this.saveConversation()
        }
      }
    )
  }

  /**
   * 格式化 token 数量为可读文本（超过 1000 时缩写为 x.xK）
   */
  private formatTokens(n: number): string {
    if (n >= 1000) {
      return (n / 1000).toFixed(1) + 'K'
    }
    return n.toString()
  }

  private modelShortName(name: string): string {
    if (name.includes('pro') || name.includes('Pro')) return 'Pro'
    if (name.includes('flash') || name.includes('Flash')) return 'Flash'
    const parts = name.split('-')
    return parts.length > 0 ? parts[parts.length - 1] : name
  }

  /**
   * 构建模型选项列表
   */
  private buildModelOptions(): SelectOption[] {
    const config: ApiConfig | null = this.apiConfig
    if (!config) {
      const empty: SelectOption = { value: '' }
      return [empty]
    }
    // custom 平台：固定使用 customModel（防御，正常路径 Select 已隐藏）
    if (config.providerId === 'custom') {
      const customOpt: SelectOption = { value: config.customModel || 'deepseek-v4-flash' }
      const customOpts: SelectOption[] = [customOpt]
      return customOpts
    }
    const provider = PRESET_PROVIDERS.find(p => p.id === config.providerId)
    const models: string[] = provider?.defaultModels ?? []
    const options: SelectOption[] = []
    for (let i = 0; i < models.length; i++) {
      const opt: SelectOption = { value: models[i] }
      options.push(opt)
    }
    return options
  }

  /**
   * 保存对话并返回
   */
  private async saveAndGoBack(): Promise<void> {
    await this.saveConversation()
    router.back()
  }

  private onOptionsClosed(): void {
    if (this.showOptions) return // only act when closing (false→true is opening)
    this.saveParams()
  }

  private async saveParams(): Promise<void> {
    try {
      this.conversation.temperature = this.localTemperature
      this.conversation.maxTokens = this.localMaxTokens
      this.conversation.topP = this.localTopP
      this.conversation.deepThinking = this.deepThinking
      this.conversation.systemPrompt = this.localSystemPrompt
      this.conversation.updatedAt = Date.now()

      const conversations = await storageService.loadConversations()
      const existingIdx = conversations.findIndex(c => c.id === this.conversation.id)
      if (existingIdx >= 0) {
        conversations[existingIdx] = this.conversation
        await storageService.saveConversations(conversations)
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Save params failed')
    }
  }

  /**
   * 保存当前对话到存储
   */
  private async saveConversation(): Promise<void> {
    try {
      this.conversation.messages = this.messages
      this.conversation.updatedAt = Date.now()
      this.conversation.temperature = this.localTemperature
      this.conversation.maxTokens = this.localMaxTokens
      this.conversation.topP = this.localTopP
      this.conversation.deepThinking = this.deepThinking
      this.conversation.systemPrompt = this.localSystemPrompt

      const conversations = await storageService.loadConversations()
      const existingIdx = conversations.findIndex(c => c.id === this.conversation.id)

      if (existingIdx >= 0) {
        conversations[existingIdx] = this.conversation
      } else {
        // 新建对话始终保存，即使尚无消息（空对话）
        conversations.unshift(this.conversation)
      }

      await storageService.saveConversations(conversations)
      hilog.info(DOMAIN, TAG, 'Conversation saved')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Save conversation failed: %{public}s', JSON.stringify(err))
    }
  }

  private async confirmRename(): Promise<void> {
    const t = this.renameText.trim()
    if (t.length > 0) {
      this.conversation.title = t
      this.conversation.updatedAt = Date.now()
      this.saveConversation()
    }
  }

}
