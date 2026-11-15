# 开发与验证

验证环境：macOS Apple Silicon，Godot 4.7.2。其他系统和 Intel Mac 尚未验证，原生组件目前仅配置 macOS arm64。

1. 安装 Godot 4.7.2 和 Xcode Command Line Tools。
2. 在仓库根目录编译原生组件：

```sh
xcrun clang -dynamiclib -fobjc-arc -arch arm64 -mmacosx-version-min=12.0 -framework Cocoa native/cozy_lifecycle.m -o project/native/libcozy_lifecycle.dylib
codesign --force --sign - project/native/libcozy_lifecycle.dylib
```

3. 用 Godot 编辑器导入 `project/project.godot`，等待资源导入结束后运行。
4. 如需本地应用包，将 Godot.app 放在 `tools/` 后执行 `python3 build_app.py --output-dir build`。这一打包步骤已在本机完成，并从生成的应用启动验证。应用包不是签名公证后的发行包。

## 模型与隐私

无模型配置时使用本地逻辑。打包脚本将模型 CLI 路径留空，避免默认接入本机登录。不要为了分享程序而复制登录文件。启用连接前需理解桥接会向所配置服务发送哪些世界上下文。

公开版使用独立应用名和数据目录；模型运行配置、存档及输出不得提交。

## 已执行检查

- 原生组件编译成功；独立测试工程导入并进入主场景，输出 READY 和 EXIT。
- 24 项 Python 模型桥接模拟测试通过；测试使用假 CLI，不请求真实模型。
- 信箱线程测试通过，验证草稿准备与寄出后回复状态。

无界面测试不代表视觉、帧率或所有生活行为验收通过。

## 贴图来源与复现

`python3 tools/generate_public_textures.py` 生成外部木纹和两个石砖目录图标；`python3 tools/rebuild_embedded_textures.py` 替换餐椅及长凳中的内嵌纹理。均不读取外部参考图片。模型网格、节点和非图片缓冲区与原始资产逐项比对一致。

图片通过 Godot 资源加载；打包时先导入资源，再携带运行所需的导入缓存。此前的三条图片加载警告已消除。

## 验证范围与限制

已从本机打包应用完成无界面启动退出和图形界面近景截图。未在其他机器验证，未进行长期生活回归测试，未进行标准 PCK 导出验证，应用没有 Apple 开发者签名与公证。本次拟公开的是源码，不是对外发布安装包。
