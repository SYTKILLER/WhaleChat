# WhaleChat 项目记忆（HarmonyOS 专属）

> 本文件为 WhaleChat 项目的专属记忆，仅在 `D:\WhaleChat` 项目内生效。
> 全局记忆（ArkTS 语法禁区 / 工作流 / 指令卡）见 `~/.dsh/AGENTS.md`。
> 来源：`D:\WhaleChat\HARMONYOS_AGENT_CONFIG.md`（导出 2026-08-14）

---

## 1. whalechat-arkts-constraints（项目特定 ArkUI 模式）

### 组件使用细节
- `Select` 使用 `.font({ size: n })` 而非 `.fontSize(n)`
- `SelectOption` 需显式构造 `{ value: string }`
- `TabsController.changeIndex()` 触发 Tab 切换（不是直接改 @State）
- `ListItem` 只能有一个子节点，多节点用 Column/Row 包裹
- `@Builder` 方法内不能声明变量，变量在 struct 级别声明
- `@Provide` 必须配合 `@State` 才是响应式

### 项目状态
- compileSdk 26, compatibleSdk 24
- 全屏布局：`setWindowLayoutFullScreen(true)` + `expandSafeArea`
- 动态安全区：`getWindowAvoidArea(TYPE_SYSTEM)` → topSafeHeight/bottomSafeHeight

---

## 2. whalechat-data-architecture（数据存储架构）

### 双表陷阱（重要）

两套 API 配置存储路径，改入口判定后必须保持一致：

| 方法 | 写入表 | 读取表 |
|---|---|---|
| `saveApiConfig(config)` | SETTINGS (key-value) | — |
| `loadApiConfig()` | — | SETTINGS (key-value) |
| `saveApiConfigs(configs[])` | APICONFIGS | — |
| `loadApiConfigs()` | — | APICONFIGS |

**事故**：Index 入口判定改为 `loadApiConfigs().length > 0` 后，ApiConfigPage 的 `saveApiConfig()` 写 SETTINGS 但 `loadApiConfigs()` 读 APICONFIGS → 永远空 → 首次安装反复跳配置页卡死。
**修复**：`saveApiConfig()` 同时写 SETTINGS（兼容）和 APICONFIGS（`ON_CONFLICT_REPLACE`）。

### 数据库初始化竞态

`EntryAbility.onCreate` 中 `dbHelper.init()` 异步 `.then()` 不 await，页面 `aboutToAppear` 可能先于数据库就绪执行 → `getStore()` 返回 null → 静默失败。
**修复**：`DatabaseHelper.waitForReady()` Promise 机制，`storageService.init()` 中阻塞等待。

### 数据表清单

| 表 | 用途 | 分布式 |
|---|---|---|
| CONVERSATIONS | 对话列表 | DISTRIBUTED_CLOUD |
| MEMORIES | 永久记忆 | DISTRIBUTED_CLOUD |
| SETTINGS | K-V 设置 | DISTRIBUTED_CLOUD |
| APICONFIGS | 多 API 配置 | DISTRIBUTED_CLOUD |
| _MIGRATION | 迁移标记 | — |

---

## 3. whalechat-cloudkit-sync（Cloud Kit 端云同步）

### 前置条件
AGC Cloud Database 需完成：创建容器（名=DB 名 `WhaleChat`）、配置数据类型、debug 证书 SHA256 指纹加到 AGC、实施变更到生产、生产测试。

### 关键 API 约束
- `setDistributedTables` 异步，必须 `await`，传 `DistributedConfig { autoSync: true }`
- `cloudSync` mode 必须用 `relationalStore.SyncMode` 枚举值（纯数字触发 401）
- 有效 SyncMode：`SYNC_MODE_TIME_FIRST`（唯一编译通过值）
- `StoreConfig` 不含 `cloudConfig` 字段
- `DistributedType.DISTRIBUTED_CLOUD` 可用，同表不能同时 DEVICE 和 CLOUD（错误码 14800051）

### 数据库版本迁移
旧代码 `setDistributedTables` 无类型参数 → 默认 DEVICE。迁移：检测 `SETTINGS.db_schema_version`，版本 <2 时 `deleteRdbStore` 重建。

---

## 4. customdialog-correct-pattern（CustomDialog 正确用法）

**根因**：`controller!` 非空断言在 ArkTS 运行时无效导致崩溃。

**正确模式**：controller 用 `| null` 而非 `!`：

```typescript
@CustomDialog
export struct RenameDialog {
  controller?: CustomDialogController      // 可选，不用 !
  @Link titleText: string                  // @Link 双向绑定
  confirm: () => void = () => {}           // 回调
  build() {
    Column() {
      Button('确定').onClick(() => { this.confirm(); this.controller?.close() })
      Button('取消').onClick(() => { this.controller?.close() })
    }
  }
}

// 父组件
private renameDialogController: CustomDialogController | null = null
aboutToDisappear(): void { this.renameDialogController = null }

this.renameDialogController = new CustomDialogController({
  builder: RenameDialog({ titleText: $renameText, confirm: () => { this.confirmRename() } }),
  autoCancel: true, alignment: DialogAlignment.Center, customStyle: false
})
this.renameDialogController?.open()
```

**要点**：bindSheet 有位置靠下和键盘避让问题；任何弹窗优先 CustomDialog，绝不用 `controller!`。

---

## 5. deveco-run-env（deveco run 环境注入）

`deveco run` 依赖 `DEEPSEEK_API_KEY` 环境变量。该变量已通过 `setx` 持久化，但**当前 shell 会话不会继承 setx 变更**（只对新开终端生效）。

每个新 shell 会话需注入一次：
```bash
export DEEPSEEK_API_KEY=$(powershell -Command "[Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY','User')" | tr -d '\r')
deveco providers list   # 应显示 DeepSeek（1 environment variable）
deveco run "问题"
```

若仍报 server error，用 `deveco providers list` 确认凭证是否被识别。

---

## 6. notice-md-workflow（NOTICE.md 工作流）

- 编码前先读取 `D:\WhaleChat\NOTICE.md` 查看历史注意事项
- 编码中出错（编译报错、逻辑 bug、遗漏步骤），修复后用一句话概括追加到 NOTICE.md 末尾（按日期分组）

---

## 7. whalechat-build-command（编译命令）

**项目根目录**：`D:\WhaleChat`

```bash
cd D:\WhaleChat && node "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" assembleHap --mode module -p module=entry@default -p product=default
```

- 必须用 `node` 调用 hvigorw.js（不能直接执行）
- 超时 180 秒，成功标志 `BUILD SUCCESSFUL`
- 文档目录 `D:\WhaleChatDocuments\`：DevGuide/、Backup/、PROJECT_STRUCTURE.md、DEVELOPMENT_LOG.md

---

## 8. whalechat-backup-and-docs（备份与文档规范）

### 目录结构
```
D:\WhaleChat\                   ← 项目根（仅代码和配置）
D:\WhaleChatDocuments\
  ├── Backup\ + index.md        ← 备份目录
  ├── DevGuide\                 ← 开发指南
  ├── PROJECT_STRUCTURE.md      ← 项目结构
  └── DEVELOPMENT_LOG.md        ← 开发日志
```

### 开发前
备份到 `D:\WhaleChatDocuments\Backup\<功能名称>\`：`entry/src/main/ets/` 完整目录、`module.json5`、`main_pages.json`、`app.json5`；更新 `Backup/index.md`

### 开发后
- 更新 `PROJECT_STRUCTURE.md`（日期、目录树、最近变更）
- 更新 `DEVELOPMENT_LOG.md`（新增日期条目：原因+改动+文件列表）

---

## 9. whalechat-project-structure（项目结构）

**关键事实**：
- Bundle: com.whalechat.app v1.0.0
- SDK: compileSdk 26 / targetSdk 26 / compatibleSdk 6.1.1(24)
- 设备: HUAWEI Pura 70 Pro+ (HBN-AL80)
- 零第三方依赖，纯 HarmonyOS SDK
- API: DeepSeek (deepseek-v4-flash/pro) + OpenAI (gpt-4o etc.)
- 存储: RdbStore（WhaleChat.db）

**目录**：
- `entry/src/main/ets/entryability/` — EntryAbility
- `entry/src/main/ets/pages/` — 所有页面
- `entry/src/main/ets/components/` — ChatBubble, MessageInput, LucideIcon, MarkdownView
- `entry/src/main/ets/models/` — Message, Conversation, ApiConfig, Memory
- `entry/src/main/ets/services/` — ApiService, StorageService, MarkdownParser 等
- `entry/src/main/ets/common/` — Constants, Utils

**路由**：Index → ApiConfigPage（首次）或 MainPage → ChatPage/MemoryPage
