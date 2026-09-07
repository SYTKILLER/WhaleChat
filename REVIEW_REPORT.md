# WhaleChat 核心代码规范审查 · 问题清单

> 审查范围：`entry/src/main/ets/` 全部 39 个 `.ets` 文件（约 7000 行）
> 审查维度：A · ArkTS 语法禁区 / B · API 用法 / C · ArkUI 组件与动画 / D · 数据与端云同步
> 总体结论：⚠️ 需改进（核心架构模式已落地，但存在 5 类严重问题 + 11 项警告 + 若干建议）
> 审查方式：全程只读，未修改任何代码

---

## 一、严重问题（编译级红线 / 数据丢失）

### S1 · 对象展开运算符（维度 A）
- **文件**：`preview/PreviewComponents.ets:81`、`:235`
- **违反条目**：`harmonyos-dev-spec`「❌ 不支持对象展开运算符（数组展开仅限 rest 参数和数组字面量）」
- **说明**：`{ ...createDefaultApiConfig(), ... }` 属 ArkTS 明确禁止语法，违反将无法编译。
- **修复建议**：改为 `const c = createDefaultApiConfig(); c.providerId = '...'; c.selectedModel = '...'` 逐字段覆盖。

### S2 · `Message` 对象字面量缺必需字段（维度 B）
- **文件**：`preview/PreviewComponents.ets:20-25`、`:27-50`、`:133-139`
- **违反条目**：对象字面量必须对应显式 interface；缺 `thinkingContent`/`showThinking`/`isStreaming`/`model` 等无 `?` 必需字段，类型不匹配。
- **修复建议**：改用 `createMessage()` 工厂函数，或补齐全部必需字段。

### S3 · `obj["field"]` 括号索引访问（维度 A，系统性，约 26 处）
- **文件**：
  - `pages/ChatPage.ets:57-58`（`params['conversationId']`）
  - `services/ApiService.ets` 约 22 处（`:160/237/239-241/244/276/346/348-349/359/361-362/444/446/451/522-523/526-529` 等，配合 `as Record<string, Object>` 解析 JSON）
  - `pages/SettingsPage.ets:240-241`（`bizErr['code']`/`['message']`）
- **违反条目**：`harmonyos-dev-spec`「❌ 不支持 `obj["field"]` 索引访问 — 用 `obj.field`」
- **说明**：`Record<string, Object>` 虽为 stdlib 特例可能通过编译，但违反项目明确红线，且 JSON 响应缺显式 interface。
- **修复建议**：为 `ChatResponse/Usage/Choice/Delta/BalanceResponse/ErrorResponse` 等声明显式 interface 并改用点号访问；`ChatPage` 用 `interface ChatRouteParams { conversationId: string }` 替代 `Record`。

### S4 · 迁移服务写入不存在列 → 旧对话静默丢失（维度 D）
- **文件**：`services/MigrationService.ets:81`
- **违反条目**：双表 / DDL 一致性约束
- **说明**：ValuesBucket 含 `'memory_id': ''`，但 `CONVERSATIONS` 表 DDL 无此列（`memory_id` 是 SETTINGS 键）→ insert 抛 SQL 异常被 catch 吞掉，老用户旧对话迁移静默失败、永久丢失。
- **修复建议**：删除该 `'memory_id'` 行，并让 catch 记录 `hilog.error`。

### S5 · 全库重建无备份丢数据（维度 D）
- **文件**：`services/DatabaseHelper.ets:237-256`（及 `:172` 的 `deleteRdbStore`）
- **违反条目**：`NOTICE.md`「DB 版本升级慎用全库重建，优先 ALTER TABLE ADD COLUMN 增量迁移」
- **说明**：`checkNeedsRebuild` 对 `version < 3` 直接 `deleteRdbStore` 清空全部本地数据，无备份。
- **修复建议**：改为增量迁移，或导出→重建→导入流程。

---

## 二、警告（运行期 bug 风险 / 明显规范违反）

### W1 · AGC 初始化 API 存疑（维度 B）
- **文件**：`services/AccountService.ets:37` `auth.init(context, json)`
- **说明**：AGC 标准初始化应为 `@hw-agconnect/core` 的 `agconnect.instance().init(context)` 自动读 rawfile，`@hw-agconnect/auth` 默认导出未见公开 `init(context,json)`。
- **修复建议**：走 T2/T3 检索确认 `@hw-agconnect/auth@1.0.5` API。

### W2 · 缺 `@hw-agconnect/core` 依赖（维度 B）
- **文件**：根 `oh-package.json5`（仅声明 `@hw-agconnect/auth@^1.0.5`）
- **修复建议**：补 `@hw-agconnect/core` 依赖。

### W3 · CustomDialog 自引用控制器（维度 C）
- **文件**：`pages/ApiManagementPage.ets:368`、`:460`、`:517`
- **违反条目**：项目 `customdialog-correct-pattern`（controller 用 `controller?: CustomDialogController`，父组件用 `CustomDialogController | null`）
- **说明**：结构体自引用 `controller = new CustomDialogController({...})`，弹窗内 `this.controller.close()` 可能关不掉父组件打开的真实实例。
- **修复建议**：改为父组件持有 `CustomDialogController | null` + `?.open()`。

### W4 · `@State` 数组元素直接下标赋值不刷新（维度 C）
- **文件**：`pages/SettingsPage.ets:415-417`、`:914`
- **说明**：`@State` 数组元素直接赋值不触发响应式刷新，全选/勾选 UI 不更新。
- **修复建议**：用 `this.xxx = [...this.xxx]` 或 `splice` 触发更新。

### W5 · 读取前未 `await storageService.init()`（维度 D）
- **文件**：`pages/ApiConfigPage.ets:43`、`pages/ApiManagementPage.ets:31`
- **说明**：数据库未就绪时静默读空，存在初始化竞态（其它页面已正确 `await init`）。
- **修复建议**：`aboutToAppear` 先 `await storageService.init(getContext(this))`。

### W6 · `SyncService.doSync` 未 await（维度 D）
- **文件**：`services/SyncService.ets:41-54`
- **说明**：fire-and-forget，「同步后刷新」失效。
- **修复建议**：`return/await doSync`。

### W7 · `.catch(() => {})` 静默吞错（维度 D）
- **文件**：`services/StorageService.ets:202`、`:251`；及 `ApiService.ets:254-256/284`
- **违反条目**：`NOTICE.md`「`.catch(() => {})` 会静默吞噬错误」
- **修复建议**：改 `.catch((err) => hilog.error(...))`。

### W8 · 全量替换无事务包裹（维度 D）
- **文件**：`services/StorageService.ets:92-136`、`:185-206`、`:234-255`
- **说明**：DELETE + 循环 INSERT 无事务，中断易部分丢失。
- **修复建议**：`beginTransaction`/`commit` 包裹。

### W9 · `ForEach` 缺 keyGenerator（维度 C）
- **文件**：`components/MarkdownView.ets:16`、`:244`
- **说明**：流式场景列表项频繁增删，缺唯一 key 可能渲染复用错乱。
- **修复建议**：补第三参数唯一 key。

### W10 · 正则负向后行断言（维度 A）
- **文件**：`services/MarkdownParser.ets:229` `(?<!\*)\*(?!\*)...`
- **说明**：lookbehind 在部分设备/低 API 运行期可能不支持。
- **修复建议**：改写为不带 lookbehind 的等价匹配。

### W11 · 未使用 import（维度 B）
- **文件**：`pages/SettingsPage.ets:20`（`readFileFromUri`）、`pages/RecycleBinPage.ets:10`（`syncService`）、`components/ModelSelector.ets:5`（`getProvider`）
- **修复建议**：删除未使用 import（RecycleBinPage 的 `syncService` 若在恢复/删除后补上云同步则可保留并调用）。

---

## 三、建议（维护性 / 资源化 / 健壮性）

1. **UI 字符串/颜色硬编码未资源化（系统性）**：pages/components 大量 `'#FFFFFF'`、`'#007DFF'`、`'rgba(...)'` 及中文文案（「深度思考」「取消」「确定」等）用字面值，且用 `currentColorMode === 1 ? A : B` 手写深浅色三元。建议下沉到 `resources/base/element/color.json`/`string.json`（含 dark/en_US），改用 `$r`。主题色 `THEME_COLORS`（`Constants.ets:86-95`）因动态存库可作例外并加注释说明。
2. **魔法数字**：`maxTokens: 393216`（`Conversation.ets:44`、`ApiConfig.ets:80`、`ChatBubble.ets`）疑似笔误（≈384K token），`temperature: 0.8`/`topP: 1.0` 散落。建议抽到 `Constants.ets` 统一。
3. **双模型漂移**：`ApiConfig`（9 字段）与 `ManagedApiConfig`（6 字段）并存，对应 SETTINGS/APICONFIGS 两条路径。建议收敛单一模型或集中字段映射。
4. **瞬时态混入持久化模型**：`Message.showThinking`/`isStreaming` 属 UI 瞬时态却随 `JSON.stringify(c.messages)` 入库。建议拆分。
5. **死代码**：`FileHelper.ets:20` `createMdFile()` 全仓库无调用；`MarkdownView.ets:80` 三元两分支相同（`'#AAAAAA'`）。
6. **`Span` 用容器属性**：`MarkdownView.ets:257-259` 的 `.backgroundColor/.borderRadius/.padding` 在行内 Span 上可能不生效，建议改 `.textBackgroundStyle({ color, radius })` 并核实 SDK 支持。
7. **`build()` 内重解析 Markdown**：`ChatBubble.ets:142/157` 每次刷新重解析整段，流式高频下开销大，建议缓存到 `@State`/`@Computed`。
8. **日志规范**：`console.info/warn` 与 `hilog` 混用（`AccountService`/`CloudBackupService`），`hilog` 模板字符串应改 `%{public}s` 占位符（`FileHelper`/`ImportService`）。
9. **硬编码路由字符串**：`'pages/LoginPage'`/`'pages/MemoryPage'` 未用 ROUTES 常量；AppStorage key 魔法字符串不一致。
10. **空 catch / fire-and-forget**：`MainPage.ets:122-123`、`MessageInput.ets:49` 空 catch；`MemoryPage.saveMemories()` 调用处未 await 且无 try/catch。
11. **`ExportHelper.ets:162`**：分享临时文件固定 5 秒删除，分享面板停留过久可能失败。
12. **`JSON.parse` 缺类型断言**：`StorageService.ets:152`、`MigrationService.ets` 多处解析结果未 `as` 断言，类型安全不足。

---

## 四、最优先修复项 Top-5

1. **`MigrationService.ets:81`** —— 删除 `'memory_id': ''`，修复旧对话迁移静默丢失（数据丢失，最高优先级）。
2. **`PreviewComponents.ets:81/235` + `:20-50/133-139`** —— 移除对象展开、补齐 `Message` 必需字段（编译级红线）。
3. **`ApiService.ets`（~22 处）+ `ChatPage.ets:57-58` + `SettingsPage.ets:240-241`** —— 用显式 interface 替换 `Record<string,Object>` 与 `obj["field"]` 括号访问。
4. **`DatabaseHelper.ets:237-256`** —— 全库重建改为 `ALTER TABLE ADD COLUMN` 增量迁移，避免丢数据。
5. **`ApiManagementPage.ets:368/460/517`** —— CustomDialog 改父组件 `controller | null` 模式，修复弹窗关闭失效。
