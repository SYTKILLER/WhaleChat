/**
 * FileHelper — 沙箱文件操作工具
 *
 * 提供 MD 文件的创建、读取、删除及 URI 获取，
 * 用于分享导出和导入流程。
 */
import { fileIo as fs } from '@kit.CoreFileKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'

const DOMAIN = 0x0004
const TAG = 'FileHelper'

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
    hilog.error(DOMAIN, TAG, 'readFileFromUri failed: %{public}s', JSON.stringify(err))
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
    hilog.warn(DOMAIN, TAG, 'deleteFile failed: %{public}s', JSON.stringify(err))
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
