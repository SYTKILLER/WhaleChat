/**
 * ChatBubble 组件 — 单条消息气泡
 */

import { Message } from '../models/Message'
import { MarkdownView } from './MarkdownView'
import { markdownParser } from '../services/MarkdownParser'
import { formatTime } from '../common/Utils'

@Component
export struct ChatBubble {
  @Prop message: Message
  @State showTime: boolean = false

  build() {
    Column() {
      // 用户消息
      if (this.message.role === 'user') {
        Row() {
          Blank()
          Column() {
            Text(this.message.content)
              .fontSize(15)
              .padding(12)
              .borderRadius({
                topLeft: 16,
                topRight: 4,
                bottomLeft: 16,
                bottomRight: 16
              })
              .backgroundColor('#4A90D9')
              .fontColor(Color.White)
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
          Text(formatTime(this.message.timestamp))
            .fontSize(10)
            .fontColor('#999999')
            .textAlign(TextAlign.End)
            .width('100%')
            .padding({ right: 16 })
        }
      }

      // AI 消息
      if (this.message.role === 'assistant') {
        Row() {
          // 头像
          Column() {
            Text('AI')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor('#999999')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          // 消息内容（支持 Markdown）
          Column() {
            if (this.message.content) {
              MarkdownView({
                tokens: markdownParser.parse(this.message.content)
              })
            } else if (this.message.isStreaming) {
              // 流式输出中但还没有内容
              Text('思考中…')
                .fontSize(14)
                .fontColor('#999999')
                .fontStyle(FontStyle.Italic)
            }
          }
          .padding(12)
          .borderRadius({
            topLeft: 4,
            topRight: 16,
            bottomLeft: 16,
            bottomRight: 16
          })
          .backgroundColor('#F0F0F0')
          .constraintSize({ maxWidth: '80%' })

          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 4 })
        .alignItems(VerticalAlign.Top)
        .onClick(() => {
          this.showTime = !this.showTime
        })

        if (this.showTime) {
          Row() {
            Text(formatTime(this.message.timestamp))
              .fontSize(10)
              .fontColor('#999999')
            if (this.message.model) {
              Text(` · ${this.message.model}`)
                .fontSize(10)
                .fontColor('#999999')
            }
          }
          .width('100%')
          .padding({ left: 56 })
        }
      }
    }
    .width('100%')
  }
}
