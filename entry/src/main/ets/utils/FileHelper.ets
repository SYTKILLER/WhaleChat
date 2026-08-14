/**
 * FileHelper — 沙箱文件操作工具
 *
 * 提供 MD 文件的创建、读取、删除及 URI 获取，
 * 用于分享导出和导入流程。
 */
import { fileIo as fs } from '@kit.CoreFileKit'
import { fileUri } from '@kit.CoreFileKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'

const DOMAIN = 0x0004
const TAG = 'FileHelper'

/**
 * 在应用沙箱中创建 MD 文件并写入内容
 * @returns 文件 URI（用于分享或持久化）
 */
export async function createMdFile(context: common.Context, fileName: string, content: string): Promise<string> {
  try {
    const safeName = sanitizeFileName(fileName)
    const path = `${context.filesDir}/${safeName}.md`
    const file: fs.File = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE)
    fs.writeSync(file.fd, content)
    fs.closeSync(file)
    hilog.info(DOMAIN, TAG, `MD file created: ${path}`)
    return fileUri.getUriFromPath(path)
  } catch (err) {
    hilog.error(DOMAIN, TAG, `createMdFile failed: ${err}`)
    return ''
  }
}

/**
 * 从 URI 读取文件内容
 */
export async function readFileFromUri(context: common.Context, uri: string): Promise<string> {
  try {
    const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY)
    const stat: fs.Stat = fs.statSync(file.fd)
    const bufLen: number = stat.size
    const buffer = new ArrayBuffer(bufLen)
    fs.readSync(file.fd, buffer)
    fs.closeSync(file)

    const decoder = new util.TextDecoder('utf-8')
    const content = decoder.decode(new Uint8Array(buffer))
    return content
  } catch (err) {
    hilog.error(DOMAIN, TAG, `readFileFromUri failed: ${err}`)
    return ''
  }
}

/**
 * 删除沙箱文件（通过路径）
 */
export function deleteFile(pathOrUri: string): void {
  try {
    // 尝试删除（如果是 file:// URI，先转路径）
    if (pathOrUri.startsWith('file://')) {
      const path = pathOrUri.substring(7) // 去除 file:// 前缀
      fs.unlinkSync(path)
    } else {
      fs.unlinkSync(pathOrUri)
    }
  } catch (err) {
    hilog.warn(DOMAIN, TAG, `deleteFile failed: ${err}`)
  }
}

/**
 * 清理文件名中的非法字符
 */
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
