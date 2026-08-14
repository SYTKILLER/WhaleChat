/**
 * MemoryPage — 永久记忆管理页面
 *
 * 列表 + 左滑删除 + 点击查看详情（showDialog）。
 */
import { Memory, createMemory } from '../models/Memory'
import { storageService } from '../services/StorageService'
import { syncService } from '../services/SyncService'
import { LucideIcon, LucideIcons } from '../components/LucideIcon'
import { MemoryDialog } from '../components/MemoryDialog'
import { router, PromptAction } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'

const DOMAIN = 0x0007
const TAG = 'MemoryPage'

@Entry
@Component
struct MemoryPage {
  @State memories: Memory[] = []
  @State inputText: string = ''
  private memoryDialogController: CustomDialogController | null = null
  @StorageLink('themeColor') themeColor: string = '#007DFF'
  @StorageLink('currentColorMode') currentColorMode: number = 0

  aboutToAppear(): void {
    this.loadMemories()
  }

  aboutToDisappear(): void {
    this.memoryDialogController = null
  }

  onPageShow(): void {
    this.loadMemories()
  }

  async loadMemories(): Promise<void> {
    try {
      await storageService.init(getContext(this))
      this.memories = await storageService.loadMemories()

      // 云同步：触发端云同步后重新加载
      await syncService.syncMemories('')
      const refreshed = await storageService.loadMemories()
      this.memories = refreshed
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Load memories failed')
    }
  }

  async saveMemories(): Promise<void> {
    await storageService.saveMemories(this.memories)
    // 通知 SettingsPage 刷新计数
    AppStorage.set('memoryUpdateKey', Date.now().toString())
  }

  /**
   * 调用华为分享面板，将指定记忆内容作为纯文本分享
   */
  shareMemory(index: number): void {
    if (index < 0 || index >= this.memories.length) {
      return
    }
    const content = this.memories[index].content
    if (!content) {
      return
    }
    try {
      const shareData = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
        content: content
      })
      const controller = new systemShare.ShareController(shareData)
      controller.show(getContext(this) as common.UIAbilityContext, {
        selectionMode: systemShare.SelectionMode.BATCH
      })
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Share memory failed: %{public}s', JSON.stringify(err))
    }
  }

  build() {
    Stack() {
      Column() {
        // 顶部标题栏
        Row() {
          Button() {
            LucideIcon({ icon: LucideIcons.ARROW_LEFT, color: this.currentColorMode === 1 ? '#333333' : '#CCCCCC', iconSize: 22 })
          }
          .width(36).height(36).backgroundColor('#00000000')
          .onClick(() => { router.back() })

          Text('永久记忆')
            .fontSize(19).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1).textAlign(TextAlign.Center)

          Column().width(36)
        }
        .width('100%').height(96).padding({ left: 8, right: 8, top: 40 })
        .backgroundColor(this.currentColorMode === 1 ?
          'rgba(250, 250, 250, 0.75)' : 'rgba(34, 34, 34, 0.75)')
        .backgroundBlurStyle(BlurStyle.Regular)
        .borderWidth({ bottom: 0.5 })
        .borderColor(this.currentColorMode === 1 ? '#E0E0E0' : '#444444')

        // 记忆列表
        if (this.memories.length === 0) {
          Column() {
            Text('暂无记忆').fontSize(15).fontColor($r('app.color.text_secondary'))
            Text('点击下方 + 添加').fontSize(12).fontColor($r('app.color.text_hint')).margin({ top: 4 })
          }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.memories, (mem: Memory, index: number) => {
              ListItem() {
                Row() {
                  Text(mem.content)
                    .fontSize(15)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                .backgroundColor(this.currentColorMode === 1 ? '#FFFFFF' : '#2A2A2A')
                .borderRadius(12)
                .shadow({ radius: 4, color: '#10000000', offsetY: 1 })
                .onClick(() => {
                  let ctx = this.getUIContext()
                  let promptAction: PromptAction = ctx.getPromptAction()
                  promptAction.showDialog({
                    title: '记忆详情',
                    message: mem.content,
                    buttons: [{ text: '关闭', color: this.themeColor }]
                  })
                })
              }
              .margin({ left: 12, right: 12, top: 4, bottom: 4 })
              .backgroundColor(Color.Transparent)
              .swipeAction({
                end: {
                  builder: () => { this.SwipeActions(index) },
                  actionAreaDistance: 120,
                  onAction: () => {
                    const preview = this.memories[index].content.length > 30
                      ? this.memories[index].content.substring(0, 30) + '...'
                      : this.memories[index].content
                    this.getUIContext().showAlertDialog({
                      title: '确认删除',
                      message: `确定要删除记忆「${preview}」吗？删除后无法恢复。`,
                      primaryButton: {
                        value: '删除',
                        fontColor: '#FF3B30',
                        action: () => {
                          this.memories.splice(index, 1)
                          this.saveMemories()
                        }
                      },
                      secondaryButton: {
                        value: '取消',
                        action: () => {}
                      }
                    })
                  }
                }
              })
            })
          }
          .layoutWeight(1)
          .backgroundColor(Color.Transparent)
          .scrollBar(BarState.Auto)
        }

        Column().height(80)
      }
      .width('100%').height('100%')
      .backgroundColor($r('app.color.bg_page'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      // 加号按钮
      Button() {
        LucideIcon({ icon: LucideIcons.PLUS, color: '#FFFFFF', iconSize: 28 })
      }
      .width(56).height(56).borderRadius(28)
      .backgroundColor(this.themeColor)
      .shadow({ radius: 12, color: '#30000000', offsetY: 4 })
      .position({ x: '50%', y: '100%' })
      .translate({ x: '-50%', y: -100 })
      .onClick(() => {
        this.inputText = ''
        if (this.memoryDialogController === null) {
          this.memoryDialogController = new CustomDialogController({
            builder: MemoryDialog({
              contentText: $inputText,
              confirm: () => {
                const t = this.inputText.trim()
                if (t.length > 0) {
                  const mem = createMemory(t)
                  this.memories.push(mem)
                  this.saveMemories()
                }
              }
            }),
            autoCancel: true,
            alignment: DialogAlignment.Center,
            customStyle: false
          })
        }
        this.memoryDialogController?.open()
      })
    }
    .width('100%').height('100%')
  }

  @Builder
  SwipeActions(index: number) {
    Row() {
      // 分享 — 蓝底 share 圆图标
      Button() {
        LucideIcon({ icon: LucideIcons.SHARE, color: '#FFFFFF', iconSize: 20 })
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor('#007AFF')
      .onClick(() => {
        this.shareMemory(index)
      })

      Column().width(8)

      // 删除 — 红底 trash 圆图标
      Button() {
        LucideIcon({ icon: LucideIcons.TRASH, color: '#FFFFFF', iconSize: 20 })
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor('#FF3B30')
      .onClick(() => {
        const preview = this.memories[index].content.length > 30
          ? this.memories[index].content.substring(0, 30) + '...'
          : this.memories[index].content
        this.getUIContext().showAlertDialog({
          title: '确认删除',
          message: `确定要删除记忆「${preview}」吗？删除后无法恢复。`,
          primaryButton: {
            value: '删除',
            fontColor: '#FF3B30',
            action: () => {
              this.memories.splice(index, 1)
              this.saveMemories()
            }
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
}
