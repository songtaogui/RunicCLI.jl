1. Documents

2. lazy command handler 支持
    - DSL 层声明某子命令对应模块/函数
    - RunicCLI 自动在 dispatch 时延迟加载并 invokelatest
    - 用户不用手写模板代码
3. build/generate 模式
    - 把 DSL 编译为纯函数文件（或最小 runtime + 生成代码）
    - 支持增量（hash）更新
4. 官方 PackageCompiler 集成
    - 提供 create_sysimage 的推荐配置脚本
    - 一键生成“help 快速响应”的二进制/启动器