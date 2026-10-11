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

- **GitHub Actions**：分支名就是要编的 AOSP 标签，例如 `android-16.0.0_r4`、`android-17.0.0_r1`，推送或在该分支上 Run workflow 即编译对应标签；`main` 默认编 `android17-release`，也可在 Run workflow 里手动填分支或标签。产物在运行页面的 Artifacts 里，附带 `SOURCES.txt` 记录各仓库的提交。`android-*` 分支编译成功后还会自动发布或更新 [Release](https://github.com/cschengliang/winscope-build/releases) `winscope-<分支名>`，附带可直接解压运行的 zip。
- **本地（Linux / WSL）**：
  ```bash
  scripts/fetch_sources.sh android17-release ./aosp
  scripts/build_winscope.sh ./aosp
  # 产物：aosp/development/tools/winscope/dist/prod
  ```
  需要 git、Node 22、Python 3。trace processor 的构建会用 Perfetto 的 `tools/install-build-deps --ui` 自动下载 emsdk、gn、ninja 等工具。

## 运行

产物是静态网页，不能直接双击 `index.html` 打开（浏览器不允许从 `file://` 加载 wasm）。

- **Windows**：解压后双击产物里的 `run_winscope.bat`（需要 Python 3），它会起本地服务并打开浏览器；`adb` 在 PATH 里时还会另开窗口运行 `winscope_proxy.py`，把它打印的 token 填到网页的 Collect Traces 里即可直接从设备抓 trace。
- **其他系统**：`python3 -m http.server -d dist/prod 8080`，再访问 http://localhost:8080 ；抓 trace 另外运行 `python3 winscope_proxy.py`。
