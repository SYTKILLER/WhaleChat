/**
 * MarkdownView 组件 — 将解析后的 Markdown Token 渲染为 ArkUI 组件
 */

import { MarkdownToken, MarkdownTokenType, InlineNode } from '../services/MarkdownParser'

@Component
export struct MarkdownView {
  @Prop tokens: MarkdownToken[] = []

  build() {
    Column() {
      ForEach(this.tokens, (token: MarkdownToken, index: number) => {
        Column() {
          if (token.type === MarkdownTokenType.HEADING) {
            this.HeadingBlock(token)
          } else if (token.type === MarkdownTokenType.PARAGRAPH) {
            this.ParagraphBlock(token)
          } else if (token.type === MarkdownTokenType.CODE_BLOCK) {
            this.CodeBlockView(token)
          } else if (token.type === MarkdownTokenType.LIST_ITEM) {
            this.ListItemBlock(token)
          } else if (token.type === MarkdownTokenType.ORDERED_LIST_ITEM) {
            this.OrderedListItemBlock(token)
          } else if (token.type === MarkdownTokenType.BLOCKQUOTE) {
            this.BlockquoteBlock(token)
          } else if (token.type === MarkdownTokenType.HORIZONTAL_RULE) {
            this.HorizontalRuleView()
          }
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })
      })
    }
    .width('100%')
  }

  @Builder
  HeadingBlock(token: MarkdownToken) {
    Text() {
      this.InlineChildren(token.children)
    }
    .fontSize(token.level === 1 ? 22 : token.level === 2 ? 19 : token.level === 3 ? 17 : 15)
    .fontWeight(FontWeight.Bold)
    .padding({ top: 6, bottom: 2 })
    .width('100%')
  }

  @Builder
  ParagraphBlock(token: MarkdownToken) {
    Text() {
      this.InlineChildren(token.children)
    }
    .fontSize(15)
    .lineHeight(22)
    .width('100%')
  }

  @Builder
  CodeBlockView(token: MarkdownToken) {
    Column() {
      if (token.language) {
        Text(token.language)
          .fontSize(11)
          .fontColor('#888')
          .padding({ left: 12, top: 6, bottom: 2 })
      }
      Text(token.code ?? '')
        .fontSize(13)
        .fontFamily('monospace')
        .padding(12)
        .width('100%')
    }
    .backgroundColor('#1E1E1E')
    .borderRadius(8)
    .width('100%')
    .margin({ top: 4, bottom: 4 })
  }

  @Builder
  ListItemBlock(token: MarkdownToken) {
    Row() {
      Text('•')
        .fontSize(15)
        .width(20)
        .textAlign(TextAlign.Center)
      Text() {
        this.InlineChildren(token.children)
      }
      .fontSize(15)
      .lineHeight(22)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 8 })
  }

  @Builder
  OrderedListItemBlock(token: MarkdownToken) {
    Row() {
      Text(`${token.order ?? 1}.`)
        .fontSize(15)
        .width(24)
        .textAlign(TextAlign.Center)
      Text() {
        this.InlineChildren(token.children)
      }
      .fontSize(15)
      .lineHeight(22)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 8 })
  }

  @Builder
  BlockquoteBlock(token: MarkdownToken) {
    Row() {
      // 左侧竖线
      Column()
        .width(3)
        .height('100%')
        .backgroundColor('#CCCCCC')
        .borderRadius(2)

      Text() {
        this.InlineChildren(token.children)
      }
      .fontSize(14)
      .fontColor('#999999')
      .fontStyle(FontStyle.Italic)
      .layoutWeight(1)
      .padding({ left: 8 })
    }
    .width('100%')
    .padding(8)
    .backgroundColor('#F5F5F5')
    .borderRadius(4)
  }

  @Builder
  HorizontalRuleView() {
    Divider()
      .width('100%')
      .height(1)
      .color('#DDDDDD')
      .margin({ top: 8, bottom: 8 })
  }

  /**
   * 渲染内联子节点
   */
  @Builder
  InlineChildren(children: InlineNode[]) {
    ForEach(children, (node: InlineNode, idx: number) => {
      if (node.type === MarkdownTokenType.TEXT) {
        Span(node.text)
      } else if (node.type === MarkdownTokenType.BOLD) {
        Span(node.text)
          .fontWeight(FontWeight.Bold)
      } else if (node.type === MarkdownTokenType.ITALIC) {
        Span(node.text)
          .fontStyle(FontStyle.Italic)
      } else if (node.type === MarkdownTokenType.INLINE_CODE) {
        Span(node.text)
          .fontFamily('monospace')
          .fontSize(13)
          .backgroundColor('#F0F0F0')
          .borderRadius(3)
          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
      } else if (node.type === MarkdownTokenType.LINE_BREAK) {
        Span('\n')
      }
    })
  }
}
