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
├── README.md             ← 本文
├── LICENSE               ← 仓库许可（MIT）
├── .gitignore
├── manifest.json         ← 唯一客户端入口，客户端拉这个文件发现组件
├── scripts/
│   └── build-component.ps1   ← 打包 + 算 SHA-256 + 输出可粘贴的 manifest 片段
└── packages/             ← 打包产物 zip（.gitignore 忽略，走 GitHub Releases 分发）
    └── <id>.zip
```

**发布文件通过 GitHub Releases**（不放 git tree，避免仓库膨胀）：
- Release tag = `<component-id>-vX.Y.Z`（如 `bge-small-zh-v1.5`）
- Release asset = `<component-id>.zip`（客户端下载的实际文件）

---

## 发布一个新组件的完整流程

假设你要发布主题包 `theme-dark-v1`，源文件在 `F:\...\theme-dark\`（含 `.nexself-component.json` + 各类文件）。

### 1. 用脚本打包

```powershell
.\scripts\build-component.ps1 -SourceDir "F:\...\theme-dark" -Id "theme-dark-v1"
```

脚本会：
- 生成 `packages/theme-dark-v1.zip`
- 算 SHA-256
- 打印可直接粘贴进 `manifest.json` 的字段（sizeBytes / sha256 / download URL 模板）
- 打印上传步骤提示

### 2. 上传到 GitHub Releases

- 打开 https://github.com/visionnie/nexself-components/releases → `Draft a new release`
- **Tag**: 手动输入 `theme-dark-v1`，选 `Create new tag: theme-dark-v1 on publish`
- **Title**: 随便（`Theme Dark v1`）
- **Attach binaries**: 把 `packages/theme-dark-v1.zip` 拖进去（**不改名**，客户端按精确路径拉）
- 点 `Publish release`

### 3. 更新 manifest.json

复制脚本打印的字段，加进 `manifest.json` 的 `components` 数组：

```json
{
  "id": "theme-dark-v1",
  "kind": "theme",
  "displayName": "Dark Theme v1",
  "description": "深色主题，护眼向",
  "version": "1.0.0",
  "runtimeMin": "0.12.0",
  "sizeBytes": ...,       // 脚本填
  "sha256": "...",         // 脚本填
  "license": "MIT",
  "download": { "primary": "...", "mirrors": [] },  // 脚本填
  "unpack": { "kind": "zip", "layout": [...] },
  "provides": ["theme.dark"],
  "default": false
}
```

### 4. 提交 manifest

```bash
git add manifest.json
git commit -m "feat: publish theme-dark-v1"
git push
```

客户端下次点「↻ 同步仓库」就能拉到。

---

## `.nexself-component.json`（组件内嵌描述）

每个组件 zip 里必须带一个 `.nexself-component.json`，客户端解压后据此登记：

```json
{
  "id": "theme-dark-v1",
  "kind": "theme",
  "displayName": "Dark Theme v1",
  "version": "1.0.0",
  "sizeBytes": ...,
  "provides": ["theme.dark"],
  "description": "深色主题，护眼向",
  "license": "MIT"
}
```

字段必须与 manifest 里同 id 的条目一致。

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
          { "path": "解压后应存在的相对路径" }
        ]
      },
      "provides": ["能力标签，客户端按此 resolve"],
      "recommendedFor": ["建议启用此组件的场景"],
      "default": false
    }
  ]
}
```

---

## 当前已发布组件

| id | kind | 大小 | 用途 |
|---|---|---|---|
| `bge-small-zh-v1.5` | embedding | 15.6 MB | AI Engine Memory 语义搜索（内嵌预装，同版本 manifest 条目仅供参考） |
| `bge-small-zh-test-v1.5` | embedding | 15.6 MB | 开发测试用，走通装卸流程；正式版可删 |

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
