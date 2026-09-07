/**
 * ModelSelector 组件 — 模型选择和参数设置弹出面板
 */

import { ApiConfig, PRESET_PROVIDERS, CUSTOM_PROVIDER_ID, getEffectiveModel } from '../models/ApiConfig'
import { LucideIcon, LucideIcons } from './LucideIcon'

@Component
export struct ModelSelector {
  @Prop config: ApiConfig
  /** 模型切换回调 */
  onModelChange?: (model: string) => void
  /** 温度变更回调 */
  onTemperatureChange?: (temperature: number) => void
  /** 关闭面板回调 */
  onClose?: () => void
  @State showPanel: boolean = false
  @State localTemperature: number = 0.8
  @StorageLink('themeColor') themeColor: string = '#007DFF'
  @StorageLink('currentColorMode') currentColorMode: number = 0

  aboutToAppear(): void {
    this.localTemperature = this.config.temperature
  }

  build() {
    Column() {
      // 触发按钮：显示当前模型
      Button() {
        Row() {
          Text(getEffectiveModel(this.config))
            .fontSize(13)
            .fontColor(this.themeColor)
          LucideIcon({
            icon: LucideIcons.CHEVRON_DOWN,
            color: this.themeColor,
            iconSize: 18
          })
          .margin({ left: 4 })
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      }
      .backgroundColor($r('app.color.bg_button'))
      .borderRadius(12)
      .height(30)
      .onClick(() => {
        this.showPanel = !this.showPanel
      })
    }
    .bindPopup(this.showPanel, {
      builder: this.ModelPanelBuilder,
      placement: Placement.BottomRight,
      enableArrow: false,
      onStateChange: (e) => {
        if (!e.isVisible) {
          this.showPanel = false
          if (this.onClose) {
            this.onClose()
          }
        }
      }
    })
  }

  @Builder
  ModelPanelBuilder() {
    Column() {
      Text('模型设置')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding(12)

      // 模型列表
      this.ModelListSection()

      Divider().height(1).color($r('app.color.divider_color'))

      // 温度滑块
      this.TemperatureSection()

      Divider().height(1).color($r('app.color.divider_color'))

      // 关闭按钮
      Button('完成')
        .fontSize(14)
        .width('100%')
        .margin(12)
        .onClick(() => {
          this.showPanel = false
          if (this.onClose) {
            this.onClose()
          }
        })
    }
    .width(200)
    .backgroundColor(this.currentColorMode === 1 ?
      'rgba(250, 250, 250, 0.85)' : 'rgba(34, 34, 34, 0.85)')
    .borderRadius(12)
    .backgroundBlurStyle(BlurStyle.Regular)
  }

  @Builder
  ModelListSection() {
    Column() {
      Text('选择模型')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 12, top: 8 })

      // 获取当前平台的模型列表
      if (this.config.providerId === CUSTOM_PROVIDER_ID) {
        Row() {
          Text(this.config.customModel || '自定义模型')
            .fontSize(14)
            .layoutWeight(1)
          Radio({ value: 'custom', group: 'models' })
            .checked(true)
        }
        .width('100%')
        .padding(12)
      } else {
        ForEach(PRESET_PROVIDERS.find(p => p.id === this.config.providerId)?.defaultModels ?? [], (modelName: string) => {
            Row() {
              Text(modelName)
                .fontSize(14)
                .layoutWeight(1)

              Radio({ value: modelName, group: 'models' })
                .checked(modelName === getEffectiveModel(this.config))
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .onClick(() => {
              if (this.onModelChange) {
                this.onModelChange(modelName)
              }
            })
          })
      }
    }
  }

  @Builder
  TemperatureSection() {
    Column() {
      Row() {
        Text('Temperature')
          .fontSize(13)
          .layoutWeight(1)
        Text(this.localTemperature.toFixed(1))
          .fontSize(13)
          .fontColor(this.themeColor)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8 })

      Slider({
        value: this.localTemperature,
        min: 0,
        max: 2,
        step: 0.1
      })
      .width('100%')
      .padding({ left: 12, right: 12 })
      .onChange((value: number) => {
        this.localTemperature = value
        if (this.onTemperatureChange) {
          this.onTemperatureChange(value)
        }
      })

      Row() {
        Text('精确')
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
        Blank()
        Text('创造性')
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ left: 12, right: 12, bottom: 8 })
    }
  }
}
