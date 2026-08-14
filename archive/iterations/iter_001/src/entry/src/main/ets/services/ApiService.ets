/**
 * API 服务 — 封装 OpenAI 兼容的 HTTP/SSE 流式请求
 *
 * 支持 DeepSeek、OpenAI 及任何 OpenAI 兼容 API。
 * 使用 @kit.NetworkKit 的 http 模块实现流式请求。
 */

import { http } from '@kit.NetworkKit'
import { ApiConfig, getEffectiveBaseUrl, getEffectiveModel } from '../models/ApiConfig'
import { Message } from '../models/Message'
import { Memory, formatMemoriesAsPrompt } from '../models/Memory'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0002
const TAG = 'ApiService'

/** 系统提示词 */
const SYSTEM_PROMPT = `你是一个智能AI助手，运行在鸿蒙(HarmonyOS)平台上的DeepChat应用中。
请用简洁清晰的语言回答用户问题。当用户询问代码时，请使用Markdown代码块并提供详细解释。
你可以处理各种任务，包括但不限于：回答问题、编写代码、翻译、总结、创作内容等。`

/** 流式响应回调接口 */
export interface StreamCallbacks {
  /** 接收到增量内容 */
  onChunk: (content: string) => void
  /** 请求完成 */
  onDone: (fullContent: string) => void
  /** 发生错误 */
  onError: (error: string) => void
}

class ApiService {
  /**
   * 发送非流式聊天请求
   */
  async chat(
    config: ApiConfig,
    messages: Message[],
    memories: Memory[],
    onChunk: (content: string) => void,
    onDone: (fullContent: string) => void,
    onError: (error: string) => void
  ): Promise<void> {
    // 构建请求体
    const requestBody = this.buildRequestBody(config, messages, memories, false)
    const baseUrl = getEffectiveBaseUrl(config)
    const url = `${baseUrl}/v1/chat/completions`

    try {
      const httpRequest = http.createHttp()
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${config.apiKey}`,
          'User-Agent': 'DeepChat-HarmonyOS/1.0'
        },
        extraData: JSON.stringify(requestBody),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 120000
      })

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string)
        const content = result.choices?.[0]?.message?.content ?? ''
        if (content) {
          onChunk(content)
        }
        onDone(content)
      } else {
        const errMsg = this.parseErrorResponse(response.result as string)
        onError(`请求失败 (${response.responseCode}): ${errMsg}`)
      }
      httpRequest.destroy()
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Chat request failed: %{public}s', JSON.stringify(err))
      onError(`网络请求失败: ${JSON.stringify(err)}`)
    }
  }

  /**
   * 发送流式聊天请求 (SSE)
   *
   * 使用 http.requestInStream 实现边收边解析。
   */
  async chatStream(
    config: ApiConfig,
    messages: Message[],
    memories: Memory[],
    callbacks: StreamCallbacks
  ): Promise<void> {
    const requestBody = this.buildRequestBody(config, messages, memories, true)
    const baseUrl = getEffectiveBaseUrl(config)
    const url = `${baseUrl}/v1/chat/completions`

    let fullContent = ''
    let sseBuffer = ''

    try {
      const httpRequest = http.createHttp()

      // 使用流式请求
      const streamHandle = httpRequest.requestInStream(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${config.apiKey}`,
          'Accept': 'text/event-stream',
          'User-Agent': 'DeepChat-HarmonyOS/1.0'
        },
        extraData: JSON.stringify(requestBody),
        connectTimeout: 30000,
        readTimeout: 300000
      })

      // 监听数据接收
      streamHandle.on('dataReceive', (data: ArrayBuffer) => {
        try {
          const decoder = new TextDecoder()
          const text = decoder.decode(data)
          sseBuffer += text

          // 解析 SSE 行
          const lines = sseBuffer.split('\n')
          // 保留最后一个不完整的行
          sseBuffer = lines.pop() ?? ''

          for (const line of lines) {
            const trimmed = line.trim()
            if (trimmed.startsWith('data: ')) {
              const data = trimmed.substring(6)
              if (data === '[DONE]') {
                // 流结束
                callbacks.onDone(fullContent)
                return
              }
              try {
                const parsed = JSON.parse(data)
                const delta = parsed.choices?.[0]?.delta?.content ?? ''
                if (delta) {
                  fullContent += delta
                  callbacks.onChunk(delta)
                }
              } catch (parseErr) {
                // 忽略 JSON 解析错误，可能是部分数据
                hilog.warn(DOMAIN, TAG, 'SSE parse warning: %{public}s', data.substring(0, 50))
              }
            } else if (trimmed.startsWith('data:')) {
              // 兼容 "data:" 格式
              const data = trimmed.substring(5).trim()
              if (data === '[DONE]') {
                callbacks.onDone(fullContent)
                return
              }
              try {
                const parsed = JSON.parse(data)
                const delta = parsed.choices?.[0]?.delta?.content ?? ''
                if (delta) {
                  fullContent += delta
                  callbacks.onChunk(delta)
                }
              } catch (parseErr) {
                // ignore
              }
            }
          }
        } catch (err) {
          hilog.error(DOMAIN, TAG, 'SSE dataReceive error: %{public}s', JSON.stringify(err))
        }
      })

      // 监听流结束
      streamHandle.on('dataEnd', () => {
        // 处理缓冲区剩余数据
        if (sseBuffer.trim().length > 0) {
          const trimmed = sseBuffer.trim()
          if (trimmed.startsWith('data: ')) {
            const data = trimmed.substring(6)
            if (data !== '[DONE]') {
              try {
                const parsed = JSON.parse(data)
                const delta = parsed.choices?.[0]?.delta?.content ?? ''
                if (delta) {
                  fullContent += delta
                  callbacks.onChunk(delta)
                }
              } catch (e) { /* ignore */ }
            }
          }
        }
        callbacks.onDone(fullContent)
      })

      // 监听错误
      streamHandle.on('dataError', (err) => {
        hilog.error(DOMAIN, TAG, 'Stream error: %{public}s', JSON.stringify(err))
        if (fullContent.length > 0) {
          // 如果已经有部分内容，当作完成
          callbacks.onDone(fullContent)
        } else {
          callbacks.onError(`流式请求出错: ${JSON.stringify(err)}`)
        }
        httpRequest.destroy()
      })

    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Stream request failed: %{public}s', JSON.stringify(err))
      if (fullContent.length > 0) {
        callbacks.onDone(fullContent)
      } else {
        callbacks.onError(`流式请求失败: ${JSON.stringify(err)}`)
      }
    }
  }

  /**
   * 构建请求体
   */
  private buildRequestBody(
    config: ApiConfig,
    messages: Message[],
    memories: Memory[],
    stream: boolean
  ): object {
    // 构建系统消息
    let systemContent = SYSTEM_PROMPT

    // 注入永久记忆
    const memoriesPrompt = formatMemoriesAsPrompt(memories)
    if (memoriesPrompt) {
      systemContent += memoriesPrompt
    }

    // 构建消息数组
    const apiMessages: Array<{ role: string; content: string }> = [
      { role: 'system', content: systemContent }
    ]

    // 添加对话消息
    for (const msg of messages) {
      apiMessages.push({
        role: msg.role,
        content: msg.content
      })
    }

    const model = getEffectiveModel(config)

    return {
      model: model,
      messages: apiMessages,
      stream: stream,
      temperature: config.temperature,
      max_tokens: config.maxTokens,
      top_p: config.topP
    }
  }

  /**
   * 解析错误响应
   */
  private parseErrorResponse(response: string): string {
    try {
      const parsed = JSON.parse(response)
      return parsed.error?.message ?? parsed.message ?? '未知错误'
    } catch (err) {
      // 截取前 200 个字符作为错误信息
      return response.length > 200 ? response.substring(0, 200) + '…' : response
    }
  }

  /**
   * 测试 API 连接
   */
  async testConnection(config: ApiConfig): Promise<{ success: boolean; message: string }> {
    const baseUrl = getEffectiveBaseUrl(config)
    const url = `${baseUrl}/v1/models`

    try {
      const httpRequest = http.createHttp()
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Authorization': `Bearer ${config.apiKey}`,
          'User-Agent': 'DeepChat-HarmonyOS/1.0'
        },
        connectTimeout: 15000,
        readTimeout: 15000
      })

      httpRequest.destroy()

      if (response.responseCode === 200) {
        return { success: true, message: '连接成功' }
      } else if (response.responseCode === 401) {
        return { success: false, message: 'API Key 无效，请检查' }
      } else {
        return { success: false, message: `请求失败 (${response.responseCode})` }
      }
    } catch (err) {
      return { success: false, message: `连接失败: ${JSON.stringify(err)}` }
    }
  }
}

/** 全局单例 */
export const apiService = new ApiService()
