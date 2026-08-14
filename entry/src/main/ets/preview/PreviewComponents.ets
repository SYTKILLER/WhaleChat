/**
 * PreviewComponents — 组件级预览入口
 *
 * 为非 @Entry 组件提供独立的 Previewer 预览包装器。
 * 在 DevEco Studio 中打开此文件即可预览各组件。
 */

import { Message, createMessage } from '../models/Message'
import { ApiConfig, createDefaultApiConfig } from '../models/ApiConfig'
import { ChatBubble } from '../components/ChatBubble'
import { MarkdownView } from '../components/MarkdownView'
import { MessageInput } from '../components/MessageInput'
import { ModelSelector } from '../components/ModelSelector'
import { markdownParser } from '../services/MarkdownParser'

// ================================================================
// 示例数据
// ================================================================

const sampleUserMsg: Message = {
  id: 'preview_user_1',
  role: 'user',
  content: '你好，请用 TypeScript 写一个 Hello World 函数。',
  timestamp: Date.now()
}

const sampleAiMsg: Message = {
  id: 'preview_ai_1',
  role: 'assistant',
  content: `好的，这是一个 TypeScript 的 Hello World 函数：

\`\`\`typescript
function greet(name: string): string {
  return \`Hello, \${name}!\`
}

console.log(greet("World"))
// 输出: Hello, World!
\`\`\`

这个函数接收一个 **string** 类型的参数，返回拼接后的问候语。你也可以试试用 *箭头函数* 来写：

\`\`\`typescript
const greet = (name: string): string => \`Hello, \${name}!\`
\`\`\`

> TypeScript 是 JavaScript 的超集，添加了静态类型系统。`,
  timestamp: Date.now(),
  model: 'deepseek-v4-flash'
}

const sampleMarkdown = `# 一级标题
## 二级标题
### 三级标题

这是一段包含 **加粗** 和 *斜体* 以及 \`行内代码\` 的段落。

---

- 无序列表项 1
- 无序列表项 2
  - 嵌套项

1. 有序列表项
2. 第二个有序项

> 这是引用文本
> 可以多行

\`\`\`typescript
// 代码块
interface User {
  name: string
  age: number
}
\`\`\`

最后一段普通文本。`

const sampleConfig: ApiConfig = {
  ...createDefaultApiConfig(),
  providerId: 'deepseek',
  selectedModel: 'deepseek-v4-flash'
}

// ================================================================
// 聊天气泡 — 用户消息
// ================================================================

@Preview({ title: 'ChatBubble - 用户消息', width: 390, height: 200, colorMode: 'light' })
@Entry
@Component
struct PreviewChatBubbleUser {
  build() {
    Column() {
      ChatBubble({ message: sampleUserMsg })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
  }
}

// ================================================================
// 聊天气泡 — AI 消息（含 Markdown）
// ================================================================

@Preview({ title: 'ChatBubble - AI消息(Markdown)', width: 390, height: 500, colorMode: 'light' })
@Entry
@Component
struct PreviewChatBubbleAi {
  build() {
    Scroll() {
      ChatBubble({ message: sampleAiMsg })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}

// ================================================================
// 聊天气泡 — 流式输出中
// ================================================================

@Preview({ title: 'ChatBubble - 流式输出中', width: 390, height: 150, colorMode: 'light' })
@Entry
@Component
struct PreviewChatBubbleStreaming {
  build() {
    Column() {
      ChatBubble({
        message: {
          id: 'streaming_preview',
          role: 'assistant',
          content: '这是一段正在输出中的文本…',
          timestamp: Date.now(),
          isStreaming: true
        }
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
  }
}

// ================================================================
// Markdown 渲染
// ================================================================

@Preview({ title: 'MarkdownView - 全部样式', width: 390, height: 700, colorMode: 'light' })
@Preview({ title: 'MarkdownView - 深色', width: 390, height: 700, colorMode: 'dark' })
@Entry
@Component
struct PreviewMarkdownView {
  build() {
    Scroll() {
      MarkdownView({
        tokens: markdownParser.parse(sampleMarkdown)
      })
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
  }
}

// ================================================================
// 消息输入区域
// ================================================================

@Preview({ title: 'MessageInput - 空状态', width: 390, height: 80, colorMode: 'light' })
@Entry
@Component
struct PreviewMessageInputEmpty {
  build() {
    Column() {
      Blank()
      MessageInput({ disabled: false })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}

@Preview({ title: 'MessageInput - 禁用状态', width: 390, height: 80, colorMode: 'light' })
@Entry
@Component
struct PreviewMessageInputDisabled {
  build() {
    Column() {
      Blank()
      MessageInput({ disabled: true })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}

// ================================================================
// 模型选择器
// ================================================================

@Preview({ title: 'ModelSelector - 按钮', width: 390, height: 100, colorMode: 'light' })
@Entry
@Component
struct PreviewModelSelector {
  build() {
    Row() {
      ModelSelector({ config: sampleConfig })
    }
    .width('100%')
    .padding(16)
    .justifyContent(FlexAlign.End)
    .backgroundColor('#FFFFFF')
  }
}

// ================================================================
// 模型选择器 — 自定义平台
// ================================================================

@Preview({ title: 'ModelSelector - 自定义平台', width: 390, height: 100, colorMode: 'light' })
@Entry
@Component
struct PreviewModelSelectorCustom {
  build() {
    Row() {
      ModelSelector({
        config: {
          ...createDefaultApiConfig(),
          providerId: 'custom',
          customModel: 'my-custom-model'
        }
      })
    }
    .width('100%')
    .padding(16)
    .justifyContent(FlexAlign.End)
    .backgroundColor('#FFFFFF')
  }
}
