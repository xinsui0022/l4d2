> 本公开仓库使用脱敏模板。首次部署前请替换 YOUR_SERVER_IP、YOUR_STEAM64、YOUR_ACCOUNT_ID，并核对 Linux 用户与路径；实际服务器配置和恢复包保留在私有本地目录。

# 交界地 · L4D2 ZoneMod 服务端配置

本仓库管理自定义 SourcePawn 插件、欢迎页与 Ubuntu 部署脚本。游戏基础文件、第三方插件整包及任何密码均不放进 Git。

基础：Ubuntu 22.04 x86_64、SourceMod 1.12、ZoneMod 2.9.1b、100 tick、4v4。上游固定提交见 `deploy/fetch-zonemod.sh` 与部署记录。

自定义功能：
- C2 默认启动图；整场结束默认开启 C5 新局并清零比分。
- `!vote` 选择战役、下一场和重开；`!admin` 管理权限。
- Tank 开场 10 秒内弹出队友／随机／自己玩菜单，每秒刷新倒计时；拳击对生还者造成伤害或投出任意石头后立即关闭；一次主动交接，保留血量和怒气。
- 仅 root 管理员可以 `!spawntank` 瞄准地面刷克、`!taketank` 接管 AI Tank。
- 独立后台脚本处理空服连续 30 分钟后的一次性重启。

## 维护

服务器运行用户与路径为 `/home/l4d2`。脚本使用服务器地址与管理员 Steam ID 占位符；部署或迁移前按 [RESTORE.md](RESTORE.md) 修改。

已有基础服务时：将 `custom/`、`deploy/` 同步到 `/home/l4d2/`，运行 `bash /home/l4d2/deploy/build-plugins.sh`，再执行 `python3 /home/l4d2/deploy/apply-customization.py`。确认空服后重启 `systemctl --user restart l4d2`。

**不要在正在使用的服务器上直接运行首次安装脚本。** `prepare-base.sh` 和 `configure-zonemod.py` 面向初次安装/受控升级。

## Git 不等于完整备份

GitHub：源码、配置生成器、版本与恢复说明。

本地私密恢复包：实际 addons/cfg/scripts、管理员与封禁数据、RCON 配置、用户服务和欢迎素材。运行 `build-restore-bundle.py` 后下载到本地 `backups/`，并校验 SHA256。该目录已忽略，不提交、不做 GitHub Release 附件。

上游项目：
- https://github.com/SirPlease/L4D2-Competitive-Rework
- https://github.com/SilvDev/Left4DHooks
- 传克行为参考调研：https://github.com/raziEiL/l4d_tank_pass 。本服使用独立的 `jjd_tank_tools`，不叠加安装上游 Tank Pass。

权限边界：SourceMod 命令注册和内部检查均要求 root 权限才允许刷克；普通玩家只能操作自己的开场传克菜单。服务端测试不能替代真人多客户端实测。


## 积分、自动备份与新云恢复

已加入 SQLite 贡献排行（!rank / !top / !stats）、每日完整备份、Windows 登录后/每小时主动同步，以及新云安装与恢复脚本。详细规则、使用方式和边界见 [STATS_AND_RECOVERY.md](STATS_AND_RECOVERY.md)。

## 2026-09-08：轮廓、Tank 预告与娱乐投票

- 生还者达到本服黑白状态且仍站立存活时，感染者可见蓝色轮廓。恢复正常、死亡或换队后移除；不修改生还者自己的原生轮廓。
- ZoneMod 后退冻结保留原规则：最靠前生还者每后退 7% 地图流程，增加 4 秒怒气冻结。实际触发时聊天提示增加秒数，一次跨多个档位会累计。
- `!tankline`：查看 Tank 预告说明。仅感染者和旁观者接收白色预计流程边界和淡蓝预测区域模型，生还者不接收。位置来自当前回合刷克流程参数与导航网格；最终出生点由导演决定，模型不是已确定的出生坐标。剧情／救援 Tank 和无法获得有效流程参数的地图不显示。本功能不能保证在所有地图复刻 C2 改的固定出生点。
- `!vote` 新增暴雨、装饰头饰和关闭娱乐效果。沿用参赛真人严格过半、20 秒投票、60 秒冷却。
- 娱乐功能默认关闭；投票通过后本章节标记为练习，停止排行计分。即使关闭效果，本章节也不恢复计分；换到下一章节重置。娱乐状态在同一章节的配置重载后保留。
- 暴雨为视觉降雨，不修改武器数值，不附加伤害雷击。头饰使用游戏自带小矮人和交通锥，`!hat` 选择或摘下；无碰撞，自己的第一人称和跟随自己的第一人称旁观不显示头饰。
- 云端每日恢复包继续生成；电脑的 `Jiaojiedi-Private-Backup-Sync` 计划任务目前已停用。双击本地 `enable-backup-sync.cmd` 即可恢复登录后／每小时同步，并立即同步一次。需要迁移前仍应获取最新完整包。

实现：`jjd_visuals`、`jjd_fun`、`jjd_server` 1.1.0，以及保留作者署名的 `l4d2_tankrage` 1.0.3-jjd1 小改版。`install-features.py` 纳入日常部署和新云恢复；不叠加第二个 Tank 怒气插件。此前管理员刷克只有一控的已知问题不在本次修改范围内，仍需单独实战验收。
