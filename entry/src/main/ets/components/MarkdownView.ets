/**
 * MarkdownView 组件 — 将解析后的 Markdown Token 渲染为 ArkUI 组件
 */

import { MarkdownToken, MarkdownTokenType, InlineNode } from '../services/MarkdownParser'
import { pasteboard } from '@kit.BasicServicesKit'
import { promptAction } from '@kit.ArkUI'

@Component
export struct MarkdownView {
  @Prop tokens: MarkdownToken[] = []
  @StorageLink('currentColorMode') currentColorMode: number = 1

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
          } else if (token.type === MarkdownTokenType.TABLE) {
            this.TableBlock(token)
          }
        }
        .constraintSize({ maxWidth: '100%' })
        .padding({ top: 4, bottom: 4 })
      })
    }
    .constraintSize({ maxWidth: '100%' })
  }

  @Builder
  HeadingBlock(token: MarkdownToken) {
    Text() {
      this.InlineChildren(token.children)
    }
    .fontSize(token.level === 1 ? 22 : token.level === 2 ? 19 : token.level === 3 ? 17 : 15)
    .fontWeight(FontWeight.Bold)
    .wordBreak(WordBreak.BREAK_WORD)
    .padding({ top: 6, bottom: 2 })
    .constraintSize({ maxWidth: '100%' })
  }

  @Builder
  ParagraphBlock(token: MarkdownToken) {
    Text() {
      this.InlineChildren(token.children)
    }
    .fontSize(15)
    .lineHeight(22)
    .wordBreak(WordBreak.BREAK_WORD)
    .constraintSize({ maxWidth: '100%' })
  }

  @Builder
  CodeBlockView(token: MarkdownToken) {
    Column() {
      // 头部：语言标签 + 复制按钮
      Row() {
        if (token.language) {
          Text(token.language)
            .fontSize(11)
            .fontColor('#AAAAAA')
        }
        Blank()
        Button() {
          SymbolGlyph($r('sys.symbol.plus_square_on_square'))
            .fontSize(14)
            .fontColor([this.currentColorMode === 1 ? '#AAAAAA' : '#AAAAAA'])
        }
          .width(28)
          .height(28)
          .backgroundColor('#00000000')
          .borderRadius(4)
          .onClick(() => {
            this.copyCode(token.code ?? '')
          })
      }
      .width('100%')
      .padding({ left: 12, right: 8, top: 6 })

      // 代码块用横向滚动防止长行溢出
      Scroll() {
        Text(token.code ?? '')
          .fontSize(13)
          .fontFamily('monospace')
          .fontColor('#D4D4D4')
          .padding({ left: 12, right: 12, top: 4, bottom: 12 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Auto)
    }
    .backgroundColor('#1E1E1E')
    .borderRadius(8)
    .constraintSize({ maxWidth: '100%' })
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
      .wordBreak(WordBreak.BREAK_WORD)
      .layoutWeight(1)
    }
    .constraintSize({ maxWidth: '100%' })
    .padding({ left: 8 })
  }

  @Builder
  OrderedListItemBlock(token: MarkdownToken) {
    Row() {
      Text((token.order ?? 1).toString() + '.')
        .fontSize(15)
        .width(24)
        .textAlign(TextAlign.Center)
      Text() {
        this.InlineChildren(token.children)
      }
      .fontSize(15)
      .lineHeight(22)
      .wordBreak(WordBreak.BREAK_WORD)
      .layoutWeight(1)
    }
    .constraintSize({ maxWidth: '100%' })
    .padding({ left: 8 })
  }

  @Builder
  BlockquoteBlock(token: MarkdownToken) {
    Row() {
      Column()
        .width(3)
        .backgroundColor($r('app.color.divider_color'))
        .borderRadius(2)
        .alignSelf(ItemAlign.Stretch)

      Text() {
        this.InlineChildren(token.children)
      }
      .fontSize(14)
      .fontColor($r('app.color.text_subtle'))
      .fontStyle(FontStyle.Italic)
      .wordBreak(WordBreak.BREAK_WORD)
      .layoutWeight(1)
      .padding({ left: 8 })
    }
    .constraintSize({ maxWidth: '100%' })
    .padding(8)
    .backgroundColor($r('app.color.bg_input'))
    .borderRadius(4)
  }

  @Builder
  HorizontalRuleView() {
    Divider()
      .width('100%')
      .height(1)
      .color($r('app.color.divider_color'))
      .margin({ top: 8, bottom: 8 })
  }

  @Builder
  TableBlock(token: MarkdownToken) {
    Scroll() {
      Column() {
        // 表头行
        if (token.headers) {
          Row() {
            ForEach(token.headers, (cell: InlineNode[], colIdx: number) => {
              this.TableHeaderCell(cell)
            }, (cell: InlineNode[], colIdx: number) => colIdx.toString())
          }
          .backgroundColor(this.currentColorMode === 1 ? '#F5F5F5' : '#2A2A2A')
          .borderRadius({ topLeft: 5, topRight: 5 })
        }

        // 数据行
        if (token.rows) {
          ForEach(token.rows, (row: InlineNode[][], rowIdx: number) => {
            Row() {
              ForEach(row, (cell: InlineNode[], colIdx: number) => {
                Text() {
                  this.InlineChildren(cell)
                }
                .fontSize(13)
                .fontColor(this.currentColorMode === 1 ? '#333333' : '#CCCCCC')
                .padding({ left: 8, right: 8, top: 5, bottom: 5 })
                .layoutWeight(1)
              }, (cell: InlineNode[], colIdx: number) => colIdx.toString())
            }
            .backgroundColor(rowIdx % 2 === 0 ?
              (this.currentColorMode === 1 ? '#FFFFFF' : '#1E1E1E') :
              (this.currentColorMode === 1 ? '#FAFAFA' : '#222222'))
          }, (row: InlineNode[][], rowIdx: number) => rowIdx.toString())
        }
      }
      .border({ width: 1, color: this.currentColorMode === 1 ? '#E0E0E0' : '#444444' })
      .borderRadius(6)
      .clip(true)
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Auto)
    .margin({ top: 6, bottom: 6 })
    .constraintSize({ maxWidth: '100%' })
  }

  @Builder
  TableHeaderCell(cell: InlineNode[]) {
    Text() {
      this.InlineChildren(cell)
    }
    .fontSize(13)
    .fontWeight(FontWeight.Bold)
    .fontColor(this.currentColorMode === 1 ? '#222222' : '#E0E0E0')
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .layoutWeight(1)
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
          .backgroundColor($r('app.color.bg_bubble_ai'))
          .borderRadius(3)
          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
      } else if (node.type === MarkdownTokenType.LINE_BREAK) {
        Span('\n')
      }
    })
  }

  private copyCode(code: string): void {
    try {
      const plainText = pasteboard.createPlainTextData(code)
      pasteboard.getSystemPasteboard().setData(plainText)
      promptAction.showToast({ message: '已复制到剪贴板', duration: 1500 })
    } catch (e) {
      promptAction.showToast({ message: '复制失败', duration: 1500 })
    }
  }
}
