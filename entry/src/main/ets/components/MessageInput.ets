/**
 * MessageInput 组件 — 消息输入区域（单卡片布局：输入区 + 深度思考/发送控制行）
 *
 * 视效说明：
 * - 毛玻璃背景由宿主页面（ChatPage InputArea）统一提供，本组件卡片为不透明浮起表面
 * - 输入卡片聚焦时边框点光源照亮；发送按钮带主题色投影与按压光效
 */

import { vibrator } from '@kit.SensorServiceKit'
import { hdsEffect } from '@kit.UIDesignKit'

@Preview({ title: 'MessageInput - 默认', width: 390, height: 120 })
@Component
export struct MessageInput {
  @State inputText: string = ''
  /** 发送回调，返回用户输入文本 */
  onSend?: (text: string) => void
  /** 是否禁用（正在等待 AI 回复时） */
  @Prop disabled: boolean = false
  /** 深度思考开关（状态由父组件持有） */
  @Prop deepThinking: boolean = false
  /** 深度思考切换回调 */
  onToggleDeep?: (next: boolean) => void
  @StorageLink('themeColor') themeColor: string = '#007DFF'
  @StorageLink('currentColorMode') currentColorMode: number = 0
  @State inputFocused: boolean = false
  // 视效对象在组件构造时预构建，build 重跑时复用同一实例，避免流式输出期间高频重建
  private focusGlowEffect: VisualEffect = new hdsEffect.HdsEffectBuilder()
    .pointLight({
      sourceType: hdsEffect.PointLightSourceType.SOFT,
      illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER,
      options: { color: this.themeColor, intensity: 10, height: 120 }
    })
    .buildEffect()
  private noVisualEffect: VisualEffect = new hdsEffect.HdsEffectBuilder().buildEffect()
  // 发送按钮沉浸光感：点光源自发光（亮光源+主题色）+ 按压光效，仅在按钮可用时应用
  private sendGlowEffect: VisualEffect = new hdsEffect.HdsEffectBuilder()
    .pointLight({
      sourceType: hdsEffect.PointLightSourceType.BRIGHT,
      illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER,
      options: { color: this.themeColor, intensity: 12, height: 90 }
    })
    .pressShadow(hdsEffect.PressShadowType.BLEND_WHITE)
    .buildEffect()

  private hintColor(): string {
    return this.currentColorMode === 1 ? '#8C8C8C' : '#777777'
  }

  build() {
    // 输入卡片：不透明浮起表面，聚焦时点光源照亮边框
    Column() {
      TextArea({ text: this.inputText, placeholder: '输入消息…' })
        .fontSize(15)
        .padding({ left: 4, right: 4, top: 8, bottom: 4 })
        .backgroundColor(Color.Transparent)
        .constraintSize({ minHeight: 40, maxHeight: 140 })
        .width('100%')
        .onChange((value: string) => {
          this.inputText = value
        })
        .onFocus(() => { this.inputFocused = true })
        .onBlur(() => { this.inputFocused = false })

      Row() {
        // 深度思考 chip
        Row() {
          SymbolGlyph($r('sys.symbol.lightbulb'))
            .fontSize(14)
            .fontColor([this.deepThinking ? this.themeColor : this.hintColor()])
          Text('深度思考')
            .fontSize(13)
            .fontColor(this.deepThinking ? this.themeColor : this.hintColor())
            .margin({ left: 4 })
        }
        .height(30)
        .padding({ left: 12, right: 12 })
        .borderRadius(15)
        .backgroundColor(this.deepThinking ? this.themeColor + '1F' :
          (this.currentColorMode === 1 ? '#0A000000' : '#14FFFFFF'))
        .constraintSize({ maxWidth: '60%' })
        .onClick(() => { this.onToggleDeep?.(!this.deepThinking) })

        Blank()

        // 发送按钮 — 未输入：浅底深箭头；激活：主题色底（宇宙蓝类高对比色）+ 浅色箭头
        // 沉浸光感：点光源发光 + 按压光效
        Button() {
          SymbolGlyph($r('sys.symbol.arrow_up'))
            .fontSize(18)
            .fontColor([this.inputText.trim() ? '#FFFFFF' :
              (this.currentColorMode === 1 ? '#5A5A5A' : '#A6A6A6')])
        }
        .width(32)
        .height(32)
        .borderRadius(16)
        .backgroundColor(this.inputText.trim() ? this.themeColor :
          (this.currentColorMode === 1 ? '#E8E8E8' : '#3C3C3C'))
        .shadow({
          radius: 10,
          color: this.inputText.trim() ? this.themeColor + '4D' : '#00000000',
          offsetY: 3
        })
        .visualEffect(this.inputText.trim() ? this.sendGlowEffect : this.noVisualEffect)
        .enabled(this.inputText.trim().length > 0 && !this.disabled)
        .onClick(() => {
          const text = this.inputText.trim()
          if (text && this.onSend) {
            try { vibrator.startVibration({ type: 'time', duration: 15 }, { usage: 'touch' }) } catch (_) {}
            this.onSend(text)
            this.inputText = ''
          }
        })
      }
      .width('100%')
      .margin({ top: 6 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(24)
    .border({ width: 0.8, color: this.currentColorMode === 1 ? '#14000000' : '#1FFFFFFF' })
    .shadow({
      radius: 12,
      color: this.currentColorMode === 1 ? '#17000000' : '#52000000',
      offsetY: 3
    })
    .clip(true)
    .visualEffect(this.inputFocused ? this.focusGlowEffect : this.noVisualEffect)
  }
}
