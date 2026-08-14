/**
 * RenameDialog — 重命名对话弹窗
 *
 * 使用 @CustomDialog 实现居中弹窗样式。
 * 替代 bindSheet 方案，解决位置靠下和键盘避让问题。
 */
@CustomDialog
export struct RenameDialog {
  controller?: CustomDialogController
  @Link titleText: string
  confirm: () => void = () => {}
  @StorageLink('currentColorMode') currentColorMode: number = 0
  @StorageLink('themeColor') themeColor: string = '#007DFF'

  build() {
    Column() {
      Text('重命名对话')
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.currentColorMode === 1 ? '#333333' : '#E0E0E0')
        .padding({ left: 16, right: 16, top: 24, bottom: 16 })
        .width('100%')
        .textAlign(TextAlign.Start)

      TextInput({ text: this.titleText })
        .fontSize(15)
        .width('90%')
        .constraintSize({ maxWidth: 300 })
        .height(44)
        .alignSelf(ItemAlign.Center)
        .padding({ left: 12, right: 12 })
        .backgroundColor(this.currentColorMode === 1 ? '#F5F5F5' : '#333333')
        .borderRadius(16)
        .onChange((value: string) => {
          this.titleText = value
        })

      Row() {
        Button('取消')
          .fontSize(14)
          .layoutWeight(1)
          .height(40)
          .backgroundColor(this.currentColorMode === 1 ? '#F0F0F0' : '#444444')
          .fontColor(this.currentColorMode === 1 ? '#333333' : '#CCCCCC')
          .borderRadius(16)
          .onClick(() => {
            this.controller?.close()
          })

        Blank().width(12)

        Button('确定')
          .fontSize(14)
          .layoutWeight(1)
          .height(40)
          .backgroundColor(this.themeColor)
          .fontColor(Color.White)
          .borderRadius(16)
          .onClick(() => {
            this.confirm()
            this.controller?.close()
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 24 })
    }
    .width('100%')
    .backgroundColor(this.currentColorMode === 1 ? Color.White : '#2A2A2A')
    .borderRadius(16)
  }
}
