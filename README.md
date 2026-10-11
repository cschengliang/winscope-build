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

产物是静态网页，不能直接双击 `index.html` 打开（浏览器不允许从 `file://` 加载 wasm），需要先起一个本地服务：

- **Windows**：解压 [Releases](https://github.com/cschengliang/winscope-build/releases) 里的 zip，双击 `run_winscope.bat`（需要 Python 3）。它会在 8080 端口起本地服务并用浏览器打开 Winscope（换端口：`run_winscope.bat 9000`）。
- **其他系统**：在解压目录里运行 `python3 -m http.server 8080`，再访问 http://localhost:8080 。

## 使用教程：用 Web Device Proxy 连接设备抓 trace

Web Device Proxy（WDP）是 Google 提供的本地小程序，Winscope 网页通过它（`ws://localhost:9167`）调用电脑上的 adb 和设备通信，是 Winscope 首页推荐的连接方式。

1. **准备设备**：手机打开 USB 调试并连上电脑（或启动模拟器），确认 `adb devices` 能看到它、状态是 `device`。
2. **安装 WDP**：从 [Android Web Device Proxy 下载页](https://tools.google.com/dlpage/android_web_device_proxy) 下载安装并保持运行。
3. **打开 Winscope**：用 Chrome 或 Edge 打开上面起好的本地页面，左侧 **Collect Traces** 选 **Web Device Proxy (Recommended)** 标签页。如果提示 "Web Device Proxy doesn't seem to be running"，确认 WDP 已启动后点 **Retry**。
4. **授权**：第一次连接时 WDP 会弹窗请求允许当前网址（`http://127.0.0.1:8080`）访问，设备也可能需要单独授权。请允许浏览器弹窗并在弹出页里批准，然后点 **Retry**。换了端口或网址需要重新授权。
5. **选设备**：连上后会显示设备名（例如 `Android SDK_Tablet_for_x86_64 (emulator-5554)`），多台设备时用 **Change device** 切换。
6. **抓 trace**：在 **Trace** 页勾选要抓的目标（IME、Input、Surface Flinger、Transactions、Window Manager、Screen Recording 等，带齿轮图标的可以点开调整配置），点 **Start trace**，在设备上复现问题后点 **End trace**。Winscope 会自动把 trace 拉回来并打开。只想看某一时刻的状态，就用 **Dump** 页的 **Dump state**。
7. **之后再看**：**Fetch traces from last session** 可以重新拉取上一次的 trace；也可以把已有的 trace 文件、zip 或 bugreport 直接拖进右侧 **Upload Traces**。

![Collect Traces：通过 Web Device Proxy 连接模拟器并选择 trace 目标](docs/images/collect-traces-wdp.png)

抓完后进入查看界面：顶部切换 Surface Flinger、Window Manager、Input、IME、Transactions 等视图，左侧是图层的 3D 示意，中间是层级树，右侧是选中图层的属性和 proto 原始数据，底部时间轴可以逐帧拖动，并和屏幕录像同步。

![查看 Surface Flinger trace：图层 3D 视图、层级树、属性面板和时间轴](docs/images/surfaceflinger-viewer.png)

> 另一个标签页 **Winscope Proxy** 是旧的连接方式：先运行产物里的 `python winscope_proxy.py`（`run_winscope.bat` 检测到 adb 时会自动另开窗口启动它，监听 5544 端口），再把它打印的 token 填进网页。用 WDP 时可以不管它。
