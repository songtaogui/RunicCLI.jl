# 需要增加的特性
- `@CMD_VERSION`宏绑定`-V, --version`
- 内置常用校验器, 减少 @ARG_TEST 手写）
    -数值：min/max/range
    -集合：oneof/include/exclude
    -字符串：length/prefix/suffix/regex
    -路径：exists/isfile/isdir/readable/writable
    -可组合校验（AND/OR）
- 参数来源: 环境变量退回、配置文件(TOML、YAML、JSON) + CLI覆盖优先级
- 自动补全(bash/zsh/fish)
