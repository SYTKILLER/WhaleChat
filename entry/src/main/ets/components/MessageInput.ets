/**
 * MessageInput 组件 — 消息输入区域
 */

import { vibrator } from '@kit.SensorServiceKit'

@Preview({ title: 'MessageInput - 默认', width: 390, height: 80 })
@Component
export struct MessageInput {
  @State inputText: string = ''
  /** 发送回调，返回用户输入文本 */
  onSend?: (text: string) => void
  /** 是否禁用（正在等待 AI 回复时） */
  @Prop disabled: boolean = false
  @StorageLink('themeColor') themeColor: string = '#007DFF'
  @StorageLink('currentColorMode') currentColorMode: number = 0

  build() {
    Row() {
      // 输入框 — 自适应高度（min 40 与发送按钮同高，max 140 超出内部滚动）
      TextArea({ text: this.inputText, placeholder: '输入消息…' })
        .fontSize(15)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.bg_input'))
        .borderRadius(20)
        .constraintSize({ minHeight: 40, maxHeight: 140 })
        .layoutWeight(1)
        .onChange((value: string) => {
          this.inputText = value
        })

      // 发送按钮
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_up'))
          .fontSize(28)
          .fontColor([Color.White])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(this.inputText.trim() ? this.themeColor :
        (this.currentColorMode === 1 ? '#CCCCCC' : '#808080'))
      .shadow({ radius: 4, color: '#20000000', offsetY: 2 })
      .enabled(this.inputText.trim().length > 0 && !this.disabled)
      .margin({ left: 8 })
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
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    // 沉浸光感：半透明背景 + 毛玻璃模糊
    .backgroundColor(this.currentColorMode === 1 ?
      'rgba(255, 255, 255, 0.75)' : 'rgba(34, 34, 34, 0.75)')
    .backgroundBlurStyle(BlurStyle.Regular)
    .shadow({
      radius: 4,
      color: this.currentColorMode === 1 ? '#10000000' : '#10FFFFFF',
      offsetX: 0,
      offsetY: -2
    })
  }
}
