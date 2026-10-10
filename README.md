# winscope-build

用 GitHub Actions 编译 AOSP 的 [Winscope](https://android.googlesource.com/platform/development/+/refs/heads/main/tools/winscope/)（WindowManager / SurfaceFlinger / Transitions / ProtoLog / IME / ViewCapture 等 trace 查看工具），不需要 `repo sync` 整个 AOSP。

## 依赖的仓库

Winscope 按 AOSP 目录结构用相对路径引用其他仓库，`scripts/fetch_sources.sh` 只稀疏拉取这些部分，并按原结构摆放：

| 路径 | 仓库 | 用途 |
|---|---|---|
| `development/tools/winscope` | `platform/development` | Winscope 源码 |
| `frameworks/base/core/proto`、`libs/WindowManager/Shell/proto` | `platform/frameworks/base` | WindowManager、IME、Shell transition 的 trace proto 及其 import |
| `frameworks/libs/systemui/viewcapturelib/.../proto` | `platform/frameworks/libs/systemui` | ViewCapture proto |
| `frameworks/proto_logging/stats/enums` | `platform/frameworks/proto_logging` | view 相关 proto 引用的枚举 |
| `external/perfetto`（完整） | `platform/external/perfetto` | SurfaceFlinger/transactions/ProtoLog/input/transition proto，以及 trace processor（wasm）和它生成的 TS proto |

`google/protobuf/descriptor.proto` 由 protobufjs 自带。所有仓库使用同一个分支或标签（`AOSP_REF`），否则 proto 可能对不上。

## 使用

- **GitHub Actions**：Actions → Build Winscope → Run workflow，填 AOSP 分支或标签（默认 `main`）。产物在运行页面的 Artifacts 里，解压后是 `dist/prod`，附带 `SOURCES.txt` 记录各仓库的提交。
- **本地（Linux / WSL）**：
  ```bash
  scripts/fetch_sources.sh main ./aosp
  scripts/build_winscope.sh ./aosp
  # 产物：aosp/development/tools/winscope/dist/prod
  ```
  需要 git、Node 20、Python 3。trace processor 的构建会由 Perfetto 的 `tools/install-build-deps --ui` 自动下载 emsdk、gn、ninja 等工具。

## 运行

`dist/prod` 是静态网页，用任意静态服务器打开，例如 `python3 -m http.server -d dist/prod 8080`，再访问 http://localhost:8080 。从设备直接抓 trace 需要配合 `winscope_proxy.py`（也在产物里）。
