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
  LINE_BREAK = 'line_break',
  TABLE = 'table'
}

/** 内联匹配结果 */
interface InlineMatch {
  type: MarkdownTokenType
  text: string
  full: string
  index: number
}

/** 内联内容节点 */
export interface InlineNode {
  type: MarkdownTokenType
  text: string
  language: string
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
  /** 表格：列数 */
  colCount?: number
  /** 表格：表头单元格 (每格为 InlineNode[]) */
  headers?: InlineNode[][]
  /** 表格：数据行 (rows[row][col] = InlineNode[]) */
  rows?: InlineNode[][][]
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

      // 表格: | ... | 后跟分隔行 |---...|
      if (line.trim().startsWith('|') && i + 1 < lines.length && this.isTableSeparator(lines[i + 1])) {
        const headerCells = this.parseTableRow(line)
        const colCount = headerCells.length
        const rows: InlineNode[][][] = []
        i += 2 // 跳过表头和分隔行
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          const rowCells = this.parseTableRow(lines[i])
          if (rowCells.length === colCount) {
            rows.push(rowCells)
          }
          i++
        }
        tokens.push({
          type: MarkdownTokenType.TABLE,
          headers: headerCells,
          rows: rows,
          colCount: colCount,
          children: []
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
      let earliest: InlineMatch | null = null

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
          for (let si = 0; si < subNodes.length; si++) {
            nodes.push(subNodes[si])
          }
        }
        nodes.push({
          type: earliest.type,
          text: earliest.text,
          language: ''
        })
        remaining = remaining.substring(earliest.index + earliest.full.length)
      } else {
        // 没有匹配，剩余都是纯文本
        const subNodes = this.parsePlainText(remaining)
        for (let si = 0; si < subNodes.length; si++) {
          nodes.push(subNodes[si])
        }
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
          text: parts[i],
          language: ''
        })
      }
      if (i < parts.length - 1) {
        nodes.push({
          type: MarkdownTokenType.LINE_BREAK,
          text: '',
          language: ''
        })
      }
    }

    return nodes
  }

  /**
   * 判断是否为表格分隔行: |---|---| 或 |:---|:---:|---:|
   */
  private isTableSeparator(line: string): boolean {
    const trimmed = line.trim()
    if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) return false
    const cells = trimmed.split('|').filter(s => s.length > 0)
    if (cells.length === 0) return false
    return cells.every(s => /^:?-{3,}:?$/.test(s.trim()))
  }

  /**
   * 解析表格行：拆分单元格并解析内联 Markdown
   */
  private parseTableRow(line: string): InlineNode[][] {
    const trimmed = line.trim()
    // 去掉首尾的 | 再按 | 分割
    let content = trimmed
    if (content.startsWith('|')) content = content.substring(1)
    if (content.endsWith('|')) content = content.substring(0, content.length - 1)
    return content.split('|').map(cell => this.parseInline(cell.trim()))
  }

  /**
   * 从 Token 列表提取纯文本（剥离所有 markdown 符号）
   */
  tokensToPlainText(tokens: MarkdownToken[]): string {
    const parts: string[] = []
    for (const token of tokens) {
      if (token.type === MarkdownTokenType.CODE_BLOCK) {
        parts.push(token.code ?? '')
      } else if (token.type === MarkdownTokenType.TABLE) {
        // 表格：表头 + 数据行，用制表符/换行拼接
        const rows: string[] = []
        if (token.headers) {
          const headerParts: string[] = []
          for (const cells of token.headers) {
            headerParts.push(this.inlineToText(cells))
          }
          rows.push(headerParts.join('\t'))
        }
        if (token.rows) {
          for (const row of token.rows) {
            const rowParts: string[] = []
            for (const cells of row) {
              rowParts.push(this.inlineToText(cells))
            }
            rows.push(rowParts.join('\t'))
          }
        }
        parts.push(rows.join('\n'))
      } else {
        parts.push(this.inlineToText(token.children))
      }
    }
    return parts.join('\n')
  }

  /**
   * 将内联节点列表提取为纯文本
   */
  private inlineToText(nodes: InlineNode[]): string {
    let result = ''
    for (const node of nodes) {
      if (node.type === MarkdownTokenType.LINE_BREAK) {
        result += '\n'
      } else {
        result += node.text
      }
    }
    return result
  }
}

/** 全局单例 */
export const markdownParser = new MarkdownParser()
