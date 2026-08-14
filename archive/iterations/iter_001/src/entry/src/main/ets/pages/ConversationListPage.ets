/**
 * ConversationListPage — 对话列表页
 *
 * 作为首页显示所有对话历史，支持新建对话、点击进入对话。
 */

import { router } from '@kit.ArkUI'
import { Conversation } from '../models/Conversation'
import { storageService } from '../services/StorageService'
import { formatTimestamp, truncateText } from '../common/Utils'
import { ROUTES } from '../common/Constants'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0005
const TAG = 'ConversationListPage'

@Component
export struct ConversationListPage {
  @State conversations: Conversation[] = []
  @State loading: boolean = true
  @State hasApiConfig: boolean = false
  @StorageLink('currentColorMode') currentColorMode: number = 0

  aboutToAppear(): void {
    this.loadData()
  }

  onPageShow(): void {
    // 每次回到页面时刷新
    this.loadData()
  }

  async loadData(): Promise<void> {
    try {
      await storageService.init(getContext(this))
      this.conversations = await storageService.loadConversations()
      this.hasApiConfig = await storageService.hasLaunched()
      this.loading = false

      hilog.info(DOMAIN, TAG, 'Loaded %{public}d conversations', this.conversations.length)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Load failed: %{public}s', JSON.stringify(err))
      this.loading = false
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('对话')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)

        Blank()

        // 新建对话按钮
        Button() {
          Image($r('sys.media.ohos_ic_public_add'))
            .width(20)
            .height(20)
            .fillColor('#4A90D9')
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor('#E8F0FE')
        .onClick(() => {
          this.newConversation()
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8, bottom: 8 })

      // 新建对话快捷入口
      this.NewChatButton()

      // 对话列表
      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(24)
            .height(24)
            .color('#4A90D9')
            .margin({ top: 60 })
          Text('加载中…')
            .fontSize(13)
            .fontColor('#999999')
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
      } else if (this.conversations.length === 0) {
        this.EmptyState()
      } else {
        List() {
          ForEach(this.conversations, (conv: Conversation) => {
            ListItem() {
              this.ConversationItem(conv)
            }
            .swipeAction({
              end: {
                builder: () => {
                  this.DeleteButton(conv)
                },
                actionAreaDistance: 80
              }
            })
          })
        }
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#E8E8E8' })
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentColorMode === 0 ? '#FFFFFF' : '#1A1A1A')
  }

  @Builder
  NewChatButton() {
    Row() {
      Image($r('sys.media.ohos_ic_public_add'))
        .width(18)
        .height(18)
        .fillColor('#4A90D9')
      Text('新建对话')
        .fontSize(15)
        .fontColor('#4A90D9')
        .margin({ left: 8 })
    }
    .width('100%')
    .height(48)
    .padding({ left: 20 })
    .onClick(() => {
      this.newConversation()
    })
    .borderWidth({ bottom: 0.5 })
    .borderColor('#E8E8E8')
  }

  @Builder
  ConversationItem(conv: Conversation) {
    Row() {
      Column() {
        // 标题
        Text(conv.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        // 预览（最后一条消息）
        if (conv.messages.length > 0) {
          const lastMsg = conv.messages[conv.messages.length - 1]
          Text(truncateText(lastMsg.content, 60))
            .fontSize(13)
            .fontColor('#999999')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 4 })
        }

        // 时间和模型
        Row() {
          Text(formatTimestamp(conv.updatedAt))
            .fontSize(11)
            .fontColor('#BBBBBB')
          Text(` · ${conv.model}`)
            .fontSize(11)
            .fontColor('#BBBBBB')
        }
        .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 箭头
      Image($r('sys.media.ohos_ic_public_arrow_right'))
        .width(16)
        .height(16)
        .fillColor('#CCCCCC')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .onClick(() => {
      router.pushUrl({
        url: ROUTES.CHAT,
        params: { conversationId: conv.id }
      })
    })
  }

  @Builder
  DeleteButton(conv: Conversation) {
    Button() {
      Image($r('sys.media.ohos_ic_public_cancel'))
        .width(20)
        .height(20)
        .fillColor(Color.White)
    }
    .width(72)
    .height('100%')
    .backgroundColor('#FF3B30')
    .onClick(() => {
      this.deleteConversation(conv)
    })
  }

  @Builder
  EmptyState() {
    Column() {
      Text('💬')
        .fontSize(48)
        .margin({ bottom: 12 })
      Text('还没有对话')
        .fontSize(16)
        .fontColor('#999999')
      Text('点击上方按钮开始新对话')
        .fontSize(13)
        .fontColor('#BBBBBB')
        .margin({ top: 4 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  /**
   * 新建对话
   */
  private newConversation(): void {
    router.pushUrl({
      url: ROUTES.CHAT,
      params: { conversationId: '' }
    })
  }

  /**
   * 删除对话
   */
  private async deleteConversation(conv: Conversation): Promise<void> {
    try {
      this.conversations = this.conversations.filter(c => c.id !== conv.id)
      await storageService.saveConversations(this.conversations)
      hilog.info(DOMAIN, TAG, 'Deleted conversation: %{public}s', conv.title)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Delete failed: %{public}s', JSON.stringify(err))
    }
  }
}
