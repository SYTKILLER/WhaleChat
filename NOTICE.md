# NOTICE — 开发注意事项

> 记录每次编码过程中犯的错误，一句话概括应避免的问题。

---

## 2026-08-14 · 代码规范审查修复（REVIEW_REPORT.md S/W 全量）

- **`@State` 数组下标赋值不触发刷新** — `exportChecked[i] = x` 不更新 UI，改用 `splice(index, 1, x)` 或重建数组整体赋值。
- **`memory_id` 是 SETTINGS 键，不得写入 CONVERSATIONS 的 ValuesBucket** — 迁移服务误写入不存在列 → insert 抛 SQL 异常被 catch 吞掉 → 旧对话静默丢失。
- **`obj['field']` 括号访问违反 ArkTS 红线** — JSON 响应必须声明显式 interface 后用点号访问，禁止 `as Record<string, Object>` 解析；错误对象统一用全局 `BusinessError`。
- **`@hw-agconnect/auth@1.0.5` 原生暴露 `init(context, json)`，无需 `@hw-agconnect/core`** — 评审 W1/W2 为误报；AGC 初始化读 rawfile/agconnect-services.json 后传 json 字符串即可。
- **hvigor 在受限沙箱下报 ENOENT（00308003）实为 child_process 管道被阻断** — hvigorw 用 fork 启动子进程，需完整访问权限才能编译，非代码错误。

## 2026-08-01 · 问题 7 完成（API 管理页简化添加流程）

- **删组件要连带删其全部引用** — 删除 `PlatformSelectDialog` 时，同步清理 `PLATFORMS`/`PlatformOption`/`platformDialogController`/`showInputDialog` 及弹窗内 `platformName`/`platformId` 参数，grep 确认零残留再编译。
- **BaseURL 归一化统一入口** — 用户输入缺 `http://`/`https://` 前缀时统一补 `https://`，且尊重显式指定的协议；平台识别用 `toLowerCase().includes('deepseek')` 大小写不敏感。

## 2026-08-01 · 问题 6 完成（深度思考默认折叠）

- **`Message.showThinking` 被持久化为展开状态** — 进入对话时必须在 `initPage()` 加载后统一重置为 false，否则上次退出时的展开状态被保留。
- **`onDone` 回调中 `aiMsg.showThinking` 不要用 `this.deepThinking`** — 发送完成时若深度思考开关开启会把展开态写入消息，与流式自动折叠冲突；统一置 false，用户可手动展开。

## 2026-08-01 · deveco run 使用方式

- **`deveco run` 需先注入 `DEEPSEEK_API_KEY`** — `setx` 持久化只对新终端生效，当前 shell 会话不会继承；使用前需 `export DEEPSEEK_API_KEY=$(powershell -Command "[Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY','User')" | tr -d '\r')`，否则报 `Unexpected server error`、`providers list` 显示 0 credentials。
- **`deveco providers list` 可快速验证凭证** — 注入后应显示 `DeepSeek DEEPSEEK_API_KEY`（1 environment variable）。

## 2026-08-01 · BUGFIX_PLAN 四项修复

- **`CopyOptions` 是全局枚举，不能从 `@kit.ArkUI` import** — 编译器报 `no exported member named 'CopyOptions'`，直接使用 `CopyOptions.InApp` 即可（定义在 ets-loader 全局 enums.d.ts）。
- **组件没有 `.onLongPress()` 链式方法** — `ColumnAttribute` 上不存在 `onLongPress`，长按需用 `.gesture(LongPressGesture().onAction(() => {...}))`（全局手势，无需 import）。
- **multi_edit 连续替换可能产生重复代码** — 重写 ApiKeyStep 时第一个编辑已插入文本框、第二个编辑又替换条件块，导致同一文本框出现两次；改完必须重读文件核对结构。
- **ArkTS 中 `.map(cell => ...).join('\t')` 可用但 for 循环更稳** — MarkdownParser 新增纯文本提取时用 for 循环替代 map/join，避免 ArkTS 兼容性问题。
- **个人开发者无 phone scope** — `user.getPhone()` 恒为空，认证凭证应改用 UnionID（AccountKit `loginResp.data.unionID`），不要以手机号作为认证闸门。

## 2026-08-01 · AIGC 合规升级

- **ArkTS 禁止无类型对象字面量** — `JSON.stringify({ key: val })` 不合法，必须为每个匿名对象声明显式 `interface`。
- **HarmonyOS Symbol 名称需验证** — `sys.symbol.clear` 不存在，改用 `sys.symbol.trash_fill`；不要假设 SF Symbols 名称在 HarmonyOS 中同样有效。
- **`@Entry` 页面必须注册到 `main_pages.json`** — 通过 `router.pushUrl` 跳转的页面若未注册到此文件，点击无响应且无报错。
- **DB 版本升级慎用全库重建** — 改 `CURRENT_DB_VERSION` 会触发 `deleteRdbStore` 清空全部本地数据，优先用 `ALTER TABLE ADD COLUMN` 增量迁移。
- **`@Watch` 装饰器位置要精确** — 想监听 `messages` 变化却误加到 `streamingContent` 上，每个 `@Watch` 绑定前确认目标属性。
- **`.catch(() => {})` 会静默吞噬错误** — 云同步失败 401 / 网络错误被完全隐藏，改为 `.catch((err) => hilog.error(...))`。

## 2026-07-28 · 回收站功能

- **`main_pages.json` 遗漏导致页面白屏** — 新建 `RecycleBinPage` 后忘记注册，`router.pushUrl` 找不到目标页面，点击无响应无报错。
- **云侧表结构与本地 DDL 必须一致** — 本地新增 `is_deleted` 列后，AGC Console 也需添加同名字段并"实施变更"到生产环境，否则 Cloud Kit 同步时丢弃该列数据。

## 2026-07-28 · 删除确认弹窗

- **`AlertDialog` 使用 `this.getUIContext().showAlertDialog()`** — 不是全局 `AlertDialog.show()`，在 `@Builder` 和 `onClick` 回调中均可使用。

## 2026-07-02 · 导出统一（更早的迭代）

- **import 清理要彻底** — 重构后旧的 `systemShare`、`fileIo`、`createMdFile` 等 import 不再使用但未删除，后续审查发现 4 个未使用 import。
- **函数签名变更需全局搜索调用方** — ExportHelper 签名从 `common.Context` 改为 `common.UIAbilityContext` 后，仅更新了 2 个调用方，遗漏了 1 个导致类型不匹配。
