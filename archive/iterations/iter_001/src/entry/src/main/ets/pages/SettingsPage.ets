/**
 * SettingsPage — 设置页面
 *
 * 主题切换、记忆管理、API 配置、导入导出入口
 */

import { router } from '@kit.ArkUI'
import { ConfigurationConstant } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { Memory, createMemory } from '../models/Memory'
import { storageService } from '../services/StorageService'
import { ROUTES, APP_INFO } from '../common/Constants'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0006
const TAG = 'SettingsPage'

@Component
export struct SettingsPage {
  @State memories: Memory[] = []
  @State showMemoryDialog: boolean = false
  @State newMemoryText: string = ''
  @StorageLink('currentColorMode') currentColorMode: number = 0
  @State isDarkMode: boolean = false

  aboutToAppear(): void {
    this.loadData()
    // 读取当前系统颜色模式
    this.isDarkMode = this.currentColorMode === 1
  }

  onPageShow(): void {
    this.loadData()
  }

  async loadData(): Promise<void> {
    try {
      await storageService.init(getContext(this))
      this.memories = await storageService.loadMemories()
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Load failed: %{public}s', JSON.stringify(err))
    }
  }

  build() {
    Column() {
      // 顶部标题
      Row() {
        Text('设置')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8, bottom: 16 })

      List() {
        // ===== API 配置 =====
        ListItem() {
          this.SectionHeader('API 配置')
        }

        ListItem() {
          this.SettingItem(
            'API 平台配置',
            '配置 DeepSeek / OpenAI 等 API',
            () => {
              router.pushUrl({ url: ROUTES.API_CONFIG })
            }
          )
        }

        // ===== 外观 =====
        ListItem() {
          this.SectionHeader('外观')
        }

        ListItem() {
          Row() {
            Text('跟随系统深色模式')
              .fontSize(15)
              .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.isDarkMode })
              .onChange((value: boolean) => {
                this.isDarkMode = value
                const ctx = getContext(this)
                if (value) {
                  ctx.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
                } else {
                  ctx.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
                }
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        }

        // ===== 永久记忆 =====
        ListItem() {
          this.SectionHeader('永久记忆')
        }

        ListItem() {
          Row() {
            Text('记忆管理')
              .fontSize(15)
              .layoutWeight(1)
            Text(`${this.memories.length} 条`)
              .fontSize(13)
              .fontColor('#999999')
              .margin({ right: 8 })
            Image($r('sys.media.ohos_ic_public_arrow_right'))
              .width(16)
              .height(16)
              .fillColor('#CCCCCC')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            this.showMemoryDialog = true
          })
        }

        // 记忆列表预览
        ForEach(this.memories.slice(0, 3), (mem: Memory) => {
          ListItem() {
            Text(mem.content)
              .fontSize(13)
              .fontColor('#999999')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .padding({ left: 32, right: 16, top: 4, bottom: 4 })
          }
        })

        if (this.memories.length > 3) {
          ListItem() {
            Text(`... 还有 ${this.memories.length - 3} 条记忆`)
              .fontSize(12)
              .fontColor('#BBBBBB')
              .width('100%')
              .padding({ left: 32, right: 16, top: 4, bottom: 4 })
          }
        }

        // ===== 数据管理 =====
        ListItem() {
          this.SectionHeader('数据管理')
        }

        ListItem() {
          this.SettingItem(
            '导出对话 (MD)',
            '将对话导出为 Markdown 文件',
            () => {
              // TODO: Phase 2 实现导出功能
              this.showToast('导出功能将在下一版本实现')
            }
          )
        }

        ListItem() {
          this.SettingItem(
            '导入对话 (MD)',
            '从 Markdown 文件导入对话',
            () => {
              // TODO: Phase 2 实现导入功能
              this.showToast('导入功能将在下一版本实现')
            }
          )
        }

        // ===== 关于 =====
        ListItem() {
          this.SectionHeader('关于')
        }

        ListItem() {
          Row() {
            Text('版本')
              .fontSize(15)
              .layoutWeight(1)
            Text(APP_INFO.VERSION)
              .fontSize(13)
              .fontColor('#999999')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        }

        ListItem() {
          Row() {
            Text(APP_INFO.DESCRIPTION)
              .fontSize(13)
              .fontColor('#999999')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 12, bottom: 24 })
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentColorMode === 0 ? '#FFFFFF' : '#1A1A1A')

    // 记忆管理弹窗
    if (this.showMemoryDialog) {
      this.MemoryDialog()
    }
  }

  @Builder
  SectionHeader(title: string) {
    Text(title)
      .fontSize(12)
      .fontColor('#999999')
      .fontWeight(FontWeight.Medium)
      .width('100%')
      .padding({ left: 16, top: 20, bottom: 6 })
      .backgroundColor(this.currentColorMode === 0 ? '#F8F8F8' : '#1E1E1E')
  }

  @Builder
  SettingItem(title: string, description: string, onClick: () => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
        Text(description)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Image($r('sys.media.ohos_ic_public_arrow_right'))
        .width(16)
        .height(16)
        .fillColor('#CCCCCC')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick(onClick)
  }

  @Builder
  MemoryDialog() {
    Column() {
      // 遮罩背景
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#80000000')
    .position({ x: 0, y: 0 })
    .onClick(() => {
      this.showMemoryDialog = false
    })

    // 弹窗内容
    Column() {
      Row() {
        Text('永久记忆')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button('关闭')
          .fontSize(14)
          .backgroundColor('#00000000')
          .fontColor('#4A90D9')
          .onClick(() => {
            this.showMemoryDialog = false
          })
      }
      .width('100%')
      .padding(16)

      // 新增记忆输入
      Row() {
        TextInput({ text: this.newMemoryText, placeholder: '输入新的记忆内容…' })
          .fontSize(14)
          .layoutWeight(1)
          .height(40)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .padding({ left: 12, right: 12 })

        Button('保存')
          .fontSize(13)
          .height(40)
          .margin({ left: 8 })
          .onClick(() => {
            this.saveMemory()
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      Divider().height(1).color('#EEEEEE')

      // 记忆列表
      if (this.memories.length === 0) {
        Text('暂无记忆，添加后每条记忆都会被注入到 AI 对话的上下文中')
          .fontSize(13)
          .fontColor('#999999')
          .padding(16)
          .width('100%')
      } else {
        List() {
          ForEach(this.memories, (mem: Memory, index: number) => {
            ListItem() {
              Row() {
                Text(mem.content)
                  .fontSize(14)
                  .layoutWeight(1)
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Button() {
                  Image($r('sys.media.ohos_ic_public_cancel'))
                    .width(14)
                    .height(14)
                    .fillColor('#FF3B30')
                }
                .width(28)
                .height(28)
                .backgroundColor('#00000000')
                .onClick(() => {
                  this.deleteMemory(index)
                })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .alignItems(VerticalAlign.Center)
            }
          })
        }
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
      }
    }
    .width('90%')
    .height('70%')
    .backgroundColor(Color.White)
    .borderRadius(16)
    .position({ x: '5%', y: '15%' })
    .shadow({ radius: 20, color: '#40000000', offsetX: 0, offsetY: 8 })
  }

  /**
   * 保存新记忆
   */
  private async saveMemory(): Promise<void> {
    const text = this.newMemoryText.trim()
    if (!text) return

    const mem = createMemory(text)
    this.memories.push(mem)
    this.newMemoryText = ''

    await storageService.saveMemories(this.memories)
    hilog.info(DOMAIN, TAG, 'Memory saved')
  }

  /**
   * 删除记忆
   */
  private async deleteMemory(index: number): Promise<void> {
    this.memories.splice(index, 1)
    await storageService.saveMemories(this.memories)
  }

  /**
   * 显示 Toast
   */
  private showToast(message: string): void {
    try {
      promptAction.showToast({ message, duration: 2000 })
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Toast failed')
    }
  }
}
