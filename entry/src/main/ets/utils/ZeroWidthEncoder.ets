/**
 * ZeroWidthEncoder — 零宽字符水印编解码
 *
 * 使用 Unicode 零宽字符将 AIGC 元数据隐写嵌入文本，
 * 人眼不可见，但可通过自动化工具检测。
 *
 * 编码规则：
 *   \u200B (ZERO WIDTH SPACE)    → 0
 *   \u200C (ZERO WIDTH NON-JOINER) → 1
 *   每 16 位组成一个 UTF-16 码元，对应 JSON 字符串的一个字符
 */

const ZW_0 = '\u200B' // bit 0
const ZW_1 = '\u200C' // bit 1

/**
 * 将字符串编码为零宽字符序列
 */
export function encodeToZeroWidth(text: string): string {
  let result = ''
  for (let i = 0; i < text.length; i++) {
    const charCode = text.charCodeAt(i)
    // 每个字符编码为 16 位（UTF-16）
    for (let bit = 15; bit >= 0; bit--) {
      if ((charCode >> bit) & 1) {
        result += ZW_1
      } else {
        result += ZW_0
      }
    }
  }
  return result
}

/**
 * 从零宽字符序列解码为字符串
 */
export function decodeFromZeroWidth(zwString: string): string {
  let result = ''
  let bits = 0
  let bitCount = 0

  for (let i = 0; i < zwString.length; i++) {
    const ch = zwString[i]
    if (ch === ZW_1) {
      bits = (bits << 1) | 1
      bitCount++
    } else if (ch === ZW_0) {
      bits = (bits << 1)
      bitCount++
    }

    if (bitCount === 16) {
      result += String.fromCharCode(bits)
      bits = 0
      bitCount = 0
    }
  }

  return result
}
