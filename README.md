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
├── CLAUDE.md             ← AI 协作入口（硬规则 + 踩坑）
├── LICENSE               ← 仓库许可（MIT）
├── .gitignore
├── manifest.json         ← 唯一客户端入口；**由 Actions 自动维护，别手工改**
├── .github/workflows/
│   └── update-manifest.yml   ← 发 Release 时自动重算 manifest 并提交
├── scripts/
│   └── build-component.ps1   ← 校验 + 打包 + 算 SHA-256
└── packages/             ← 打包产物和源目录（.gitignore 忽略，走 GitHub Releases 分发）
    ├── <id>-<version>.zip
    └── _src/<id>/            ← 打包源目录，换版本时在这儿替换文件重打
```

**发布文件通过 GitHub Releases**（不放 git tree，避免仓库膨胀）：
- Release tag = `<component-id>-vX.Y.Z`（如 `bge-small-zh-v1.5`）
- Release asset = `<component-id>.zip`（客户端下载的实际文件）

---

## 发布一个新组件：打包 + 传 Release，完

`manifest.json` 由 `.github/workflows/update-manifest.yml` 自动维护，**不要手工改**。

### 1. 用脚本打包

源目录要**平铺**、带 `.nexself-component.json`（UTF-8 **无 BOM**）：

```powershell
.\scripts\build-component.ps1 -SourceDir ".\packages\_src\theme-dark-v1"
```

脚本会先卡两条硬要求（见下），然后生成 `packages/<id>-<version>.zip` 并打印 SHA-256。
`id` / `version` 默认从描述文件读，不用传。

### 2. 传 GitHub Release

- https://github.com/visionnie/nexself-components/releases/new
- **Tag**：`<id>-<version>`（脚本会打出来），选 `Create new tag on publish`
- **正文**：写变更说明 —— 会被自动写进 manifest 的 `changelog`，升级确认框里给用户看
- **附件**：拖 `packages/<id>-<version>.zip`
- `Publish release`

发布后 Actions 自动跑：扫所有正式 Release（草稿和预发布跳过）→ 解出每个 zip 里的描述文件 →
算 sha256 和体积 → 合并进 `manifest.json` → 提交回 `main`。

客户端点「↻ 同步仓库」就能拉到（raw.githubusercontent 有 CDN 缓存，可能要等几分钟）。

### 工作流是「合并」不是「重建」

机械字段（`version` / `sizeBytes` / `sha256` / `download` / `unpack`）按包里的实际内容覆盖；
人工字段（`runtimeMin` / `recommendedFor` / `default`）保留 manifest 里的原值 ——
这些 zip 里没有，全量重建会把它们抹掉。

`changelog` 取 Release 正文；正文留空就沿用已有的，不会被冲掉。
正文写漏了可以回头编辑 Release，工作流监听 `edited`，会自动重跑。

### 组件 zip 的两条硬要求

客户端 `api/components.rs` 装的时候会卡，不满足直接装不上（而且会把目录删掉）：

1. **必须含 `.nexself-component.json`** —— 没有就报「组件 zip 打包不合规」
2. **必须平铺**，不能有子目录 —— `extract_zip_flat()` 遇到子目录报「非法 entry 路径」

脚本和工作流都会提前查这两条。工作流查到不合规会**整体失败并点名哪个包**，
manifest 一个字不动，线上用户不受影响。

### id 的两种命名

| 写法 | 例子 | 行为 |
|---|---|---|
| 版本进 id | `bge-small-zh-v1.5` | 新版本 = 新 id = 新安装目录，多版本可并存 |
| id 不带版本 | `frpc-windows-x64` | 靠 `version` 字段升级，同 id 比版本号判「可升级」，覆盖安装 |

**默认用后者**，除非真要多版本并存。

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
| `bge-small-zh-v1.5` | embedding | 15.6 MB | AI Engine Memory 语义搜索 |
| `frpc-windows-x64` | tunnel | 5.5 MB | 内网穿透；开启公网访问（手机在外面连回家）时才需要 |

> frpc 从 nexself-pc v0.12.33 起不再随安装包 —— 它的行为特征和远控木马像，随包会让
> 95% 从不开公网访问的用户白吃一次杀毒误报，安装包也因此从 14.82 MB 降到 10.62 MB。
> 来龙去脉见 `nexself-pc/src-tauri/resources/frpc/README.md`。

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
