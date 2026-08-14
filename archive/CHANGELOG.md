# 迭代更新记录

---

## Iteration 001 — 基础框架搭建

**日期**: 2026-06-20  
**代号**: Foundation

### 新增

| 模块 | 内容 |
|------|------|
| 项目结构 | models/ services/ components/ common/ 目录 |
| 数据模型 | ApiConfig, Message, Conversation, Memory |
| 加密存储 | StorageService (AES-256-GCM + Base64 降级) |
| API 客户端 | ApiService (HTTP 非流式 + SSE 流式，兼容 OpenAI 格式) |
| Markdown | MarkdownParser (纯 ArkTS，9 种块级 + 3 种内联格式) |
| 组件 | ChatBubble, MarkdownView, MessageInput, ModelSelector |
| 页面 | Index, ApiConfigPage, MainPage, ChatPage, ConversationListPage, SettingsPage |
| 导航 | 底部 Tab (对话列表 + 设置) |
| 主题 | 跟随系统明/暗模式 |
| 永久记忆 | Memory 模型 + SettingsPage 管理面板 |

### 路由

```
Index → ApiConfigPage (首次) → MainPage
                                   ├─ Tab1: ConversationListPage → ChatPage
                                   └─ Tab2: SettingsPage
```

### 已知待完成 (Phase 2)

- MD 导入/导出
- 华为云备份同步
- 华为分享 / 光效 UI
- HUKS 硬件级密钥存储

### 文件清单

```
entry/src/main/ets/common/Constants.ets
entry/src/main/ets/common/Utils.ets
entry/src/main/ets/models/ApiConfig.ets
entry/src/main/ets/models/Message.ets
entry/src/main/ets/models/Conversation.ets
entry/src/main/ets/models/Memory.ets
entry/src/main/ets/services/StorageService.ets
entry/src/main/ets/services/ApiService.ets
entry/src/main/ets/services/MarkdownParser.ets
entry/src/main/ets/components/ChatBubble.ets
entry/src/main/ets/components/MarkdownView.ets
entry/src/main/ets/components/MessageInput.ets
entry/src/main/ets/components/ModelSelector.ets
entry/src/main/ets/pages/Index.ets
entry/src/main/ets/pages/ApiConfigPage.ets
entry/src/main/ets/pages/MainPage.ets
entry/src/main/ets/pages/ChatPage.ets
entry/src/main/ets/pages/ConversationListPage.ets
entry/src/main/ets/pages/SettingsPage.ets
```
