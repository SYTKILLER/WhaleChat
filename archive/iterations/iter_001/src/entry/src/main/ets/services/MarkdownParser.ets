/**
 * Markdown 解析器 — 纯 ArkTS 实现
 *
 * 将 Markdown 文本解析为结构化 Token 列表，
 * 由 MarkdownView 组件负责渲染。
 */

/** Token 类型 */
export enum MarkdownTokenType {
  HEADING = 'heading',
  PARAGRAPH = 'paragraph',
  CODE_BLOCK = 'code_block',
  INLINE_CODE = 'inline_code',
  BOLD = 'bold',
  ITALIC = 'italic',
  LIST_ITEM = 'list_item',
  ORDERED_LIST_ITEM = 'ordered_list_item',
  BLOCKQUOTE = 'blockquote',
  HORIZONTAL_RULE = 'horizontal_rule',
  TEXT = 'text',
  LINE_BREAK = 'line_break'
}

/** 内联内容节点 */
export interface InlineNode {
  type: MarkdownTokenType
  text: string
  /** 代码块语言 */
  language?: string
}

/** Markdown 块级 Token */
export interface MarkdownToken {
  type: MarkdownTokenType
  /** 标题级别 (1-6) */
  level?: number
  /** 内联内容（标题、段落等） */
  children: InlineNode[]
  /** 代码块语言 */
  language?: string
  /** 代码块内容 */
  code?: string
  /** 列表项序号 */
  order?: number
}

/**
 * Markdown 解析器
 */
export class MarkdownParser {
  /**
   * 解析 Markdown 文本为 Token 列表
   */
  parse(markdown: string): MarkdownToken[] {
    const tokens: MarkdownToken[] = []
    const lines = markdown.split('\n')
    let i = 0

    while (i < lines.length) {
      const line = lines[i]

      // 空行
      if (line.trim() === '') {
        i++
        continue
      }

      // 代码块 ``` ... ```
      if (line.trim().startsWith('```')) {
        const language = line.trim().substring(3).trim()
        const codeLines: string[] = []
        i++
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.push(lines[i])
          i++
        }
        const prevCodeBlock = tokens.length > 0 ? tokens[tokens.length - 1] : null
        if (prevCodeBlock && prevCodeBlock.type === MarkdownTokenType.CODE_BLOCK) {
          // 当前代码块追加到上一个（两个代码块相邻合并）
          prevCodeBlock.code = (prevCodeBlock.code ?? '') + '\n' + codeLines.join('\n')
        } else {
          tokens.push({
            type: MarkdownTokenType.CODE_BLOCK,
            language: language || undefined,
            code: codeLines.join('\n'),
            children: []
          })
        }
        i++ // 跳过结束 ```
        continue
      }

      // 水平线 ---, ***, ___
      const trimmed = line.trim()
      if (/^(-{3,}|\*{3,}|_{3,})$/.test(trimmed)) {
        tokens.push({
          type: MarkdownTokenType.HORIZONTAL_RULE,
          children: []
        })
        i++
        continue
      }

      // 标题 # - ######
      const headingMatch = line.match(/^(#{1,6})\s+(.+)$/)
      if (headingMatch) {
        const level = headingMatch[1].length
        const text = headingMatch[2]
        tokens.push({
          type: MarkdownTokenType.HEADING,
          level,
          children: this.parseInline(text)
        })
        i++
        continue
      }

      // 无序列表 - or *
      const ulMatch = line.match(/^(\s*)[-*]\s+(.+)$/)
      if (ulMatch) {
        tokens.push({
          type: MarkdownTokenType.LIST_ITEM,
          children: this.parseInline(ulMatch[2])
        })
        i++
        continue
      }

      // 有序列表 1. 2. ...
      const olMatch = line.match(/^(\s*)(\d+)\.\s+(.+)$/)
      if (olMatch) {
        tokens.push({
          type: MarkdownTokenType.ORDERED_LIST_ITEM,
          order: parseInt(olMatch[2]),
          children: this.parseInline(olMatch[3])
        })
        i++
        continue
      }

      // 引用 >
      if (line.trim().startsWith('>')) {
        const quoteLines: string[] = []
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          quoteLines.push(lines[i].trim().substring(1).trim())
          i++
        }
        tokens.push({
          type: MarkdownTokenType.BLOCKQUOTE,
          children: this.parseInline(quoteLines.join('\n'))
        })
        continue
      }

      // 普通段落 — 收集连续的非空行
      const paraLines: string[] = []
      while (i < lines.length &&
        lines[i].trim() !== '' &&
        !lines[i].trim().startsWith('```') &&
        !lines[i].trim().startsWith('>') &&
        !lines[i].match(/^(#{1,6})\s+/) &&
        !lines[i].match(/^(\s*)[-*]\s+/) &&
        !lines[i].match(/^(\s*)(\d+)\.\s+/) &&
        !/^(-{3,}|\*{3,}|_{3,})$/.test(lines[i].trim())) {
        paraLines.push(lines[i])
        i++
      }
      if (paraLines.length > 0) {
        tokens.push({
          type: MarkdownTokenType.PARAGRAPH,
          children: this.parseInline(paraLines.join('\n'))
        })
      }
    }

    return tokens
  }

  /**
   * 解析内联文本（加粗、斜体、行内代码等）
   */
  private parseInline(text: string): InlineNode[] {
    const nodes: InlineNode[] = []
    let remaining = text

    while (remaining.length > 0) {
      // 行内代码 `...`
      const codeMatch = remaining.match(/`([^`]+)`/)
      // 加粗 **...**
      const boldMatch = remaining.match(/\*\*(.+?)\*\*/)
      // 斜体 *...*（但不匹配 **）
      const italicMatch = remaining.match(/(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)/)

      // 找到最早出现的匹配
      let earliest: { type: MarkdownTokenType; text: string; full: string; index: number } | null = null

      if (codeMatch && codeMatch.index !== undefined) {
        earliest = {
          type: MarkdownTokenType.INLINE_CODE,
          text: codeMatch[1],
          full: codeMatch[0],
          index: codeMatch.index
        }
      }

      if (boldMatch && boldMatch.index !== undefined &&
        (earliest === null || boldMatch.index < earliest.index)) {
        earliest = {
          type: MarkdownTokenType.BOLD,
          text: boldMatch[1],
          full: boldMatch[0],
          index: boldMatch.index
        }
      }

      if (italicMatch && italicMatch.index !== undefined &&
        (earliest === null || italicMatch.index < earliest.index)) {
        earliest = {
          type: MarkdownTokenType.ITALIC,
          text: italicMatch[1],
          full: italicMatch[0],
          index: italicMatch.index
        }
      }

      if (earliest !== null) {
        // 添加匹配前的纯文本
        if (earliest.index > 0) {
          const before = remaining.substring(0, earliest.index)
          // 递归解析前面的文本（处理嵌套）
          const subNodes = this.parsePlainText(before)
          nodes.push(...subNodes)
        }
        nodes.push({
          type: earliest.type,
          text: earliest.text
        })
        remaining = remaining.substring(earliest.index + earliest.full.length)
      } else {
        // 没有匹配，剩余都是纯文本
        const subNodes = this.parsePlainText(remaining)
        nodes.push(...subNodes)
        break
      }
    }

    return nodes
  }

  /**
   * 解析纯文本（处理换行符）
   */
  private parsePlainText(text: string): InlineNode[] {
    if (!text) return []

    const nodes: InlineNode[] = []
    const parts = text.split('\n')

    for (let i = 0; i < parts.length; i++) {
      if (parts[i].length > 0) {
        nodes.push({
          type: MarkdownTokenType.TEXT,
          text: parts[i]
        })
      }
      if (i < parts.length - 1) {
        nodes.push({
          type: MarkdownTokenType.LINE_BREAK,
          text: ''
        })
      }
    }

    return nodes
  }
}

/** 全局单例 */
export const markdownParser = new MarkdownParser()
