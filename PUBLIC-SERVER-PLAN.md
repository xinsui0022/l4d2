# 交界地：公开可发现方案与到期迁移

2026-09-09，方案文档；本次只部署维护者公告与配置修正，尚未应用下述公开化配置建议。

## 已核查的状态

- Steam 官方 `ISteamApps/GetServersAtAddress/v0001` 查询已返回本服：appid=550、secure=true、lan=false、region=255。说明已被 Steam 主服务器收录。
- 从管理员电脑的外网发起 A2S_INFO 查询成功：服名“交界地”、8 人位、无密码、VAC 开启。
- `sv_lan=0`、`sv_allow_lobby_connect_only=0`、`sv_steamgroup_exclusive=0`。
- `sv_search_key` 当前非空，是本服专用大厅匹配键；`sv_tags` 当前为 `confogl,gravity`；`sv_steamgroup` 为空。
- 主服务器收录、外网查询、真实客户端列表刷新/筛选、多人连接分别是不同验证步骤。前两项通过；尚未在一个陌生玩家的客户端验证列表展示和加入。

## 建议路线

第一阶段先做好 `openserverbrowser` 的 Internet/互联网列表，最符合“不用预先知道 IP，能按服名找到并加入测试”的目标。保留竞技模式和真实人数，清楚标注测试服。

建议对主配置与配置生成器同时维护以下值（供实施时使用，本次未应用）：

```cfg
hostname "[CN] 交界地 | ZoneMod药抗4v4 | 测试服"
sv_lan 0
sv_password ""
sv_allow_lobby_connect_only 0
sv_steamgroup_exclusive 0
sv_region 4
sv_tags "jiaojiedi,zonemod,versus,test"
```

地域 4 对应亚洲，当前 255 是不限地域；实施时核对当前引擎值和客户端筛选。模式可能自动追加 `confogl` 等标签，应保留这些真实标记。修改 `hostname` 时也要调整 `apply-customization.py`，否则下次应用配置会恢复旧服名。

保持现有 UDP 27015 的外网游戏/查询连通及 Steam 出站连接。公网 TCP 27015 的 RCON 不是浏览列表所需；管理仍走 SSH。无需为了被搜到而关闭 VAC，也不需要安装伪造人数或刷列表插件。

验收：用另一网络、未收藏本服的正版客户端打开控制台，输入 `openserverbrowser`；选 Internet/互联网，游戏为 Left 4 Dead 2，允许空服、放宽延迟限制，取消不合适的地图/密码/区域过滤。按服名查找“交界地”，或在支持标签过滤的界面用 `jiaojiedi`，并尝试实际加入。不应把“收藏中通过 IP 添加成功”当作公开列表验收。

第二阶段如希望陌生大厅也自动匹配进来，再清空 `sv_search_key`，测试“最佳可用专用服务器”。非空键限制大厅选择与浏览列表收录是不同机制。ZoneMod 是修改模式，玩家的模式、延迟、标签及大厅条件都会影响匹配，清空键不能保证随机匹配流量，也不会变成 Valve 官方服务器。

第三阶段可创建自己的 Steam 社区组并关联 `sv_steamgroup`，保留 `sv_steamgroup_exclusive=0`。这能为组员提供另一个入口，并不保证所有陌生人的游戏主页都会显示本服。需要先有真实的组 ID，不能随意填写他人组。

公告已改为“服务器维护者:QQ 3389141”，出现在欢迎页顶部、进服聊天和定时公告，保留命令查询提示。玩家报告时最好提供地图、小关、双方半场、发生时间和复现步骤。

## 游戏文件怎样备份

| 内容 | 保存方式 | 恢复时怎么用 |
|---|---|---|
| 自定义源码、部署/恢复脚本、版本说明 | GitHub | 获取对应版本，审查和重建定制功能 |
| 实际插件二进制、配置、管理员/封禁、积分 SQLite、欢迎素材、脚本、匹配编译器 | 私有 `jiaojiedi-full-*.tar.gz` 和同名 JSON 清单 | 校验 SHA256 后恢复到新安装的游戏上 |
| 官方基础游戏 | 当前服务器安装目录约 9.4 GiB；当前恢复包不含本体 | 用 SteamCMD 重新下载 dedicated server App 222860 |

定制恢复包当前约 61 MB，包含数据库一致性快照，云端每天生成、保留最近 30 个。文件名里的 `full` 指完整定制恢复包，不是整个云硬盘镜像。电脑自动同步此前被用户暂停；仅在旧云同一硬盘保存包不能抵御实例被回收，必须有电脑或独立存储副本。本次收尾会手动同步一次，不恢复定时任务。

如果要求彻底不依赖未来 Steam 下载，额外保存一份基础安装目录的离线归档或云磁盘快照。它更大，且未来游戏更新可能需要相应升级；通常“可重新下载的本体 + 已验证私有恢复包”已经足够。新增的非官方地图/素材应明确纳入恢复包；目前是官方地图服。

## 云到期前怎么处理

建议预留 3–7 天迁移窗口（工作安排建议，不是云厂商保留期保证）。原机续费一般无需搬家；若换云，先开新机并恢复验证，再停旧机做最后一次增量数据截止。

1. 在旧云仍可登录时获取完整包和 JSON 清单，保存到电脑，核验 SHA256。到期前最后一次结算完成后停止旧服写入，再生成最终包，避免迁移期间新积分落在旧机。
2. 新云准备 Ubuntu 22.04 x86_64，运行 `deploy/bootstrap-server.sh` 安装环境、SteamCMD 和官方基础游戏；配置游戏用户 SSH 公钥。
3. 上传恢复包和清单，以游戏用户运行 `restore-server.py --verify-only`；通过后以 `--new-ip` 正式恢复、重编译和启动。
4. 新云配置 UDP 27015、欢迎页 HTTP 和实际 SSH 端口；更新本机 SSH 地址，核对新主机指纹。验证管理员、积分、插件、公告及真人对局。
5. 确认新服运行且电脑保有最终包后再停用旧云。IP 可能变化，玩家旧收藏需更新；可用域名作为额外长期入口，但不能假定已有收藏自动跟随域名变化。

已做过隔离解包、SQLite 与核心文件验证；尚未在第二台新云完成从游戏下载到多人对局的完整迁移演练。旧云已回收且没有异地数据副本时，GitHub 只能重建源码和模板，无法找回丢失的积分/实际私有配置。

资料：[Steam 服务器浏览器](https://partner.steamgames.com/doc/features/multiplayer/game_servers)、[按地址查询主服务器收录](https://partner.steamgames.com/doc/webapi/ISteamApps#GetServersAtAddress)、[SteamCMD 专用服务器分发](https://partner.steamgames.com/doc/features/multiplayer/game_servers#5)。配置现状以上述实际服务器查询为依据。
