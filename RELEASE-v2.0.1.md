# v2.0.1 维护者公告与配置加载修正

- 欢迎页顶部、进服聊天、定时公告统一显示“服务器维护者:QQ 3389141”，保留 `!commands` 提示。
- 修正 v2.0.0 安装器将部分 `confogl_addcvar` 写在 `shared_settings.cfg` 之后的问题。该文件执行 `confogl_setcvars` 后拒绝追加，导致旧生还 MVP 自动摘要仍为开启；现在四项玩家配置在锁定前统一注册。
- 回归脚本新增检查 `sm_survivor_mvp_enabled=0`、`jjd_progress_interval=30`、`jjd_round_report=1`。
- 新增公开发现与到期迁移方案：实际 Steam 主服务器已收录，外网 A2S 查询通过；公开化建议尚未执行，未更改服名、搜索键、标签或区域。
- `jjd_server` 1.2.1，`jjd_player_info` 1.0.1；v2.0.0 标签保留原提交。

验证：两个更新插件编译通过；空服引擎回归通过，正式进程确认旧 MVP 自动摘要=0、路程间隔=30、双方报告=1、Tank 人选全服广播=0，公告 HTTP 内容正确；没有新增 SourceMod 错误日志。多人客户端视听体验仍待真人复核。
