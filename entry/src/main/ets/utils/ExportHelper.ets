/**
 * ExportHelper — 统一导出服务（GB/T AIGC-2024 合规）
 *
 * 生成符合国家标准的导出文件，包含：
 * 1. 显式标识：头部 AI 生成声明 + 尾部辅助创作声明
 * 2. 隐式标识 — 零宽水印：附录 E JSON 编码为不可见字符
 * 3. 隐式标识 — JSON-LD 元数据：schema.org 标准词汇 + C2PA
 */
import { Conversation } from '../models/Conversation'
import { conversationToMarkdown } from './MarkdownConverter'
import { encodeToZeroWidth } from './ZeroWidthEncoder'
import { systemShare } from '@kit.ShareKit'
import { picker } from '@kit.CoreFileKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { fileUri } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { deleteFile } from './FileHelper'

const DOMAIN = 0x0009
const TAG = 'ExportHelper'

// ── 常量 ──

const HEADER_EXPLICIT = '【AI生成内容声明】本内容由人工智能模型生成，模型信息可查阅文件末尾元数据。'
const FOOTER_EXPLICIT = '\n\n本文由AI辅助创作，仅供参考。'

// ── AIGC 元数据 ──

interface AigcPayload {
  AIGC: AigcFields
}

interface AigcFields {
  Label: string
  ContentProducer: string
  ProduceID: string
  ReservedCode1: string
  ContentPropagator: string
  PropagateID: string
  ReservedCode2: string
}

function buildAigcPayload(conv: Conversation): string {
  const payload: AigcPayload = {
    AIGC: {
      Label: '1',
      ContentProducer: '鲸语(com.whalechat.app)',
      ProduceID: conv.id,
      ReservedCode1: '',
      ContentPropagator: '鲸语(com.whalechat.app)',
      PropagateID: conv.id,
      ReservedCode2: ''
    }
  }
  return JSON.stringify(payload)
}

// ── JSON-LD 元数据 ──

interface JsonLdGenerator {
  '@type': string
  'name': string
  'applicationCategory': string
}

interface JsonLdMeta {
  '@context': string
  '@type': string
  'ai:generatedBy': JsonLdGenerator
  'ai:isAIGenerated': boolean
  'dateCreated': string
  'creativeWorkStatus': string
  'aigc:label': string
  'aigc:produceID': string
  'standard': string
  'c2pa': boolean
}

function buildJsonLd(conv: Conversation): string {
  const generator: JsonLdGenerator = {
    '@type': 'SoftwareApplication',
    'name': '鲸语(com.whalechat.app)',
    'applicationCategory': 'Artificial Intelligence'
  }
  const meta: JsonLdMeta = {
    '@context': 'https://schema.org',
    '@type': 'CreativeWork',
    'ai:generatedBy': generator,
    'ai:isAIGenerated': true,
    'dateCreated': new Date(conv.createdAt).toISOString(),
    'creativeWorkStatus': 'AI-Generated',
    'aigc:label': '1',
    'aigc:produceID': conv.id,
    'standard': 'GB/T AIGC-2024',
    'c2pa': true
  }
  return '\n\n<!-- JSON-LD Metadata\n' + JSON.stringify(meta, null, 2) + '\n-->'
}

// ── 核心构建 ──

/**
 * 构建完整的合规导出文本内容
 */
export function buildExportContent(conv: Conversation): string {
  const aigcJson = buildAigcPayload(conv)
  const watermark = encodeToZeroWidth(aigcJson)

  // 第 1 行：显式声明 + 零宽水印
  const header = HEADER_EXPLICIT + watermark

  // 正文：whalechat 格式
  const body = conversationToMarkdown(conv)

  // 尾部：显式声明 + JSON-LD 元数据
  const footer = FOOTER_EXPLICIT + buildJsonLd(conv)

  return header + '\n\n' + body + footer
}

// ── 工具函数 ──

function sanitizeFileName(name: string): string {
  let result = ''
  for (let i = 0; i < name.length && i < 100; i++) {
    const ch = name[i]
    if (ch === '<' || ch === '>' || ch === ':' || ch === '"' ||
      ch === '/' || ch === '\\' || ch === '|' || ch === '?' || ch === '*') {
      result += '_'
    } else if (ch === ' ' || ch === '\t') {
      result += '_'
    } else {
      result += ch
    }
  }
  return result
}

// ── 导出接口 ──

/**
 * 分享单条对话：构建 .txt → 写沙箱临时文件 → 系统分享面板
 */
export async function shareConversation(ctx: common.UIAbilityContext, conv: Conversation): Promise<void> {
  try {
    const content = buildExportContent(conv)
    const safeName = sanitizeFileName(conv.title)
    const path = ctx.filesDir + '/鲸语_' + safeName + '.txt'
    const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE)
    fs.writeSync(file.fd, content)
    fs.closeSync(file)

    const uri = fileUri.getUriFromPath(path)
    const shareData = new systemShare.SharedData({
      utd: 'general.plain-text',
      uri: uri
    })
    const controller = new systemShare.ShareController(shareData)
    controller.show(ctx, { selectionMode: systemShare.SelectionMode.BATCH })

    setTimeout(() => deleteFile(uri), 5000)
  } catch (err) {
    hilog.error(DOMAIN, TAG, 'shareConversation failed: %{public}s', JSON.stringify(err))
  }
}

// ── 侧车 JSON 数据结构 ──

interface SidecarConversation {
  id: string
  title: string
  exportedAt: string
}

interface SidecarCompliance {
  standard: string
  c2pa: boolean
}

interface Sidecar {
  version: string
  generator: string
  timestamp: string
  contentType: string
  markingTypes: string[]
  conversations: SidecarConversation[]
  compliance: SidecarCompliance
}

/**
 * 保存对话到用户指定位置：弹出文件选择器 → 写入 .txt + 侧车 JSON
 */
export async function saveConversations(ctx: common.UIAbilityContext, convs: Conversation[]): Promise<void> {
  try {
    // 1. 生成所有 .txt 内容
    const parts: string[] = []
    const metaList: SidecarConversation[] = []
    for (let i = 0; i < convs.length; i++) {
      parts.push(buildExportContent(convs[i]))
      const entry: SidecarConversation = {
        id: convs[i].id,
        title: convs[i].title,
        exportedAt: new Date().toISOString()
      }
      metaList.push(entry)
    }
    const content = parts.join('\n\n---\n\n')

    // 2. 生成侧车 JSON
    const sidecar: Sidecar = {
      version: '1.0',
      generator: '鲸语(com.whalechat.app)',
      timestamp: new Date().toISOString(),
      contentType: 'text/plain',
      markingTypes: ['explicit', 'implicit'],
      conversations: metaList,
      compliance: {
        standard: 'GB/T AIGC-2024',
        c2pa: true
      }
    }
    const sidecarJson = JSON.stringify(sidecar, null, 2)

    // 3. 保存 .txt
    const documentPicker = new picker.DocumentViewPicker()
    const saveOptions = new picker.DocumentSaveOptions()
    saveOptions.newFileNames = ['鲸语对话导出.txt']
    const saveResult = await documentPicker.save(saveOptions)

    if (saveResult.length > 0) {
      const file = fs.openSync(saveResult[0], fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE)
      fs.writeSync(file.fd, content)
      fs.closeSync(file)

      // 4. 保存侧车 .json（与 .txt 同目录）
      const txtPath = saveResult[0]
      const jsonPath = txtPath.replace('.txt', '_metadata.json')
      try {
        const jsonFile = fs.openSync(jsonPath, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE)
        fs.writeSync(jsonFile.fd, sidecarJson)
        fs.closeSync(jsonFile)
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'Sidecar JSON write failed (non-fatal): %{public}s', JSON.stringify(e))
      }

      hilog.info(DOMAIN, TAG, 'Exported %{public}d conversations with sidecar', convs.length)
    }
  } catch (err) {
    hilog.error(DOMAIN, TAG, 'saveConversations failed: %{public}s', JSON.stringify(err))
  }
}
