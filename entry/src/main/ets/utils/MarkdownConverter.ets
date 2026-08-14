/**
 * MarkdownConverter — 对话 ↔ Markdown 互转
 *
 * MD 格式包含识别标记 <!-- whalechat-conversation -->，
 * 导入时通过此标记判断是否为鲸语导出的对话文件。
 */
import { Conversation } from '../models/Conversation'
import { Message, MessageRole } from '../models/Message'

// 文件识别标记
const WHALECHAT_MARKER = '<!-- whalechat-conversation -->'
// AIGC 元数据分隔符（.txt 格式）
const META_DELIMITER = '================================================================'

// 角色显示名
function getRoleLabel(role: string): string {
  if (role === 'user') return '**User:**'
  if (role === 'assistant') return '**Assistant:**'
  if (role === 'system') return '**System:**'
  return `**${role}:**`
}

/**
 * 将对话转换为 Markdown 字符串
 */
export function conversationToMarkdown(conv: Conversation): string {
  const lines: string[] = []

  // 识别标记（放在开头以便解析时快速判断）
  lines.push(WHALECHAT_MARKER)

  // 标题
  lines.push(`# ${conv.title}`)
  lines.push('')

  // 元数据
  lines.push(`> id: ${conv.id}`)
  lines.push(`> model: ${conv.model}`)
  lines.push(`> createdAt: ${new Date(conv.createdAt).toISOString()}`)
  lines.push(`> updatedAt: ${new Date(conv.updatedAt).toISOString()}`)
  lines.push('')

  // 消息
  for (const msg of conv.messages) {
    lines.push('---')
    lines.push('')
    const label = getRoleLabel(msg.role)
    lines.push(label)
    lines.push('')
    lines.push(msg.content)
    lines.push('')

    // 深度思考内容
    if (msg.thinkingContent) {
      lines.push('<details>')
      lines.push('<summary>思考过程</summary>')
      lines.push('')
      lines.push(msg.thinkingContent)
      lines.push('')
      lines.push('</details>')
      lines.push('')
    }
  }

  return lines.join('\n')
}

/**
 * 从 Markdown 字符串解析为 Conversation
 * 如果不是鲸语格式，返回 null
 */
export function markdownToConversation(md: string): Conversation | null {
  // 预处理：跳过旧 .txt 格式的 AIGC-META 元数据块（向后兼容）
  let content = md
  if (content.includes('AIGC-META')) {
    const lastDelimIdx = content.lastIndexOf(META_DELIMITER)
    if (lastDelimIdx >= 0) {
      content = content.substring(lastDelimIdx + 64)
      content = content.trimStart()
    }
  }

  // 预处理：跳过合规导出的显式声明行
  const declPrefix = '【AI生成内容声明】'
  if (content.startsWith(declPrefix)) {
    const firstNewline = content.indexOf('\n')
    if (firstNewline >= 0) {
      content = content.substring(firstNewline + 1)
    }
  }

  // 预处理：裁剪尾部显式声明和 JSON-LD 元数据块
  const tailDecl = '本文由AI辅助创作'
  const tailIdx = content.indexOf(tailDecl)
  if (tailIdx >= 0) {
    content = content.substring(0, tailIdx).trimEnd()
  }

  // 快速检查识别标记
  if (!content.includes(WHALECHAT_MARKER)) {
    return null
  }

  const lines = content.split('\n')

  // 解析元数据
  let id = ''
  let model = ''
  let createdAt = Date.now()
  let updatedAt = Date.now()

  for (const line of lines) {
    if (line.startsWith('> id: ')) {
      id = line.substring(6)
    } else if (line.startsWith('> model: ')) {
      model = line.substring(9)
    } else if (line.startsWith('> createdAt: ')) {
      createdAt = new Date(line.substring(13)).getTime() || Date.now()
    } else if (line.startsWith('> updatedAt: ')) {
      updatedAt = new Date(line.substring(14)).getTime() || Date.now()
    }
    // 遇到分隔符则停止元数据解析
    if (line.startsWith('---')) break
  }

  // 解析标题（# 开头且不包含元数据标记的行）
  let title = '导入的对话'
  for (const line of lines) {
    if (line.startsWith('# ') && !line.includes('<!--')) {
      title = line.substring(2).trim()
      break
    }
  }

  // 解析消息
  const messages: Message[] = []
  let currentRole: MessageRole = 'user'
  let currentContent: string[] = []
  let capturing = false

  for (const line of lines) {
    // 跳过元数据行
    if (line.startsWith('> ')) continue
    // 跳过标记行
    if (line.includes(WHALECHAT_MARKER)) continue

    // 检测角色标签
    if (line.startsWith('**User:**')) {
      if (capturing && currentContent.length > 0) {
        messages.push(makeMessage(currentRole, currentContent.join('\n').trim(), model))
        currentContent = []
      }
      currentRole = 'user'
      capturing = true
      continue
    }
    if (line.startsWith('**Assistant:**')) {
      if (capturing && currentContent.length > 0) {
        messages.push(makeMessage(currentRole, currentContent.join('\n').trim(), model))
        currentContent = []
      }
      currentRole = 'assistant'
      capturing = true
      continue
    }
    if (line.startsWith('**System:**')) {
      if (capturing && currentContent.length > 0) {
        messages.push(makeMessage(currentRole, currentContent.join('\n').trim(), model))
        currentContent = []
      }
      currentRole = 'system'
      capturing = true
      continue
    }

    // 跳过空行和分隔线（在非捕获状态下）
    if (!capturing) continue
    if (line.trim() === '---' || line.trim() === '') continue

    // 跳过 <details> 块（思考过程不需要导入）
    if (line.trim() === '<details>' || line.trim() === '</details>') continue
    if (line.trim() === '<summary>思考过程</summary>') continue

    currentContent.push(line)
  }

  // 最后一段内容
  if (capturing && currentContent.length > 0) {
    messages.push(makeMessage(currentRole, currentContent.join('\n').trim(), model))
  }

  // 去除末尾空消息
  const filtered = messages.filter(m => m.content.trim().length > 0)

  return {
    id: id || generateImportId(),
    title: title,
    messages: filtered,
    createdAt: createdAt,
    updatedAt: updatedAt,
    model: model || 'unknown',
    systemPrompt: '',
    temperature: 0.8,
    maxTokens: 393216,
    topP: 1.0,
    deepThinking: false
  }
}

/**
 * 批量解析 MD 文本 — 支持多个 <!-- whalechat-conversation --> 标记
 */
export function batchParseMarkdown(md: string): Conversation[] {
  const results: Conversation[] = []
  const parts = md.split(WHALECHAT_MARKER)
  for (const part of parts) {
    const conv = markdownToConversation(WHALECHAT_MARKER + part)
    if (conv && conv.messages.length > 0) {
      results.push(conv)
    }
  }
  return results
}

// ── 内部辅助 ──

function generateImportId(): string {
  return `import_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`
}

function makeMessage(role: MessageRole, content: string, model: string): Message {
  return {
    id: generateImportId(),
    role: role,
    content: content,
    thinkingContent: '',
    showThinking: false,
    timestamp: Date.now(),
    isStreaming: false,
    model: model
  }
}
