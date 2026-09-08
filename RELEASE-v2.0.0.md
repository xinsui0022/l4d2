# 交界地 v2.0.0 · 玩家信息与半场结算

2026-09-09。基于现有 ZoneMod 2.9.1b 和本服定制功能的完整源码版本。

## 玩家功能

- `!commands` / `!cmds`：分页查询目前加载的 SourceMod `!` 命令，按权限过滤，常用命令提供中文说明。选择条目只显示说明。部署时扫描源码生成内部命令排除表；新加插件后重新执行安装脚本可刷新该表。
- 进服聊天、每 180 秒的公告和欢迎页顶部均提醒使用 `!commands`。
- 路程每 **30 秒**自动播报一行：最前生还进度、Tank 流程或当前状态。准备、暂停、回合结束、无人时不播报。`!progress` 可随时查询；配置 `jjd_progress_interval 0` 可关闭。百分比是导航流程，不是计分距离；导演缓冲可能让实际刷克提前。
- 待变克名单设为 `tankcontrol_print_all 0`：感染者与旁观者保留提示，生还者看不到人选。出生后已经成为 Tank 的提示沿用原模式。
- 无声猴在已加载的 Unsilent Jockey 0.8 上做维护：实体化或骑乘结束后立即补声音，随后每 2 秒一次；增加存活、阵营、职业、灵魂、骑乘检查，以及断线和换图清理。使用原版空间声音和声级，不叠加第二个声音插件。
- 每小关的**每个半场结束**均显示双方真人结算，避免第二半场覆盖第一半场；`!roundstats` / `!lvp` 可查当前半场。复用 `l4d2_playstats` 的统计数据，不修改累计贡献积分。

## 结算口径

| 阵营 | 每人显示 | MVP | LVP |
|---|---|---|---|
| 生还 | 对普通特感伤害、打克伤害、小丧尸击杀、造成/受到友伤 | 普通特感伤害最高 | 对队友友伤最高；无友伤不标 |
| 感染 | 对站立生还伤害（含克）、其中克伤、倒地伤害、喷中人数 | 站立生还伤害最高 | 最低；全员相同或仅一人时不标 |

并列均标。只展示本半场真人数据，包含中途加入/退出；数值不代表综合水平。感染者友伤沿用 ZoneMod 禁用规则。统计继承 ZoneMod 的归因和伤害口径；例如 Boomer 喷后丧尸伤害按上游归因，倒地伤害与站立伤害分开。原生还自动聊天摘要关闭，详细控制台统计保留，避免重复刷屏。`!rank` 仍为累计积分，已有 `!stats` 同时被原统计与积分插件注册，建议分别用 `!roundstats` 和 `!rank`。

## 一键添加管理员

Windows 将 `add-server-admin.cmd`、`add-server-admin.ps1` 放在私有 `ssh_config_l4d2` 旁，双击 CMD 并粘贴 `https://steamcommunity.com/profiles/7656.../`，或输入 17 位 SteamID64。

默认添加 **最高管理员权限 `99:z`**。脚本校验 SteamID、转换为 Steam2，保留其他管理员，避免重复，并备份原文件到云端 `~/admin-backups/`；随后调用 `sm_reloadadmins`，无需重启。

```powershell
# 仅预览转换和权限，不修改服务器
.\add-server-admin.ps1 -Profile 'https://steamcommunity.com/profiles/76561199191371037/' -DryRun
```

不支持 `/id/自定义名称` 链接。实际 SSH 凭据与管理员配置不在 GitHub。刷新失败时脚本会明确提示“文件已保存、权限未实时刷新”，服务恢复后执行 `sm_reloadadmins` 即可；旧文件可从上述备份目录还原。

## 部署与验证

沿用 README 的构建和应用步骤。`build-plugins.sh` 已纳入新增插件，`apply-customization.py` 已调用 `install-player-update.py`，恢复到新云服务器时也会应用。模式启用期间不热重载插件；确认空服后重启。

自动验证：四个更新插件编译通过（仅现有 SDK 的 CreateDialog 弃用警告）；空服实际引擎检查通过命令注册/权限标志/内部命令排除、Jockey 原生生成与状态清理、半场重复结算保护、伤害字段拆分、并列及无友伤分支；管理员转换、非法输入拒绝、重复执行和其他条目保留通过。Windows → SSH → 云端管理员脚本的 DryRun 已实测。

`deploy/test-player-update.py` 使用临时测试插件和统计夹具，最终恢复正式插件。测试不写积分库，不授予新账号管理员。它验证报告与生命周期逻辑，不能代替多人真实伤害过程或客户端画面/声音体验；需要真人复核无声猴、聊天显示与 30 秒自动播报观感。

保留既有已知问题：管理员手动刷克的二控尚未解决，本次未改 Tank 控制逻辑。完整私有恢复包另存云端，不作为公开 Release 附件。

## 上游与版本

- `jjd_player_info` 1.0.0、`jjd_server` 1.2.0。
- Unsilent Jockey 0.8-jjd2；Player Statistics 1.1.4-jjd2，附本服 `jjd_round_report.inc`。
- 两个上游插件均来自已安装的 [L4D2-Competitive-Rework](https://github.com/SirPlease/L4D2-Competitive-Rework)，保留作者信息；其原始快照与维护差异随本次源码提交可审查。
