/**
 * RecycleBinPage — 回收站页面
 *
 * 显示被软删除的对话，支持恢复和永久删除。
 * 右上角：全部恢复 + 全部删除按钮。
 */
import { router } from '@kit.ArkUI'
import { Conversation } from '../models/Conversation'
import { storageService } from '../services/StorageService'
import { formatTimestamp, truncateText } from '../common/Utils'
import { ROUTES } from '../common/Constants'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { LucideIcon, LucideIcons } from '../components/LucideIcon'

const DOMAIN = 0x0008
const TAG = 'RecycleBinPage'

@Entry
@Component
struct RecycleBinPage {
  @State conversations: Conversation[] = []
  @State loading: boolean = true
  @StorageLink('themeColor') themeColor: string = '#007DFF'
  @StorageLink('currentColorMode') currentColorMode: number = 0

  aboutToAppear(): void {
    this.loadData()
  }

  onPageShow(): void {
    this.loadData()
  }

  async loadData(): Promise<void> {
    try {
      await storageService.init(getContext(this))
      this.conversations = await storageService.loadRecycleBin()
      this.loading = false
      hilog.info(DOMAIN, TAG, 'Recycle bin: %{public}d conversations', this.conversations.length)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Load failed: %{public}s', JSON.stringify(err))
      this.loading = false
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        // 返回按钮
        Button() {
          LucideIcon({
            icon: LucideIcons.ARROW_LEFT,
            color: this.currentColorMode === 1 ? '#333333' : '#CCCCCC',
            iconSize: 22
          })
        }
        .width(40).height(40).borderRadius(20)
        .backgroundColor(this.currentColorMode === 1 ?
          'rgba(250, 250, 250, 0.55)' : 'rgba(34, 34, 34, 0.55)')
        .backgroundBlurStyle(BlurStyle.Regular)
        .shadow({ radius: 8, color: '#18000000', offsetY: 2 })
        .onClick(() => { router.back() })

        // 标题
        Text('回收站')
          .fontSize(19)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 全部恢复按钮
        Button() {
          LucideIcon({
            icon: LucideIcons.ARROW_COUNTERCLOCKWISE,
            color: this.currentColorMode === 1 ? '#333333' : '#CCCCCC',
            iconSize: 22
          })
        }
        .width(40).height(40).borderRadius(20)
        .backgroundColor(this.currentColorMode === 1 ?
          'rgba(250, 250, 250, 0.55)' : 'rgba(34, 34, 34, 0.55)')
        .backgroundBlurStyle(BlurStyle.Regular)
        .shadow({ radius: 8, color: '#18000000', offsetY: 2 })
        .onClick(() => { this.restoreAll() })

        Column().width(8)

        // 全部删除按钮
        Button() {
          LucideIcon({
            icon: LucideIcons.CLEAN,
            color: this.currentColorMode === 1 ? '#333333' : '#CCCCCC',
            iconSize: 22
          })
        }
        .width(40).height(40).borderRadius(20)
        .backgroundColor(this.currentColorMode === 1 ?
          'rgba(250, 250, 250, 0.55)' : 'rgba(34, 34, 34, 0.55)')
        .backgroundBlurStyle(BlurStyle.Regular)
        .shadow({ radius: 8, color: '#18000000', offsetY: 2 })
        .onClick(() => { this.confirmDeleteAll() })
      }
      .width('100%')
      .height(112)
      .padding({ left: 8, right: 8, top: 44, bottom: 12 })
      .backgroundColor(this.currentColorMode === 1 ?
        'rgba(242, 242, 242, 0.75)' : 'rgba(18, 18, 18, 0.75)')
      .backgroundBlurStyle(BlurStyle.Regular)
      .borderWidth({ bottom: 0.5 })
      .borderColor(this.currentColorMode === 1 ? '#E0E0E0' : '#444444')

      // 内容区
      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(24).height(24)
            .color(this.themeColor)
            .margin({ top: 60 })
          Text('加载中…')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
        }
        .width('100%').layoutWeight(1)
      } else if (this.conversations.length === 0) {
        Column() {
          SymbolGlyph($r('sys.symbol.ohos_trash'))
            .fontSize(48)
            .fontColor([$r('app.color.text_secondary')])
            .margin({ bottom: 12 })
          Text('回收站为空')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
          Text('删除的对话将出现在这里')
            .fontSize(13)
            .fontColor($r('app.color.text_hint'))
            .margin({ top: 4 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.conversations, (conv: Conversation) => {
            ListItem() {
              this.RecycleBinItem(conv)
            }
            .padding({ left: 16, right: 16, top: 3, bottom: 3 })
            .swipeAction({
              end: {
                builder: () => { this.SwipeActions(conv) },
                actionAreaDistance: 136
              }
            })
          })
          ListItem() {
            Row().height(88).width('100%').backgroundColor(Color.Transparent)
          }
        }
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: this.currentColorMode === 1 ? '#E8E8E8' : '#444444' })
        .backgroundColor(Color.Transparent)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.currentColorMode === 1 ? '#F2F2F2' : '#121212')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  RecycleBinItem(conv: Conversation) {
    Row() {
      Column() {
        Text(conv.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (conv.messages.length > 0) {
          Text(truncateText(conv.messages[conv.messages.length - 1].content, 60))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 4 })
        }

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
  }

  @Builder
  SwipeActions(conv: Conversation) {
    Row() {
      // 恢复 — 蓝底
      Button() {
        LucideIcon({ icon: LucideIcons.ARROW_COUNTERCLOCKWISE, color: '#FFFFFF', iconSize: 20 })
      }
      .width(40).height(40).borderRadius(20).backgroundColor('#007AFF')
      .onClick(() => { this.restoreConversation(conv) })

      Column().width(8)

      // 永久删除 — 红底
      Button() {
        LucideIcon({ icon: LucideIcons.TRASH, color: '#FFFFFF', iconSize: 20 })
      }
      .width(40).height(40).borderRadius(20).backgroundColor('#FF3B30')
      .onClick(() => {
        this.getUIContext().showAlertDialog({
          title: '永久删除',
          message: `确定要永久删除对话「${conv.title}」吗？删除后无法恢复。`,
          primaryButton: {
            value: '删除',
            fontColor: '#FF3B30',
            action: () => { this.permanentlyDelete(conv) }
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

  /** 恢复单个对话 */
  private async restoreConversation(conv: Conversation): Promise<void> {
    try {
      const all = await storageService.loadConversations()
      const idx = all.findIndex(c => c.id === conv.id)
      if (idx >= 0) {
        all[idx].isDeleted = false
        all[idx].updatedAt = Date.now()
      }
      await storageService.saveConversations(all)
      this.conversations = await storageService.loadRecycleBin()
      hilog.info(DOMAIN, TAG, 'Restored: %{public}s', conv.title)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Restore failed: %{public}s', JSON.stringify(err))
    }
  }

  /** 永久删除单个对话 */
  private async permanentlyDelete(conv: Conversation): Promise<void> {
    try {
      const all = await storageService.loadConversations()
      const filtered = all.filter(c => c.id !== conv.id)
      await storageService.saveConversations(filtered)
      this.conversations = await storageService.loadRecycleBin()
      hilog.info(DOMAIN, TAG, 'Permanently deleted: %{public}s', conv.title)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Permanent delete failed: %{public}s', JSON.stringify(err))
    }
  }

  /** 全部恢复 */
  private async restoreAll(): Promise<void> {
    try {
      const all = await storageService.loadConversations()
      for (const c of all) {
        if (c.isDeleted) {
          c.isDeleted = false
          c.updatedAt = Date.now()
        }
      }
      await storageService.saveConversations(all)
      this.conversations = await storageService.loadRecycleBin()
      hilog.info(DOMAIN, TAG, 'All restored')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Restore all failed: %{public}s', JSON.stringify(err))
    }
  }

  /** 全部永久删除 — 弹出确认 */
  private confirmDeleteAll(): void {
    if (this.conversations.length === 0) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: '全部永久删除',
      message: `确定要永久删除回收站中的 ${this.conversations.length} 个对话吗？删除后无法恢复。`,
      primaryButton: {
        value: '全部删除',
        fontColor: '#FF3B30',
        action: () => { this.deleteAll() }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    })
  }

  /** 执行全部永久删除 */
  private async deleteAll(): Promise<void> {
    try {
      const all = await storageService.loadConversations()
      const filtered = all.filter(c => !c.isDeleted)
      await storageService.saveConversations(filtered)
      this.conversations = await storageService.loadRecycleBin()
      hilog.info(DOMAIN, TAG, 'All permanently deleted')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Delete all failed: %{public}s', JSON.stringify(err))
    }
  }
}
