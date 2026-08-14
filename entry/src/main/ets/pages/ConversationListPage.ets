/**
 * ConversationListPage — 对话列表页
 *
 * 作为首页显示所有对话历史，支持新建对话、点击进入对话。
 */

import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { Conversation } from '../models/Conversation'
import { storageService } from '../services/StorageService'
import { syncService } from '../services/SyncService'
import { formatTimestamp, truncateText } from '../common/Utils'
import { ROUTES } from '../common/Constants'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { LucideIcon, LucideIcons } from '../components/LucideIcon'
import { RenameDialog } from '../components/RenameDialog'
import { shareConversation as doShare } from '../utils/ExportHelper'

const DOMAIN = 0x0005
const TAG = 'ConversationListPage'

@Preview({ title: '对话列表 - 浅色', width: 390, height: 844 })
@Preview({ title: '对话列表 - 深色', width: 390, height: 844, colorMode: 'dark' })
@Entry
@Component
export struct ConversationListPage {
  @State conversations: Conversation[] = []
  @State loading: boolean = true
  @State renameText: string = ''
  private renameTargetId: string = ''
  private renameDialogController: CustomDialogController | null = null
  @StorageLink('themeColor') themeColor: string = '#007DFF'
  @StorageLink('currentColorMode') currentColorMode: number = 0
  @StorageLink('convListRefreshKey') @Watch('onRefresh') refreshKey: string = ''
  @StorageLink('account_logged_in') accountLoggedIn: boolean = false

  aboutToAppear(): void {
    this.loadData()
  }

  aboutToDisappear(): void {
    this.renameDialogController = null
  }

  onPageShow(): void {
    this.loadData()
  }

  onRefresh(): void {
    this.loadData()
  }

  async loadData(): Promise<void> {
    try {
      await storageService.init(getContext(this))
      this.conversations = await storageService.loadActiveConversations()

      // 云同步：触发端云同步，然后重新加载
      await syncService.syncConversations('')
      const refreshed = await storageService.loadActiveConversations()
      this.conversations = refreshed

      this.loading = false
      hilog.info(DOMAIN, TAG, 'Loaded %{public}d conversations', this.conversations.length)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Load failed: %{public}s', JSON.stringify(err))
      this.loading = false
    }
  }

  build() {
    Column() {
      // 强调型标题栏（Free 样式）：左标题 → 右按钮
      Row() {
        Text('对话')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Blank()

        // 新建对话按钮 — 沉浸光感材质，无主题色
        Button() {
          LucideIcon({
            icon: LucideIcons.PLUS,
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
          this.newConversation()
        })
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

      // 对话列表
      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(this.themeColor)
            .margin({ top: 60 })
          Text('加载中…')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
      } else if (this.conversations.length === 0) {
        Column() {
          Blank().layoutWeight(4)
          this.EmptyState()
          Blank().layoutWeight(6)
        }
        .layoutWeight(1)
      } else {
        List() {
          ForEach(this.conversations, (conv: Conversation) => {
            ListItem() {
              this.ConversationItem(conv)
            }
            .padding({ left: 16, right: 16, top: 3, bottom: 3 })
            .swipeAction({
              end: {
                builder: () => {
                  this.SwipeActions(conv)
                },
                actionAreaDistance: 136
              }
            })
          })
          ListItem() {
            Row()
              .height(88)
              .width('100%')
              .backgroundColor(Color.Transparent)
          }
        }
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: this.currentColorMode === 1 ? '#E8E8E8' : '#444444' })
        .backgroundColor(Color.Transparent)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentColorMode === 1 ? '#F2F2F2' : '#121212')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])


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
          Text(truncateText(conv.messages[conv.messages.length - 1].content, 60))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 4 })
        }

        // 时间和模型
        Row() {
          Text(formatTimestamp(conv.updatedAt))
            .fontSize(11)
            .fontColor($r('app.color.text_hint'))
          Text(` · ${conv.model}`)
            .fontSize(11)
            .fontColor($r('app.color.text_hint'))
        }
        .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 箭头
      LucideIcon({
        icon: LucideIcons.CHEVRON_RIGHT,
        color: this.currentColorMode === 1 ? '#CCCCCC' : '#AAAAAA',
        iconSize: 27
      })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .backgroundColor(this.currentColorMode === 1 ? '#FFFFFF' : '#2A2A2A')
    .borderRadius(12)
    .shadow({ radius: 4, color: '#10000000', offsetY: 1 })
    .onClick(() => {
      router.pushUrl({
        url: ROUTES.CHAT,
        params: { conversationId: conv.id }
      })
    })
  }

  @Builder
  SwipeActions(conv: Conversation) {
    Row() {
      // 重命名 — 绿底
      Button() {
        LucideIcon({ icon: LucideIcons.RENAME, color: '#FFFFFF', iconSize: 20 })
      }
      .width(40).height(40).borderRadius(20).backgroundColor('#34C759')
      .onClick(() => {
        this.renameText = conv.title
        this.renameTargetId = conv.id
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

      Column().width(8)

      // 分享 — 蓝底
      Button() {
        LucideIcon({ icon: LucideIcons.SHARE, color: '#FFFFFF', iconSize: 20 })
      }
      .width(40).height(40).borderRadius(20).backgroundColor('#007AFF')
      .onClick(() => { this.shareConversation(conv) })

      Column().width(8)

      // 删除 — 红底
      Button() {
        LucideIcon({ icon: LucideIcons.TRASH, color: '#FFFFFF', iconSize: 20 })
      }
      .width(40).height(40).borderRadius(20).backgroundColor('#FF3B30')
      .onClick(() => {
        this.getUIContext().showAlertDialog({
          title: '确认删除',
          message: `确定要将对话「${conv.title}」移入回收站吗？`,
          primaryButton: {
            value: '移入回收站',
            fontColor: '#FF3B30',
            action: () => { this.deleteConversation(conv) }
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

  @Builder
  EmptyState() {
    Column() {
      SymbolGlyph($r('sys.symbol.ellipsis_message'))
        .fontSize(48)
        .fontColor([$r('app.color.text_secondary')])
        .margin({ bottom: 12 })
      Text('还没有对话')
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
      Text('点击上方按钮开始新对话')
        .fontSize(13)
        .fontColor($r('app.color.text_hint'))
        .margin({ top: 4 })
    }
    .width('100%')
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
   * 软删除对话（移入回收站）
   */
  private async deleteConversation(conv: Conversation): Promise<void> {
    try {
      conv.isDeleted = true
      conv.updatedAt = Date.now()
      // 保存所有对话（包括被标记的），触发 UI 刷新
      const all = await storageService.loadConversations()
      const idx = all.findIndex(c => c.id === conv.id)
      if (idx >= 0) {
        all[idx].isDeleted = true
        all[idx].updatedAt = Date.now()
        hilog.info(DOMAIN, TAG, 'Marking isDeleted=true for: %{public}s', conv.id)
      }
      await storageService.saveConversations(all)
      // 重新加载活跃对话以刷新列表
      this.conversations = await storageService.loadActiveConversations()
      hilog.info(DOMAIN, TAG, 'Moved to recycle bin: %{public}s', conv.title)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Delete failed: %{public}s', JSON.stringify(err))
    }
  }

  /**
   * 分享对话：生成 MD 文件 → 系统分享面板
   */
  private async shareConversation(conv: Conversation): Promise<void> {
    await doShare(getContext(this) as common.UIAbilityContext, conv)
  }



  private async confirmRename(): Promise<void> {
    const t = this.renameText.trim()
    if (t.length > 0 && this.renameTargetId.length > 0) {
      const convs = await storageService.loadConversations()
      const idx = convs.findIndex(c => c.id === this.renameTargetId)
      if (idx >= 0) {
        convs[idx].title = t
        convs[idx].updatedAt = Date.now()
        await storageService.saveConversations(convs)
        this.conversations = convs
      }
    }
  }

}
