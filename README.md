# nexself-components

nexself-pc 桌面客户端的**官方组件仓**。

- 每个组件是 `<data>/components/<id>/` 目录里的一个可选能力包
- 客户端通过 `manifest.json` 发现可装组件，SHA-256 校验后下载解压
- 卸载不影响主程序

蓝图见 nexself-pc 项目内 `.docs/modules/component-store.md`。

---

## 仓库结构

```
nexself-components/
├── README.md
├── manifest.json                    ← 唯一入口，客户端拉这个文件
└── (未来) components/
    └── <id>/                        ← 每个组件的源文件（构建脚本用）
```

**发布文件通过 GitHub Releases**（不放 git tree，避免仓库膨胀）：
- Release tag = `<component-id>-vX.Y.Z`（如 `bge-small-zh-v1.5`）
- Release asset = `<component-id>.zip`（客户端下载的实际文件）

---

## manifest.json 契约

```json
{
  "schema": "nexself-components-v1",
  "publishedAt": "ISO 8601 时间戳",
  "components": [
    {
      "id": "唯一 id，含版本后缀，kebab-case",
      "kind": "embedding|stt|tts-voice|ocr|mcp-server|theme|font|icon-pack|other",
      "displayName": "面向用户的显示名",
      "description": "1-2 句说明",
      "version": "semver X.Y.Z",
      "runtimeMin": "客户端最低兼容版本",
      "sizeBytes": 24010842,
      "sha256": "整个 zip 的 SHA-256 (小写 hex 64 字符)",
      "license": "MIT / Apache-2.0 / ...",
      "download": {
        "primary": "GitHub Release asset 直链",
        "mirrors": ["可选备份镜像"]
      },
      "unpack": {
        "kind": "zip",
        "layout": [
          { "path": "解压后应存在的相对路径", "sha256": "(可选) 逐文件校验" }
        ]
      },
      "provides": ["能力标签，客户端按此 resolve"],
      "recommendedFor": ["建议启用此组件的场景"],
      "default": false
    }
  ]
}
```

### 发布一个新组件的流程

1. 把源文件打成 `<id>.zip`（内含 `.nexself-component.json` 描述）
2. 算 zip 的 SHA-256（Windows：`certutil -hashfile <id>.zip SHA256`；Linux：`sha256sum`）
3. 在 GitHub 建 Release，tag = `<id>-v<version>`，上传 zip 作为 asset
4. 编辑本仓 `manifest.json`：追加 / 更新对应条目，`download.primary` 用 asset 的直链
5. `git commit && git push` —— 客户端下次点"↻ 同步仓库"就能拉到

### `.nexself-component.json`（组件内嵌描述）

每个组件 zip 里必须带一个 `.nexself-component.json`，客户端解压后据此登记：

```json
{
  "id": "bge-small-zh-v1.5",
  "kind": "embedding",
  "displayName": "bge-small-zh v1.5",
  "version": "1.5.0",
  "sizeBytes": 24010842,
  "provides": ["embedding.bge-small-zh", "embedding.chinese-default"],
  "description": "...",
  "license": "MIT"
}
```

字段必须与 manifest 里同 id 的条目一致。

---

## 当前已发布组件

| id | kind | 大小 | 用途 |
|---|---|---|---|
| `bge-small-zh-v1.5` | embedding | 22.9 MB | AI Engine Memory 语义搜索（内嵌预装，同版本 manifest 条目仅供参考） |

（未来在这里追加，让人一眼看清仓里有什么）

---

## 客户端如何用

- **拉 manifest**：客户端在 设置 → 组件 → `↻ 同步仓库`，缓存 manifest.json 到本地 SQLite
- **列可装**：manifest 里但本地 `installed_components` 表还没有的条目 = 可装
- **安装**：点卡片 `+ 安装` → 下载 `download.primary` → 校验 SHA-256 → 解压到 `<data>/components/<id>/` → 插入 `installed_components` 行
- **卸载**：删表行 + `rm -rf <data>/components/<id>/`（内嵌预装组件不可卸载）
- **升级**：manifest 版本 > 本地版本时卡片显示"可升级"，用户确认后走安装流程覆盖

---

## 许可

仓库本身 MIT。各组件 zip 里的实际内容遵循其自身声明的 license。
