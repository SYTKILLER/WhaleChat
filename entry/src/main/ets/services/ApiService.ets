/**
 * API 服务 — 封装 OpenAI 兼容的 HTTP/SSE 流式请求
 *
 * 支持 DeepSeek、OpenAI 及任何 OpenAI 兼容 API。
 */

import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { ApiConfig, getEffectiveModel, getChatCompletionsUrl, getModelsUrl, ManagedApiConfig } from '../models/ApiConfig'
import { Message } from '../models/Message'
import { Memory, formatMemoriesAsPrompt } from '../models/Memory'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0002
const TAG = 'ApiService'

/** 系统提示词 */
const SYSTEM_PROMPT = '你是一个智能AI助手，运行在鸿蒙(HarmonyOS)平台上的WhaleChat应用中。请用简洁清晰的语言回答用户问题。当用户询问代码时，请使用Markdown代码块并提供详细解释。'

/** 流式响应回调接口 */
export interface StreamCallbacks {
  onChunk: (content: string) => void
  onThinkingChunk: (thinking: string) => void
  onDone: (fullContent: string, thinkingContent: string) => void
  onError: (error: string) => void
}

/** 聊天完成结果 */
export interface ChatResult {
  content: string
  thinkingContent: string
}

/** API 消息格式 */
interface ApiMessage {
  role: string
  content: string
  /** 思考内容（仅 assistant 角色带回） */
  reasoning_content?: string
}

/** 思考配置 */
interface ThinkingConfig {
  type: string
}

/** 请求体格式 */
interface ChatRequestBody {
  model: string
  messages: ApiMessage[]
  stream: boolean
  temperature?: number
  top_p?: number
  max_tokens?: number
  /** 思考模式开关 */
  thinking?: ThinkingConfig
  /** 思考强度 */
  reasoning_effort?: string
}

/** 连接测试结果 */
export interface ConnectionResult {
  success: boolean
  message: string
}

/** 余额查询结果 */
export interface BalanceResult {
  isAvailable: boolean
  totalBalance: string
  currency: string
  grantedBalance: string
  toppedUpBalance: string
}

/** API 使用统计 */
export interface UsageStats {
  /** 累计请求次数 */
  requestCount: number
  /** 累计失败次数 */
  failedCount: number
  /** 最近一次请求的输入 token 数 */
  lastPromptTokens: number
  /** 最近一次请求的输出 token 数 */
  lastCompletionTokens: number
  /** 累计总 token 消耗 */
  totalTokens: number
}

/** OpenAI 兼容聊天响应的显式结构（替代 Record<string, Object> 括号访问） */
interface ChatApiMessage {
  role?: string
  content?: string
  reasoning_content?: string
}

interface ChatApiDelta {
  content?: string
  reasoning_content?: string
}

interface ChatChoice {
  message?: ChatApiMessage
  delta?: ChatApiDelta
}

interface ChatUsage {
  prompt_tokens?: number
  completion_tokens?: number
  total_tokens?: number
}

interface ApiErrorBody {
  message?: string
}

interface ChatResponse {
  choices?: ChatChoice[]
  usage?: ChatUsage
  error?: ApiErrorBody
  message?: string
}

interface BalanceInfo {
  total_balance?: string
  currency?: string
  granted_balance?: string
  topped_up_balance?: string
}

interface BalanceResponse {
  is_available?: boolean
  balance_infos?: BalanceInfo[]
}

class ApiService {
  private stats: UsageStats = {
    requestCount: 0,
    failedCount: 0,
    lastPromptTokens: 0,
    lastCompletionTokens: 0,
    totalTokens: 0
  }

  /** 获取当前使用统计 */
  getStats(): UsageStats {
    return this.stats
  }

  /** 重置统计 */
  resetStats(): void {
    this.stats = {
      requestCount: 0,
      failedCount: 0,
      lastPromptTokens: 0,
      lastCompletionTokens: 0,
      totalTokens: 0
    }
  }

  /**
   * 发送非流式聊天请求
   */
  async chat(
    config: ApiConfig,
    messages: Message[],
    memories: Memory[],
    deepThinking: boolean,
    customPrompt: string,
    onChunk: (content: string) => void,
    onDone: (result: ChatResult) => void,
    onError: (error: string) => void
  ): Promise<void> {
    const requestBody: ChatRequestBody = this.buildRequestBody(config, messages, memories, false, deepThinking, customPrompt)
    const url: string = getChatCompletionsUrl(config)

    try {
      const httpRequest = http.createHttp()
      const bodyStr: string = JSON.stringify(requestBody)
      hilog.info(DOMAIN, TAG, 'Chat POST url: %{public}s', url)
      hilog.info(DOMAIN, TAG, 'Chat body length: %{public}d, key length: %{public}d',
        bodyStr.length, config.apiKey.length)
      // 输出 body 前 200 字符用于调试
      hilog.info(DOMAIN, TAG, 'Chat body preview: %{public}s',
        bodyStr.length > 200 ? bodyStr.substring(0, 200) + '...' : bodyStr)

      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + config.apiKey,
          'User-Agent': 'WhaleChat-HarmonyOS/1.0'
        },
        extraData: bodyStr,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 120000
      })

      hilog.info(DOMAIN, TAG, 'Chat response code: %{public}d, resultType: %{public}s',
        response.responseCode, typeof response.result)

      if (response.responseCode === 200) {
        const resultStr: string = (response.result as string) ?? '{}'
        const result = JSON.parse(resultStr) as ChatResponse
        const choices: ChatChoice[] = result.choices ?? []
        const extracted: ChatResult = this.extractContent(choices)
        if (extracted.content.length > 0) {
          onChunk(extracted.content)
        }
        onDone(extracted)
      } else {
        const rawBody: string = this.responseToString(response.result)
        const errMsg: string = this.parseErrorResponse(rawBody)
        onError('请求失败 (' + response.responseCode.toString() + '): ' + errMsg)
      }
      httpRequest.destroy()
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Chat request failed: %{public}s', JSON.stringify(err))
      onError('网络请求失败: ' + JSON.stringify(err))
    }
  }

  /**
   * 发送流式聊天请求 (SSE)
   *
   * ⚠️ 关键：必须先注册事件再调用 requestInStream，否则数据事件全部丢失。
   */
  async chatStream(
    config: ApiConfig,
    messages: Message[],
    memories: Memory[],
    deepThinking: boolean,
    customPrompt: string,
    callbacks: StreamCallbacks
  ): Promise<void> {
    const requestBody: ChatRequestBody = this.buildRequestBody(config, messages, memories, true, deepThinking, customPrompt)
    const url: string = getChatCompletionsUrl(config)

    this.stats.requestCount++

    let fullContent: string = ''
    let fullThinking: string = ''
    let sseBuffer: string = ''
    let isFinished: boolean = false

    const httpRequest = http.createHttp()

    // ═══ 1. 先注册事件监听 ═══

    httpRequest.on('headerReceive', (header: Object) => {
      hilog.info(DOMAIN, TAG, 'Stream header received')
    })

    httpRequest.on('dataReceive', (data: ArrayBuffer) => {
      if (isFinished) return
      clearTimeout(timeoutId)
      try {
        const uint8 = new Uint8Array(data)
        const textDecoder = util.TextDecoder.create('utf-8', { fatal: false })
        const text: string = textDecoder.decodeToString(uint8, { stream: true })
        sseBuffer += text

        // 按行分割 SSE
        const lines: string[] = sseBuffer.split('\n')
        sseBuffer = lines.pop() ?? ''

        for (let li = 0; li < lines.length; li++) {
          const trimmed: string = lines[li].trim()
          if (trimmed.length === 0) continue

          if (trimmed.startsWith('data:')) {
            const jsonStr: string = trimmed.substring(5).trim()
            if (jsonStr === '[DONE]') {
              isFinished = true
              callbacks.onDone(fullContent, fullThinking)
              httpRequest.destroy()
              return
            }
            try {
              const parsed = JSON.parse(jsonStr) as ChatResponse
              // 累加 token 使用量（DeepSeek 在 SSE 最后一个消息中返回 usage）
              const usage = parsed.usage
              if (usage != undefined) {
                this.stats.lastPromptTokens = usage.prompt_tokens ?? 0
                this.stats.lastCompletionTokens = usage.completion_tokens ?? 0
                const total: number = usage.total_tokens ?? 0
                this.stats.totalTokens += total
              }
              const choices: ChatChoice[] = parsed.choices ?? []
              const delta: ChatResult = this.extractDeltaContent(choices)
              if (delta.thinkingContent.length > 0) {
                fullThinking += delta.thinkingContent
                callbacks.onThinkingChunk(delta.thinkingContent)
              }
              if (delta.content.length > 0) {
                fullContent += delta.content
                callbacks.onChunk(delta.content)
              }
            } catch (parseErr) {
              // JSON 不完整时静默跳过，等待更多数据（仅 debug 级可追踪日志）
              hilog.debug(DOMAIN, TAG, 'Incomplete SSE json, waiting for more data')
            }
          }
        }
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'dataReceive error: %{public}s', JSON.stringify(err))
      }
    })

    httpRequest.on('dataEnd', () => {
      if (isFinished) return
      isFinished = true
      clearTimeout(timeoutId)
      // 处理剩余缓冲区
      if (sseBuffer.trim().length > 0) {
        const trimmed: string = sseBuffer.trim()
        if (trimmed.startsWith('data:')) {
          const jsonStr: string = trimmed.substring(5).trim()
          if (jsonStr !== '[DONE]') {
            try {
              const parsed = JSON.parse(jsonStr) as ChatResponse
              const choices: ChatChoice[] = parsed.choices ?? []
              const delta: ChatResult = this.extractDeltaContent(choices)
              if (delta.thinkingContent.length > 0) {
                fullThinking += delta.thinkingContent
              }
              if (delta.content.length > 0) {
                fullContent += delta.content
              }
            } catch (e) {
              hilog.debug(DOMAIN, TAG, 'Incomplete SSE tail json, ignore')
            }
          }
        }
      }
      callbacks.onDone(fullContent, fullThinking)
      httpRequest.destroy()
    })

    // ═══ 2. 再发起请求（事件驱动，不 await 避免错失事件）═══

    // 30 秒整体超时兜底
    const timeoutId: number = setTimeout(() => {
      if (!isFinished) {
        isFinished = true
        hilog.error(DOMAIN, TAG, 'Stream timeout after 30s, url: %{public}s', url)
        this.stats.failedCount++
        callbacks.onError('请求超时，请检查网络和 API 配置')
        httpRequest.destroy()
      }
    }, 30000)

    try {
      const streamPromise = httpRequest.requestInStream(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + config.apiKey,
          'Accept': 'text/event-stream',
          'User-Agent': 'WhaleChat-HarmonyOS/1.0'
        },
        extraData: JSON.stringify(requestBody),
        connectTimeout: 30000,
        readTimeout: 300000
      })
      // 捕获异步错误（如 DNS 解析失败、连接被拒）
      streamPromise.catch((err: Object) => {
        if (!isFinished) {
          isFinished = true
          clearTimeout(timeoutId)
          hilog.error(DOMAIN, TAG, 'requestInStream rejected: %{public}s', JSON.stringify(err))
          this.stats.failedCount++
          callbacks.onError('连接失败: ' + JSON.stringify(err))
          httpRequest.destroy()
        }
      })
    } catch (err) {
      if (!isFinished) {
        isFinished = true
        clearTimeout(timeoutId)
        this.stats.failedCount++
        callbacks.onError('发起请求失败: ' + JSON.stringify(err))
        httpRequest.destroy()
      }
    }
  }

  /**
   * 提取非流式响应中的 content
   */
  private extractContent(choices: ChatChoice[]): ChatResult {
    if (choices.length === 0) return { content: '', thinkingContent: '' }
    const firstChoice = choices[0]
    const message = firstChoice.message
    if (message == undefined) return { content: '', thinkingContent: '' }
    const content = message.content ?? ''
    const thinkingContent = message.reasoning_content ?? ''
    return { content: content, thinkingContent: thinkingContent }
  }

  /**
   * 提取流式响应中的 delta content
   */
  private extractDeltaContent(choices: ChatChoice[]): ChatResult {
    if (choices.length === 0) return { content: '', thinkingContent: '' }
    const firstChoice = choices[0]
    const delta = firstChoice.delta
    if (delta == undefined) return { content: '', thinkingContent: '' }
    const content = delta.content ?? ''
    const thinkingContent = delta.reasoning_content ?? ''
    return { content: content, thinkingContent: thinkingContent }
  }

  /**
   * 构建请求体
   */
  private buildRequestBody(
    config: ApiConfig,
    messages: Message[],
    memories: Memory[],
    stream: boolean,
    deepThinking: boolean = false,
    customPrompt: string = ''
  ): ChatRequestBody {
    let systemContent: string = customPrompt.length > 0 ? customPrompt : SYSTEM_PROMPT

    const memoriesPrompt: string = formatMemoriesAsPrompt(memories)
    if (memoriesPrompt.length > 0) {
      systemContent += memoriesPrompt
    }

    const apiMessages: ApiMessage[] = [
      { role: 'system', content: systemContent }
    ]

    for (let i = 0; i < messages.length; i++) {
      const msg: Message = messages[i]
      const apiMsg: ApiMessage = {
        role: msg.role,
        content: msg.content
      }
      // 多轮对话时，将 assistant 的思考内容带回
      if (msg.role === 'assistant' && msg.thinkingContent.length > 0) {
        apiMsg.reasoning_content = msg.thinkingContent
      }
      apiMessages.push(apiMsg)
    }

    const model: string = getEffectiveModel(config)

    const body: ChatRequestBody = {
      model: model,
      messages: apiMessages,
      stream: stream
    }

    if (deepThinking) {
      // 思考模式：开启 thinking，不发送 temperature/top_p（不生效）
      body.thinking = { type: 'enabled' }
      body.reasoning_effort = 'high'
    } else {
      // 普通模式：显式关闭思考（API 默认为 enabled），发送温度和采样参数
      body.thinking = { type: 'disabled' }
      body.temperature = config.temperature
      body.top_p = config.topP
      body.max_tokens = config.maxTokens
    }

    return body
  }

  /**
   * 安全提取 HTTP 响应体为字符串
   */
  private responseToString(result: string | Object | ArrayBuffer): string {
    if (typeof result === 'string') {
      return result
    }
    if (result instanceof ArrayBuffer) {
      const decoder = util.TextDecoder.create('utf-8')
      return decoder.decodeToString(new Uint8Array(result))
    }
    return JSON.stringify(result ?? '')
  }

  /**
   * 解析错误响应
   */
  private parseErrorResponse(response: string): string {
    try {
      const parsed = JSON.parse(response) as ChatResponse
      const error = parsed.error
      if (error != undefined) {
        const message = error.message
        if (message != undefined && message.length > 0) {
          return message
        }
      }
      const msg = parsed.message
      if (msg != undefined && msg.length > 0) {
        return msg
      }
      return '未知错误'
    } catch (err) {
      if (response.length > 200) {
        return response.substring(0, 200) + '…'
      }
      return response
    }
  }

  /**
   * 测试 API 连接
   * 先尝试 GET models 端点，若不支持则降级到 POST chat 端点空消息测试
   */
  async testConnection(config: ApiConfig): Promise<ConnectionResult> {
    const modelsUrl: string = getModelsUrl(config)

    // 方案 A：GET models 端点（带 15s 整体超时）
    const modelsResult = await this.withTimeout(
      this.tryGet(modelsUrl, config.apiKey),
      15000,
      '连接超时，请检查 API 地址是否正确'
    )
    if (modelsResult.success) {
      return modelsResult
    }
    // 如果 models 端点返回 404/405/超时，降级到 chat 端点
    if (modelsResult.message.includes('404') || modelsResult.message.includes('405') ||
        modelsResult.message.includes('超时') || modelsResult.message.includes('失败')) {
      return await this.withTimeout(
        this.tryChatTest(config),
        15000,
        '连接超时，请检查 API 地址是否正确'
      )
    }

    return modelsResult
  }

  /**
   * 查询账户余额（DeepSeek 专属）
   *
   * GET {baseUrl}/user/balance
   */
  async checkBalance(config: ManagedApiConfig): Promise<BalanceResult> {
    const base: string = config.baseUrl.trim().replace(/\/+$/, '')
    const url: string = base + '/user/balance'

    hilog.info(DOMAIN, TAG, 'checkBalance url: %{public}s', url)

    const httpRequest = http.createHttp()
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ' + config.apiKey
        },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 10000
      })
      httpRequest.destroy()

      if (response.responseCode === 200) {
        const raw: string = this.responseToString(response.result)
        hilog.info(DOMAIN, TAG, 'checkBalance response: %{public}s', raw)
        const parsed = JSON.parse(raw) as BalanceResponse
        const isAvailable: boolean = parsed.is_available ?? false
        const balanceInfos = parsed.balance_infos
        if (balanceInfos && balanceInfos.length > 0) {
          const info = balanceInfos[0]
          const totalBalance: string = info.total_balance ?? '0.00'
          const currency: string = info.currency ?? 'CNY'
          const grantedBalance: string = info.granted_balance ?? '0.00'
          const toppedUpBalance: string = info.topped_up_balance ?? '0.00'
          return {
            isAvailable: isAvailable,
            totalBalance: totalBalance,
            currency: currency,
            grantedBalance: grantedBalance,
            toppedUpBalance: toppedUpBalance
          }
        }
        return {
          isAvailable: isAvailable,
          totalBalance: '0.00',
          currency: 'CNY',
          grantedBalance: '0.00',
          toppedUpBalance: '0.00'
        }
      } else {
        hilog.error(DOMAIN, TAG, 'checkBalance failed: %{public}d', response.responseCode)
        return {
          isAvailable: false,
          totalBalance: '--',
          currency: '',
          grantedBalance: '',
          toppedUpBalance: ''
        }
      }
    } catch (err) {
      httpRequest.destroy()
      hilog.error(DOMAIN, TAG, 'checkBalance error: %{public}s', JSON.stringify(err))
      return {
        isAvailable: false,
        totalBalance: '--',
        currency: '',
        grantedBalance: '',
        toppedUpBalance: ''
      }
    }
  }

  /**
   * Promise 超时包装
   */
  private withTimeout(promise: Promise<ConnectionResult>, timeoutMs: number, timeoutMsg: string): Promise<ConnectionResult> {
    return new Promise<ConnectionResult>((resolve) => {
      const timer = setTimeout(() => {
        resolve({ success: false, message: timeoutMsg })
      }, timeoutMs)

      promise.then((result: ConnectionResult) => {
        clearTimeout(timer)
        resolve(result)
      }).catch((err: Object) => {
        clearTimeout(timer)
        resolve({ success: false, message: '连接失败: ' + JSON.stringify(err) })
      })
    })
  }

  /**
   * 尝试 GET 请求
   */
  private async tryGet(url: string, apiKey: string): Promise<ConnectionResult> {
    const httpRequest = http.createHttp()
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Authorization': 'Bearer ' + apiKey
        },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 10000
      })
      httpRequest.destroy()

      if (response.responseCode === 200) {
        return { success: true, message: '连接成功' }
      } else if (response.responseCode === 401) {
        return { success: false, message: 'API Key 无效，请检查' }
      } else {
        const rawBody: string = this.responseToString(response.result)
        const errBody: string = this.parseErrorResponse(rawBody)
        return { success: false, message: errBody }
      }
    } catch (err) {
      httpRequest.destroy()
      const errStr: string = JSON.stringify(err)
      if (errStr.includes('2300028') || errStr.includes('timeout')) {
        return { success: false, message: '连接超时，请检查 API 地址是否正确' }
      }
      return { success: false, message: '连接失败: ' + errStr }
    }
  }

  /**
   * 降级测试：用最小 chat 请求验证 API Key + URL 是否可用
   */
  private async tryChatTest(config: ApiConfig): Promise<ConnectionResult> {
    const chatUrl: string = getChatCompletionsUrl(config)
    const testMsg: ApiMessage = { role: 'user', content: 'hi' }
    const messagesArr: ApiMessage[] = [testMsg]
    const body: ChatRequestBody = {
      model: getEffectiveModel(config),
      messages: messagesArr,
      stream: false
    }

    const httpRequest = http.createHttp()
    try {
      const response = await httpRequest.request(chatUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + config.apiKey
        },
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 10000
      })
      httpRequest.destroy()

      if (response.responseCode === 200) {
        return { success: true, message: '连接成功' }
      } else if (response.responseCode === 401) {
        return { success: false, message: 'API Key 无效，请检查' }
      } else {
        const rawBody: string = this.responseToString(response.result)
        const errBody: string = this.parseErrorResponse(rawBody)
        return { success: false, message: errBody }
      }
    } catch (err) {
      httpRequest.destroy()
      return { success: false, message: '连接失败: ' + JSON.stringify(err) }
    }
  }
}

/** 全局单例 */
export const apiService = new ApiService()
