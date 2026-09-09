# v2.0.2 · 公开发现与加入历史

- 公开服名 `[CN] 交界地 | ZoneMod药抗4v4 | 测试服`，亚洲地域 4，增加 `jiaojiedi,zonemod,versus,test` 标签，清空专用大厅匹配键。安装、更新和插件中的服名同步维护。
- 新增 `jjd_join_info`：真人认证加入后，在聊天框显示昵称、隐藏最后一段的 IPv4 和大致地区。IPv6 隐藏地址。使用现有本地 GeoIP 库，无外部定位请求；数据库缺失对应信息时退化为国家或未知。定位不代表实际住址，语言取决于加入者客户端和数据库。
- 私有 SQLite `jjd_visitors.sq3` 记录时间、昵称、Steam ID、完整 IP、地区和地图；目录仅游戏用户可访问，自动纳入完整恢复包。记录从插件启用后开始，不能补回旧访问的地区。
- 双击 `view-server-join-history.cmd` 查看最近 7 天、最多 200 条并持续刷新。一次查询：`powershell -File .\view-server-join-history.ps1 -Once -Days 30 -Limit 1000`；`-Days 0` 查询所有仍保留记录。原访客脚本仍可查询旧引擎日志。

验证：插件编译和加载、GeoIP 扩展加载、空服重启持久化、外网 A2S 新服名、Steam API 亚洲收录、现有管理员/模式/公告检查通过；查询脚本过滤、排序、条数限制和控制字符清理通过。真人聊天展示和互联网列表实际加入仍需客户端验证。编译仅有 SDK 已有的 CreateDialog 弃用警告。
