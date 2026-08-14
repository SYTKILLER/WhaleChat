# WhaleChat 导入兼容 .txt 合规格式 — 修复方案

> **日期**：2026-08-01  
> **问题**：新 .txt 合规导出文件的尾部显式声明和 JSON-LD 元数据会污染导入后的最后一条消息  
> **状态**：待实施（coder 执行）

---

## 一、问题描述

### 新导出格式的文件结构

```
【AI生成内容声明】本内容由人工智能模型生成...[零宽水印]

<!-- whalechat-conversation -->
# 标题
> id: xxx
...
**User:**
你好

**Assistant:**
你好！有什么可以帮你的？

本文由AI辅助创作，仅供参考。          ← 尾部显式声明
                                        ← 空行
<!-- JSON-LD Metadata                    ← JSON-LD 元数据块
{
  "@context": "https://schema.org",
  ...
}
-->
```

### 污染路径

导入流程：`ImportService.tryImportFromUri()` → 读文件 → `batchParseMarkdown()` 按 `<!-- whalechat-conversation -->` 切分 → `markdownToConversation()` 单段解析

`markdownToConversation()` 的消息解析循环（第 134-178 行）从 `**Assistant:**` 开始一直读到文件末尾，以下 3 类内容会被追加到最后一条消息中：

1. `本文由AI辅助创作，仅供参考。`
2. 空行
3. `<!-- JSON-LD Metadata` 到 `-->` 整个块

### 影响范围

| 场景 | 受影响 |
|------|--------|
| 导入新格式 .txt 单文件 | ❌ 最后一条消息被污染 |
| 导入新格式 .txt 批量文件 | ❌ 每段最后一条消息被污染 |
| 导入旧格式 .md 文件 | ✅ 不受影响（无尾部文本） |
| 导入旧格式 .txt 文件（`====AIGC-META====`） | ✅ 不受影响（已有跳过逻辑） |
| 外部普通 .md 文件 | ✅ 不受影响 |

---

## 二、无需修改的文件

以下文件经确认无需任何改动：

| 文件 | 原因 |
|------|------|
| `pages/SettingsPage.ets` | `DocumentViewPicker` 未设置 `fileSuffixFilters`，默认接受所有文件类型（含 .txt） ✅ |
| `entryability/EntryAbility.ets` | `onNewWant` 不区分文件扩展名，直接透传 URI ✅ |
| `services/ImportService.ets` | 仅做读取+解析，无文件类型判断 ✅ |
| `utils/FileHelper.ets` | `readFileFromUri()` 通用文本读取，无扩展名限制 ✅ |

---

## 三、需修改的文件

### 仅 1 个文件：`entry/src/main/ets/utils/MarkdownConverter.ets`

**位置**：`markdownToConversation()` 函数，第 90 行之后（显式声明跳过逻辑的 `}` 闭合之后）

**当前代码**（第 83-95 行）：
```typescript
  // 预处理：跳过合规导出的显式声明行
  const declPrefix = '【AI生成内容声明】'
  if (content.startsWith(declPrefix)) {
    const firstNewline = content.indexOf('\n')
    if (firstNewline >= 0) {
      content = content.substring(firstNewline + 1)
    }
  }

  // 快速检查识别标记
  if (!content.includes(WHALECHAT_MARKER)) {
    return null
  }
```

**修改为**（在第 90 行 `}` 与第 92 行 `// 快速检查识别标记` 之间插入 6 行）：
```typescript
  // 预处理：跳过合规导出的显式声明行
  const declPrefix = '【AI生成内容声明】'
  if (content.startsWith(declPrefix)) {
    const firstNewline = content.indexOf('\n')
    if (firstNewline >= 0) {
      content = content.substring(firstNewline + 1)
    }
  }

  // 预处理：裁剪尾部显式声明和 JSON-LD 元数据块
  const tailDecl = '本文由AI辅助创作'
  const tailIdx = content.indexOf(tailDecl)
  if (tailIdx >= 0) {
    content = content.substring(0, tailIdx).trimEnd()
  }

  // 快速检查识别标记
  if (!content.includes(WHALECHAT_MARKER)) {
    return null
  }
```

### 修改说明

- 在消息解析循环开始之前，检测到 `本文由AI辅助创作` 字符串时，截断其后的所有内容
- `batchParseMarkdown` 的每个分段都会独立调用 `markdownToConversation`，因此批量导入时每段都能正确裁剪
- 不影响旧格式（旧格式不含 `本文由AI辅助创作` 字符串，`indexOf` 返回 -1，跳过此分支）

---

## 四、验收标准

### 4a. 单元级验收

| 编号 | 验收项 | 输入 | 预期输出 |
|------|--------|------|---------|
| U1 | 新 .txt 单文件导入 | 合规导出的单段对话 .txt | 正常导入，消息内容不含 `本文由AI辅助创作` 和 JSON-LD |
| U2 | 新 .txt 批量导入 | 合规导出的多段对话 .txt | 正常导入所有对话，每段最后一条消息干净 |
| U3 | 旧 .md 导入（向后兼容） | 旧版导出的 .md 文件 | 正常导入，不受影响 |
| U4 | 旧 .txt 导入（`====AIGC-META====`） | 旧版 .txt 格式 | 正常导入，已有跳过逻辑仍然生效 |
| U5 | 外部普通 .md 导入 | 不含 `<!-- whalechat-conversation -->` 的普通 markdown | `markdownToConversation` 返回 null（无识别标记），ImportService 不保存 |
| U6 | 分享后立即导入 | 从系统分享面板接收的 .txt | 同 U1，正常导入 |

### 4b. 集成级验收

| 编号 | 验收项 | 验证步骤 |
|------|--------|---------|
| I1 | 编译通过 | 运行 `hvigorw assembleHap`，确认 `BUILD SUCCESSFUL` |
| I2 | 导出→导入闭环 | 在应用中导出 1 条对话 → 立即导入该 .txt → 对话列表中出现导入的对话，消息内容与原文一致 |
| I3 | 批量闭环 | 批量导出 3 条对话 → 导入该 .txt → 3 条对话均正确还原 |

### 4c. 编译命令

```bash
cd D:/WhaleChat
"C:/Program Files/Huawei/DevEco Studio/tools/hvigor/bin/hvigorw" assembleHap --no-daemon
```

期望：`BUILD SUCCESSFUL`，零错误零警告。

---

## 五、变更汇总

| 文件 | 操作 | 行数 |
|------|------|------|
| `utils/MarkdownConverter.ets` | 在 `markdownToConversation()` 预处理阶段增加尾部裁剪（+6 行） | +6 |
| 其他文件 | **不修改** | 0 |

---

## 六、注意事项

1. `replacement` 的 `tailDecl` 使用了 `'本文由AI辅助创作'` 作为检测锚点（而非完整句子 `'本文由AI辅助创作，仅供参考。'`），防止未来文案微调时遗漏。
2. 尾部裁剪放在显式声明跳过之后、识别标记检查之前，确保裁剪逻辑在 `batchParseMarkdown` 的每个分段都生效。
3. 如果未来导出格式在正文中出现 `本文由AI辅助创作` 字符串（用户消息恰好包含此文本），这会导致误裁剪。虽然概率极低，但可选择更精确的锚点（如 `'\n本文由AI辅助创作'`）。
