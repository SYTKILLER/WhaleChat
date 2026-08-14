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
import { ApiConfig, getEffectiveModel } from '../models/ApiConfig'
import { Memory } from '../models/Memory'
import { storageService } from '../services/StorageService'
import { apiService } from '../services/ApiService'
import { ChatBubble } from '../components/ChatBubble'
import { MessageInput } from '../components/MessageInput'
import { ModelSelector } from '../components/ModelSelector'
import { ROUTES } from '../common/Constants'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0004
const TAG = 'ChatPage'

@Entry
@Component
struct ChatPage {
  @State conversation: Conversation = createConversation('')
  @State messages: Message[] = []
  @State isLoading: boolean = false
  @State streamingContent: string = ''
  @State apiConfig: ApiConfig | null = null
  @State memories: Memory[] = []
  @State showScrollToBottom: boolean = false
  @StorageLink('currentColorMode') currentColorMode: number = 0
  private scroller: Scroller = new Scroller()
  private conversationId: string = ''

  aboutToAppear(): void {
    // 获取传入的对话 ID
    const params = router.getParams() as Record<string, string>
    if (params && params['conversationId']) {
      this.conversationId = params['conversationId']
    }

    this.initPage()
  }

  async initPage(): Promise<void> {
    try {
      await storageService.init(getContext(this))

      // 加载 API 配置
      this.apiConfig = await storageService.loadApiConfig()

      // 加载记忆
      this.memories = await storageService.loadMemories()

      // 加载对话
      if (this.conversationId) {
        const conversations = await storageService.loadConversations()
        const found = conversations.find(c => c.id === this.conversationId)
        if (found) {
          this.conversation = found
          this.messages = [...found.messages]
          hilog.info(DOMAIN, TAG, 'Loaded conversation: %{public}s', found.title)
          return
        }
      }

      // 创建新对话
      const model = this.apiConfig ? getEffectiveModel(this.apiConfig) : 'deepseek-chat'
      this.conversation = createConversation(model)
      this.messages = []
      hilog.info(DOMAIN, TAG, 'Created new conversation')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Init page failed: %{public}s', JSON.stringify(err))
    }
  }

  build() {
    Column() {
      // 顶部导航栏
      this.TopBar()

      // 消息列表
      Scroll(this.scroller) {
        Column() {
          // 空状态
          if (this.messages.length === 0 && !this.isLoading) {
            this.EmptyState()
          }

          // 消息列表
          ForEach(this.messages, (msg: Message, index: number) => {
            ChatBubble({ message: msg })
          }, (msg: Message) => msg.id)

          // 流式输出中的临时消息
          if (this.isLoading && this.streamingContent) {
            ChatBubble({
              message: {
                id: 'streaming',
                role: 'assistant',
                content: this.streamingContent,
                timestamp: Date.now(),
                isStreaming: true,
                model: this.apiConfig ? getEffectiveModel(this.apiConfig) : ''
              }
            })
          } else if (this.isLoading && !this.streamingContent) {
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
              .backgroundColor('#999999')
              .justifyContent(FlexAlign.Center)

              LoadingProgress()
                .width(16)
                .height(16)
                .color('#999999')
                .margin({ left: 8 })
              Blank()
            }
            .width('100%')
            .padding({ left: 16, top: 8, bottom: 8 })
          }
        }
        .width('100%')
        .padding({ bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .onScrollEnd(() => {
        // 检测是否在底部
      })

      // 滚动到底部按钮
      if (this.showScrollToBottom) {
        Button() {
          Image($r('sys.media.ohos_ic_public_arrow_down'))
            .width(18)
            .height(18)
            .fillColor('#4A90D9')
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(Color.White)
        .shadow({ radius: 4, color: '#20000000', offsetX: 0, offsetY: 2 })
        .position({ right: 16, bottom: 80 })
        .onClick(() => {
          this.scroller.scrollEdge(Edge.Bottom)
        })
      }

      // 输入区域
      MessageInput({
        disabled: this.isLoading,
        onSend: (text: string) => {
          this.handleSend(text)
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentColorMode === 0 ? '#FFFFFF' : '#1A1A1A')
  }

  @Builder
  TopBar() {
    Row() {
      // 返回按钮
      Button() {
        Image($r('sys.media.ohos_ic_public_back'))
          .width(20)
          .height(20)
          .fillColor('#333333')
      }
      .width(36)
      .height(36)
      .backgroundColor('#00000000')
      .onClick(() => {
        this.saveAndGoBack()
      })

      // 标题
      Text(this.conversation.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)

      // 模型选择器
      if (this.apiConfig) {
        ModelSelector({
          config: this.apiConfig,
          onModelChange: (model: string) => {
            if (this.apiConfig) {
              this.apiConfig.selectedModel = model
              storageService.saveApiConfig(this.apiConfig)
            }
          },
          onTemperatureChange: (temp: number) => {
            if (this.apiConfig) {
              this.apiConfig.temperature = temp
              storageService.saveApiConfig(this.apiConfig)
            }
          }
        })
      }

      // 占位（保持标题居中）
      Column().width(36)
    }
    .width('100%')
    .height(52)
    .padding({ left: 8, right: 8 })
    .backgroundColor(this.currentColorMode === 0 ? '#FAFAFA' : '#222222')
    .borderWidth({ bottom: 0.5 })
    .borderColor('#E0E0E0')
  }

  @Builder
  EmptyState() {
    Column() {
      // Logo/图标区域
      Column() {
        Text('💬')
          .fontSize(48)
      }
      .width(80)
      .height(80)
      .borderRadius(40)
      .backgroundColor('#F0F0F0')
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 16 })

      Text('DeepChat')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .padding({ bottom: 8 })

      Text('使用 DeepSeek / OpenAI 驱动')
        .fontSize(14)
        .fontColor('#999999')
        .padding({ bottom: 4 })

      Text('在下方输入消息开始对话')
        .fontSize(13)
        .fontColor('#BBBBBB')
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
    this.isLoading = true

    // 滚动到底部
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom)
    }, 100)

    // 获取所有消息历史（包括刚添加的）
    const allMessages = [...this.messages]

    // 发送请求
    await apiService.chatStream(
      this.apiConfig,
      allMessages,
      this.memories,
      {
        onChunk: (content: string) => {
          this.streamingContent += content
          // 自动滚动
          this.scroller.scrollEdge(Edge.Bottom)
        },
        onDone: (fullContent: string) => {
          // 流式完成，添加 AI 消息
          if (fullContent) {
            const aiMsg = createMessage('assistant', fullContent, getEffectiveModel(this.apiConfig!))
            this.messages.push(aiMsg)
          }
          this.streamingContent = ''
          this.isLoading = false
          this.saveConversation()
        },
        onError: (error: string) => {
          // 错误处理
          const errorMsg = createMessage('assistant', `❌ 请求出错: ${error}`, '')
          this.messages.push(errorMsg)
          this.streamingContent = ''
          this.isLoading = false
          this.saveConversation()
        }
      }
    )
  }

  /**
   * 保存对话并返回
   */
  private async saveAndGoBack(): Promise<void> {
    await this.saveConversation()
    router.back()
  }

  /**
   * 保存当前对话到存储
   */
  private async saveConversation(): Promise<void> {
    try {
      this.conversation.messages = this.messages
      this.conversation.updatedAt = Date.now()

      const conversations = await storageService.loadConversations()
      const existingIdx = conversations.findIndex(c => c.id === this.conversation.id)

      if (existingIdx >= 0) {
        conversations[existingIdx] = this.conversation
      } else if (this.messages.length > 0) {
        // 只有有消息时才保存
        conversations.unshift(this.conversation)
      }

      await storageService.saveConversations(conversations)
      hilog.info(DOMAIN, TAG, 'Conversation saved')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Save conversation failed: %{public}s', JSON.stringify(err))
    }
  }
}
