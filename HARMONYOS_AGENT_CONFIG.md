# HarmonyOS 开发配置手册（Agent 迁移用）

> 本手册汇总当前环境中的所有鸿蒙开发记忆、技能与约定，可直接复制到其他 Agent 工具（OpenCode / Cursor / Claude Code 等）中配置。
> 导出日期：2026-08-14

---

# 第一部分 · 全局记忆（适用于所有鸿蒙项目）

---

## 1. harmonyos-dev-spec（ArkTS 语法禁区 + API 规范）

> 适用于所有 HarmonyOS 项目

### ArkTS/ets 语法约束（违反将无法编译）

**类型系统：**
- ❌ 不支持 `any` / `unknown` — 显式指定类型
- ❌ 不支持 `as const` — 用显式类型标注
- ❌ 不支持交叉类型 `A & B` — 用继承
- ❌ 不支持索引访问类型 `T['key']` — 用类型名称
- ❌ 不支持映射类型、条件类型别名、`infer` 关键字
- ❌ 不支持结构化类型 — 用继承、接口或类型别名
- ❌ 不支持将对象字面量直接用作类型声明 — 显式声明 class/interface
- ✅ `Partial`、`Required`、`Readonly`、`Record` 可用

**类与接口：**
- ❌ 不支持类字面量 — 显式引入命名类类型
- ❌ 不支持将类用作对象（赋值给变量）
- ❌ 不支持在构造函数中声明类字段
- ❌ 不支持声明合并 — 保持定义紧凑
- ❌ 不支持接口中的构造函数签名 — 用方法
- ❌ 不支持接口包含两个不可区分签名的方法
- ❌ 不支持索引签名 — 用数组
- ❌ 不支持以 `#` 开头的私有标识符 — 用 `private`

**对象与数组：**
- ❌ 对象布局编译时已知且不可更改（不能删除属性、不能动态字段访问）
- ❌ 不支持 `obj["field"]` 索引访问 — 用 `obj.field`
- ❌ 不支持解构赋值、解构变量声明、解构参数
- ❌ 不支持对象展开运算符（数组展开仅限 rest 参数和数组字面量）
- ❌ 对象字面量必须对应显式声明的 class/interface（不能用于 `any`/`Object` 类型）

**函数：**
- ❌ 不支持函数表达式 — 用箭头函数
- ❌ 不支持嵌套函数 — 用 lambda
- ❌ 不支持 `Function.apply`/`Function.call`/`Function.bind`
- ❌ 不支持生成器函数 — 用 `async/await`
- ❌ 不支持在函数上声明属性
- ❌ 独立函数和静态方法中不支持 `this`
- ⚠️ 函数返回类型推断受限 — 建议显式指定

**其他关键：**
- ❌ 不支持 `for .. in` — 用常规 `for` 循环（数组）
- ❌ 不支持 `in` 运算符 — 用 `instanceof`
- ❌ 不支持 `is` 运算符 — 用 `instanceof` + `as` 转换
- ❌ 不支持 `var` — 用 `let`
- ❌ 不支持 `with` 语句
- ❌ 不支持 `delete` 属性 — 用可空类型赋 `null`
- ❌ 不支持 `typeof` 类型标注 — 用显式类型声明
- ❌ 不支持 `catch` 子句类型标注 — 省略类型
- ❌ 不支持 `require` 导入 — 用 `import`
- ❌ 不支持全局作用域和 `globalThis`
- ❌ 不支持 `Symbol()` API（除 `Symbol.iterator`）

### HarmonyOS API 使用规范

1. 优先使用官方 API、UI 组件、动画、代码模板
2. API 调用前确认入参、返回值、API Level 和设备支持
3. 不猜测或自行构造 API — 搜索华为开发者官方文档确认
4. 确认是否需要 `import` 语句
5. 确认是否需要权限，检查 `module.json5`
6. 确认依赖库存在和版本，检查 `oh-package.json5`
7. `@Component` 和 `@ComponentV2` 兼容性 — 与已有代码保持一致
8. UI 常量用 `resources` 资源值 + `$r` 引用，不用字面值
9. 国际化资源每种语言都添加
10. 颜色资源默认支持深色/浅色主题

### ArkUI 动画规范

1. 优先使用原生动画 API 和 `@State` 驱动动画
2. 复杂子组件动画设置 `renderGroup(true)` 减少渲染批次
3. 禁止在动画中频繁改变 `width`/`height`/`padding`/`margin` 等布局属性

### Cloud Kit 端云同步 API 约束（实测 + 官方文档验证）

| 知识点 | 说明 |
|---|---|
| `relationalStore.getRdbStore()` | `StoreConfig` **不含 `cloudConfig` 字段**（compileSdk 26 中不存在此属性） |
| `setDistributedTables()` | **异步方法**（返回 `Promise<void>`），必须 `await`；需传 `DistributedConfig { autoSync: true }` |
| `cloudSync()` mode 参数 | **必须用 `relationalStore.SyncMode` 枚举值**，纯数字 `0`/`1` 运行时触发 401 |
| 可用 SyncMode | `SYNC_MODE_TIME_FIRST`（唯一编译通过的值）；`SYNC_MODE_DEVICE_FIRST`/`SYNC_MODE_CLOUD_FIRST` 在 API 26 SDK 中不存在 |
| AGC 开发环境测试 | 需将 debug 证书 SHA256 指纹添加到 AGC 项目设置中 |

---

## 2. harmonyos-dev-workflow（开发工作流规范）

适用于所有鸿蒙项目的开发流程，分为 5 个阶段，不同场景裁剪执行。

### 阶段一：需求分析与知识准备

- **1a. 读取知识基线**：`harmonyos-dev-spec`（ArkTS 语法禁区）+ 项目专属约束记忆
- **1b. 需求确认**：需求不明确 → **立即确认**，不猜测用户意图
- **1c. 查询原生 API 支持**（三级检索）：
  1. 本地记忆（毫秒级）
  2. 直接读参考文件 `~/.local/share/deveco/skills/*/references/*.md`（秒级）
  3. `deveco run` 调用 harmonyos-knowledge skill（30-120s）
  - 原则：**有原生 API → 优先用原生；无 → 最小自定义；零第三方依赖**
- **1d. 方案对比**：列出 ≥2 种方案，标注 SDK 兼容性，选最稳定方案

### 阶段二：编码前准备（仅大量改动时）

- 涉及大量文件改动 → **询问用户是否需要备份**
- 需要备份 → 按项目备份规范执行（备份 + 更新 Backup/index.md）

### 阶段三：编码实现

- **3a. 语法层面**：禁止 `any`、`as const`、解构、对象展开、`for..in`、`obj["field"]`、第三方库
- **3b. 组件层面**：`Select` 用 `.font({size:n})`、`ListItem` 只能 1 个子节点、`@Builder` 不能声明变量、`@Provide` 配 `@State`
- **3c. 数据层面**：注意双表陷阱和初始化竞态
- **3d. 云同步层面**：`SyncMode` 用枚举值，`StoreConfig` 不含 `cloudConfig`

### 阶段四：编译验证（强制，不可跳过）

```bash
cd <项目目录> && node "<DevEco Studio路径>/tools/hvigor/bin/hvigorw.js" assembleHap --mode module -p module=entry@default -p product=default
```

报错处理循环：读错误 → 查 arkts-error-fixes → 修改 → 重编译 → 直到 BUILD SUCCESSFUL

### 阶段五：收尾

- 更新 DEVELOPMENT_LOG.md（`## 日期 · 变更原因` 条目）
- 更新 PROJECT_STRUCTURE.md（日期、变更表、目录树）
- 沉淀新知识：通用问题 → harmonyos-dev-spec；项目问题 → 项目记忆

### 场景裁剪指南

| 场景 | 执行阶段 |
|------|---------|
| 新功能开发 | 1 → 2 → 3 → 4 → 5 |
| Bug 修复（已知根因） | 1a + 3 + 4 + 5 |
| Bug 修复（未知根因） | 1a + 1c + 3 + 4 + 5 |
| 单文件小改 | 3 + 4 + 5a |
| 仅文档/注释 | 3 + 5a |

**核心底线**：编译验证不可跳过、原生 API 优先、需求不清必确认、新发现必沉淀。

---

## 3. harmonyos-dev-instruction-card（执行指令卡，精简版）

### 场景判定

```
新功能 → [A]全流程    Bug已知根因 → [B]跳知识+备份    Bug未知根因 → [C]需检索
单文件 → [D]轻量      文档/注释 → [E]仅记录
```

### [A] 新功能全流程

1. 读 harmonyos-dev-spec 语法禁区
2. 需求不清 → ask 确认
3. 查原生 API（T1 grep → T2 docs → T3 run）
4. 方案 ≥2 选 1，说明理由
5. 大改动 → ask 是否备份
6. 编码对照全部约束
7. 编译验证
8. 报错 → 查 → 修 → 重编 → BUILD SUCCESSFUL
9. 更新 DEVELOPMENT_LOG.md
10. 更新 PROJECT_STRUCTURE.md
11. 新坑写入记忆

### [B] Bug 修复（已知根因）
读 spec → 编码修复 → 编译 → 更新日志 → 更新结构 → 写记忆

### [C] Bug 修复（未知根因）
读 spec → 查知识定位 → 编码修复 → 编译 → 更新日志 → 写记忆

### [D] 单文件小改
改代码 → 编译 → 更新 DEVELOPMENT_LOG.md

### [E] 仅文档/注释
改 → 更新 DEVELOPMENT_LOG.md

### 知识检索三层策略

| 层级 | 方法 | 速度 |
|------|------|------|
| T1 | grep 本地参考文件 | 瞬时 |
| T2 | devecocli docs search | ~2s |
| T3 | deveco run | 30-120s |

**始终 T1 → T2 → T3 逐级升级。**

---

## 4. arkts-tabbar-builder-pitfall（BottomTabBarStyle 坑）

`BottomTabBarStyle({ normal, selected })` 的 `normal`/`selected` 属性接受 `SymbolGlyphModifier` 类型，不能直接传 `@Builder` 函数调用（`@Builder` 返回 `void`）。

**正确写法**：用 `@Builder` 直接作为 `.tabBar()` 参数（`.tabBar()` 本身接受 `CustomBuilder`）：

```typescript
@Builder tabItem(icon: Resource, label: string, index: number) {
  Column() {
    SymbolGlyph(icon)
      .fontColor([this.tab === index ? '#007AFF' : '#8E8E93'])
      .fontSize(24)
    Text(label).fontSize(10).fontColor(this.tab === index ? '#007AFF' : '#8E8E93')
  }
}
@Builder homeTabBar() { this.tabItem($r('sys.symbol.house'), '首页', 0) }
TabContent() { ... }.tabBar(this.homeTabBar)
```

---

# 第二部分 · 项目记忆（WhaleChat 专属）

---

## 5. whalechat-arkts-constraints（项目特定 ArkUI 模式）

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

## 6. whalechat-data-architecture（数据存储架构）

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

## 7. whalechat-cloudkit-sync（Cloud Kit 端云同步）

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

## 8. customdialog-correct-pattern（CustomDialog 正确用法）

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

## 9. deveco-run-env（deveco run 环境注入）

`deveco run` 依赖 `DEEPSEEK_API_KEY` 环境变量。该变量已通过 `setx` 持久化，但**当前 shell 会话不会继承 setx 变更**（只对新开终端生效）。

每个新 shell 会话需注入一次：
```bash
export DEEPSEEK_API_KEY=$(powershell -Command "[Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY','User')" | tr -d '\r')
deveco providers list   # 应显示 DeepSeek（1 environment variable）
deveco run "问题"
```

若仍报 server error，用 `deveco providers list` 确认凭证是否被识别。

---

## 10. notice-md-workflow（NOTICE.md 工作流）

- 编码前先读取 `D:\WhaleChat\NOTICE.md` 查看历史注意事项
- 编码中出错（编译报错、逻辑 bug、遗漏步骤），修复后用一句话概括追加到 NOTICE.md 末尾（按日期分组）

---

## 11. whalechat-build-command（编译命令）

**项目根目录**：`D:\WhaleChat`

```bash
cd D:\WhaleChat && node "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" assembleHap --mode module -p module=entry@default -p product=default
```

- 必须用 `node` 调用 hvigorw.js（不能直接执行）
- 超时 180 秒，成功标志 `BUILD SUCCESSFUL`
- 文档目录 `D:\WhaleChatDocuments\`：DevGuide/、Backup/、PROJECT_STRUCTURE.md、DEVELOPMENT_LOG.md

---

## 12. whalechat-backup-and-docs（备份与文档规范）

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

## 13. whalechat-project-structure（项目结构）

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

---

# 第三部分 · 技能（Skills）

---

## harmonyos-knowledge（HarmonyOS 知识检索，3 层策略）

桥接 DevEco CLI 内置 HarmonyOS 知识库。3 层检索策略避免 `deveco run` 超时：

```
已知错误类型/文件名? → Tier 1: grep + read_file（瞬时）
已知 API/组件名?     → Tier 2: devecocli docs search（~1-3s）
复杂问题/无匹配?    → Tier 3: deveco run（30-120s，最后手段）
```

### Tier 1 — 直接文件搜索（瞬时）

Base path: `C:/Users/sytki/.local/share/deveco/skills/`

- ArkTS 语法 → `arkts-grammar-standards/references/`（restrictions.md / basic-syntax.md / ts-diff.md）
- ArkUI 组件 → `arkui-knowledge/references/`（component-cookbook.md / common-mistakes.md / api-guardrails.md / ui-quality-checklist.md）
- 编译/运行错误 → `arkts-error-fixes/reference/`（31 个专题修复指南）

用法：`grep -i "<keyword>" "C:/Users/sytki/.local/share/deveco/skills/<分类>/references/"*.md`

### Tier 2 — 本地文档搜索（快）

```bash
devecocli docs search "<keywords>" --limit 5 --format json
devecocli docs read "<documentId>"
```

可用 catalog：harmonyos-guides / harmonyos-references / best-practices / harmonyos-faqs / harmonyos-releases / harmonyos-roadmap

### Tier 3 — 全量 AI 查询（慢，最后手段）

```bash
deveco run "<question>"
```

自动加载 5 个内置 skill（arkui-knowledge / arkts-grammar-standards / arkts-error-fixes / arkts-runtime-fix / deveco-create-project），超时设 180s。

**边界**：本地记忆已覆盖的问题优先用记忆；始终 Tier 1 → Tier 2 → Tier 3 逐级升级。

---

# 第四部分 · 关键约定速查

| 约定 | 内容 |
|------|------|
| **编译不可跳过** | 任何代码改动后必须 `hvigorw assembleHap` 到 BUILD SUCCESSFUL |
| **原生 API 优先** | 有原生就原生，无则最小自定义，零第三方依赖 |
| **需求不清必确认** | 不猜测用户意图 |
| **大改动先备份** | 备份到 Backup 目录 + 更新 index.md |
| **新坑必沉淀** | 通用 → harmonyos-dev-spec，项目 → 项目记忆 |
| **ArkTS 红线** | 禁 any/解构/展开/for..in/obj["field"]/嵌套函数 |
| **CustomDialog** | controller 用 `| null`，绝不用 `!` |
| **Cloud Kit** | SyncMode 用枚举，setDistributedTables 必须 await |
| **双表陷阱** | saveApiConfig 写 SETTINGS+APICONFIGS 保持一致 |
