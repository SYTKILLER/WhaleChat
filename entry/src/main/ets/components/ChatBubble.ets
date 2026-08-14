/**
 * ChatBubble 组件 — 单条消息气泡
 */

import { Message } from '../models/Message'
import { MarkdownView } from './MarkdownView'
import { markdownParser } from '../services/MarkdownParser'
import { formatTimestamp } from '../common/Utils'
import { pasteboard } from '@kit.BasicServicesKit'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { Conversation } from '../models/Conversation'
import { shareConversation } from '../utils/ExportHelper'

@Component
export struct ChatBubble {
  @Prop @Watch("onMessageChange") message: Message
  @State showTime: boolean = false
  @State localShowThinking: boolean = false
  @State streamingCompleted: string = ''
  @State streamingPending: string = ''
  @StorageLink('currentColorMode') currentColorMode: number = 0
  @StorageLink('themeColor') themeColor: string = '#007DFF'

  aboutToAppear(): void {
    this.onMessageChange()
  }

  onMessageChange(): void {

    this.localShowThinking = this.message.showThinking
    // 正式内容开始输出时自动折叠深度思考
    if (this.message.isStreaming &&
      this.message.content.length > 0 &&
      this.message.thinkingContent.length > 0) {
      this.localShowThinking = false
    }
    // 流式内容按空行分段：已完成部分可渲染 Markdown，待完成部分显示纯文本
    if (this.message.isStreaming && this.message.content.length > 0) {
      const idx: number = this.message.content.lastIndexOf('\n\n')
      if (idx > 0) {
        this.streamingCompleted = this.message.content.substring(0, idx)
        this.streamingPending = this.message.content.substring(idx + 2)
      } else {
        this.streamingCompleted = ''
        this.streamingPending = this.message.content
      }
    } else {
      this.streamingCompleted = ''
      this.streamingPending = ''
    }
  }

  build() {
    Column() {
      // 用户消息
      if (this.message.role === 'user') {
        Row() {
          Blank()
          Column() {
            Text(this.message.content)
              .fontSize(15)
              .copyOption(CopyOptions.InApp)
              .padding(12)
              .borderRadius({
                topLeft: 16,
                topRight: 4,
                bottomLeft: 16,
                bottomRight: 16
              })
              .backgroundColor(this.themeColor)
              .fontColor(Color.White)
              .shadow({ radius: 4, color: '#20000000', offsetY: 2 })
              .constraintSize({ maxWidth: '75%' })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 4 })
        .justifyContent(FlexAlign.End)
        .onClick(() => {
          this.showTime = !this.showTime
        })

        if (this.showTime) {
          Text(formatTimestamp(this.message.timestamp))
            .fontSize(10)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.End)
            .width('100%')
            .padding({ right: 16 })
        }
      }

      // AI 消息
      if (this.message.role === 'assistant') {
        // 深度思考区域
        if (this.message.thinkingContent) {
          Row() {
            Column() {
              Row() {
                Text('深度思考')
                  .fontSize(12)
                  .fontColor($r('app.color.text_subtle'))
                  .fontWeight(FontWeight.Medium)
                Blank()
                SymbolGlyph(this.localShowThinking ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_up'))
                  .fontSize(16)
                  .fontColor(['#AAAAAA'])
              }
              .width('100%')
              .padding({ left: 12, right: 12, top: 8, bottom: this.localShowThinking ? 4 : 8 })
              .onClick(() => {
                this.localShowThinking = !this.localShowThinking
              })

              if (this.localShowThinking) {
                Text(this.message.thinkingContent)
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .fontStyle(FontStyle.Italic)
                  .lineHeight(20)
                  .width('100%')
                  .padding({ left: 12, right: 12, bottom: 10 })
                  .wordBreak(WordBreak.BREAK_WORD)
              }
            }
            .layoutWeight(1)
            .backgroundColor($r('app.color.bg_input'))
            .borderRadius(10)
            .clip(true)
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 6 })
        }

        Row() {
          // 头像
          // 消息内容
          Column() {
            if (this.message.isStreaming && this.streamingCompleted.length > 0) {
              // 已完成段落实时渲染 Markdown
              MarkdownView({ tokens: markdownParser.parse(this.streamingCompleted) })
              if (this.streamingPending.length > 0) {
                Text(this.streamingPending)
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .fontStyle(FontStyle.Italic)
                  .margin({ top: 8 })
              }
            } else if (this.message.isStreaming) {
              Text(this.streamingPending || '思考中…')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .fontStyle(FontStyle.Italic)
            } else if (this.message.content) {
              MarkdownView({
                tokens: markdownParser.parse(this.message.content)
              })
            }
          }
          .padding(12)
          .borderRadius({
            topLeft: 4,
            topRight: 16,
            bottomLeft: 16,
            bottomRight: 16
          })
          .backgroundColor($r('app.color.bg_bubble_ai'))
          .shadow({ radius: 4, color: '#15000000', offsetY: 1 })
          .clip(true)
          .layoutWeight(1)
          .gesture(LongPressGesture().onAction(() => {
            this.copyAIContent()
          }))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 4 })
        .alignItems(VerticalAlign.Top)
        .onClick(() => {
          this.showTime = !this.showTime
        })

        // 复制按钮 + 分享按钮（仅对已完成的非流式消息显示）
        if (!this.message.isStreaming && this.message.content.length > 0) {
          Row() {
            Blank()
              .layoutWeight(1)
            Button() {
              SymbolGlyph($r('sys.symbol.plus_square_on_square'))
                .fontSize(16)
                .fontColor([this.currentColorMode === 1 ? '#6B6B6B' : '#AAAAAA'])
            }
            .width(30)
            .height(30)
            .borderRadius(15)
            .backgroundColor('#00000000')
            .onClick(() => {
              this.copyAIContent()
            })

            Column().width(16)

            Button() {
              SymbolGlyph($r('sys.symbol.share'))
                .fontSize(16)
                .fontColor([this.currentColorMode === 1 ? '#6B6B6B' : '#AAAAAA'])
            }
            .width(30)
            .height(30)
            .borderRadius(15)
            .backgroundColor('#00000000')
            .onClick(() => {
              this.shareAIContent()
            })
          }
          .width('100%')
          .padding({ left: 56, top: 2, right: 16 })
        }

        if (this.showTime) {
          Row() {
            Text(formatTimestamp(this.message.timestamp))
              .fontSize(10)
              .fontColor($r('app.color.text_secondary'))
            if (this.message.model.length > 0) {
              Text(' · ' + this.message.model)
                .fontSize(10)
                .fontColor($r('app.color.text_secondary'))
            }
          }
          .width('100%')
          .padding({ left: 56 })
        }
      }
    }
    .width('100%')
  }

  private copyAIContent(): void {
    try {
      // 纯文本提取（剥离 markdown 符号 **、#、` 等）
      const plainText = markdownParser.tokensToPlainText(markdownParser.parse(this.message.content))
      const data = pasteboard.createPlainTextData(plainText)
      pasteboard.getSystemPasteboard().setData(data)
      promptAction.showToast({ message: '已复制到剪贴板', duration: 1500 })
    } catch (e) {
      promptAction.showToast({ message: '复制失败', duration: 1500 })
    }
  }

  private async shareAIContent(): Promise<void> {
    // 构建临时 Conversation 用于导出（含 AIGC 隐式标识）
    const tempConv: Conversation = {
      id: this.message.id,
      title: this.message.content.substring(0, 30),
      messages: [this.message],
      createdAt: this.message.timestamp,
      updatedAt: this.message.timestamp,
      model: this.message.model,
      systemPrompt: '',
      temperature: 0.8,
      maxTokens: 393216,
      topP: 1.0,
      deepThinking: false
    }
    await shareConversation(getContext(this) as common.UIAbilityContext, tempConv)
  }
}
