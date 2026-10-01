# AI 协作 — nexself-components

nexself-pc 的**官方组件仓**（public）。本地克隆就在 `F:\Git\AI\nexself\nexself-components`，
**直接在这儿改、在这儿提交**，不要再在 nexself-pc 里另写一份组件相关的脚本或文档。

远程：`git@github.com:visionnie/nexself-components.git`（单远程，`main` 分支，不走 test/master 那套）

## 硬规则

- **发组件只有一步**：打好 zip → 传 GitHub Release。`manifest.json` 由
  `.github/workflows/update-manifest.yml` 自动重算并提交回 `main`。
- **绝对不要手工编辑 manifest.json 的机械字段**（`version` / `sizeBytes` / `sha256` /
  `download` / `unpack`）—— 下次发 Release 会被工作流覆盖。
  人工字段（`runtimeMin` / `recommendedFor` / `default`）可以直接改，工作流会保留。
- `packages/` 已 gitignore：zip 和打包源目录都不进 git（frpc.exe 单个就 14.59 MB），只走 Releases 分发。
- 改哪个仓就在哪个仓提交。本仓没有 commit-push.ps1，用原生 git。

## 发一个组件

```powershell
# 源目录要平铺 + 带 .nexself-component.json（UTF-8 无 BOM）
.\scripts\build-component.ps1 -SourceDir ".\packages\_src\<id>"
```

脚本会校验那两条硬要求、打出 `packages/<id>-<version>.zip`、打印 sha256 和剩下的一步。
然后去 Releases 新建：**tag 用 `<id>-<version>`**，正文写变更说明（会变成 manifest 的 `changelog`），
附件拖 zip，Publish。Actions 跑绿就完事。

## 组件 zip 的两条硬要求

客户端 `api/components.rs` 装的时候会卡，不满足直接装不上（而且会把目录删掉）：

1. 必须含 `.nexself-component.json`，字段见 README
2. 必须平铺，不能有子目录（`extract_zip_flat()` 只认平铺）

工作流会提前查这两条，不合规就**整体失败并点名哪个包**，manifest 一个字不动，线上用户不受影响。

## id 的两种命名，别混

- **版本进 id**（`bge-small-zh-v1.5`）：新版本 = 新组件 id = 新安装目录，老版本可以并存
- **id 不带版本**（`frpc-windows-x64`）：靠 `version` 字段升级，客户端按同 id 比版本号判「可升级」，
  覆盖安装。**这是默认选择** —— 除非真要并存多版本

## 踩坑

- **PowerShell 5.1 读 .ps1 默认按 ANSI**：带中文的脚本必须存成 **UTF-8 带 BOM**，
  否则注释里的中文会乱码到让解析器报 `Array index expression is missing`。
  而 `.nexself-component.json` 反过来，**必须无 BOM**（Rust 的 serde_json 不吃 BOM）。
- 同理 `Get-Content` 读 UTF-8 的 json 会乱码，核对内容用
  `[System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)`。
- `Compress-Archive -Path "dir\*"` **会漏掉点开头的文件**，所以 `.nexself-component.json` 会丢。
  build-component.ps1 用 .NET ZipFile + `Get-ChildItem -Force` 规避了，别图省事换回去。
- raw.githubusercontent 有 CDN 缓存，Actions 跑完客户端可能还要等几分钟才同步得到。

## 相关文档

- 组件系统蓝图：`nexself-pc/.docs/modules/component-store.md`
- 客户端侧校验逻辑：`nexself-pc/src-tauri/src/api/components.rs`
- frpc 组件的来历（为什么从安装包里拿出来）：`nexself-pc/src-tauri/resources/frpc/README.md`
