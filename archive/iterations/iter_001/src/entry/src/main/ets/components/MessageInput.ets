/**
 * MessageInput 组件 — 消息输入区域
 */

@Component
export struct MessageInput {
  @State inputText: string = ''
  /** 发送回调，返回用户输入文本 */
  onSend?: (text: string) => void
  /** 是否禁用（正在等待 AI 回复时） */
  @Prop disabled: boolean = false

  build() {
    Row() {
      // 输入框
      TextArea({ text: this.inputText, placeholder: '输入消息…' })
        .fontSize(15)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor('#F5F5F5')
        .borderRadius(20)
        .layoutWeight(1)
        .maxLines(4)
        .onChange((value: string) => {
          this.inputText = value
        })

      // 发送按钮
      Button('发送')
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor(this.inputText.trim() ? '#4A90D9' : '#CCCCCC')
        .borderRadius(20)
        .padding({ left: 16, right: 16 })
        .height(40)
        .enabled(this.inputText.trim().length > 0 && !this.disabled)
        .margin({ left: 8 })
        .onClick(() => {
          const text = this.inputText.trim()
          if (text && this.onSend) {
            this.onSend(text)
            this.inputText = ''
          }
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(Color.White)
    .shadow({
      radius: 4,
      color: '#10000000',
      offsetX: 0,
      offsetY: -2
    })
  }
}
