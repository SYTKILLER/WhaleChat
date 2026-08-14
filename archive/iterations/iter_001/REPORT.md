# Iteration 001 — 基础框架

**日期**: 2026-06-20  
**代号**: Foundation  

## 完成内容

### 🏗️ 架构
- 4 层结构：models → services → components → pages
- 21 个源文件，0 外部依赖（纯 ArkTS 自实现 Markdown）

### 🔑 API 配置
- 3 步引导式配置：选择平台 → 输入密钥 → 选择模型
- 预设 DeepSeek (deepseek-chat, deepseek-reasoner)
- 预设 OpenAI (gpt-4o, gpt-4o-mini, gpt-4-turbo, o1, o1-mini)
- 支持自定义 endpoint + 模型
- API 连接测试功能

### 💬 核心对话
- SSE 流式输出，实时渲染
- Markdown 解析渲染（标题 / 加粗 / 斜体 / 代码块 / 列表 / 引用 / 水平线）
- 对话中切换模型 + 调节 Temperature
- 对话自动保存到本地存储

### 🔐 安全
- AES-256-GCM 加密 API Key 存储
- 加密失败自动降级到 Base64 编码
- Preferences 沙箱隔离

### 📱 页面
| 页面 | 功能 |
|------|------|
| Index | 入口 + 自动路由判断 |
| ApiConfigPage | 3 步配置向导 |
| MainPage | 底部 Tab 容器 |
| ChatPage | 流式对话 + Markdown |
| ConversationListPage | 对话列表 + 滑动删除 |
| SettingsPage | 主题 / 记忆 / 导入导出 |

## 技术决策

| 决策 | 选择 | 原因 |
|------|------|------|
| 导航方式 | Tabs 底部导航 | 用户明确选择 |
| Markdown 方案 | 纯 ArkTS 自实现 | 零外部依赖 |
| API 兼容 | OpenAI 格式 | 覆盖 DeepSeek/OpenAI/自定义 |
| 加密方案 | AES-256-GCM | cryptoFramework 原生支持 |

## 下一迭代计划

- MD 文件导出
- MD 文件导入
- 对话搜索
- 性能优化
