# 迁移与恢复

优先迁移到另一台 Ubuntu/Linux x86_64 服务器。Linux 插件 .so 无法直接用于 Windows 服务端；在家测试若要复用此套文件，使用 Linux 主机或虚拟机。

1. 新服务器创建 `l4d2` 用户，安装 SSH 公钥，安装 32 位运行库并启用用户 linger。SSH 私钥始终留在本机，不在恢复包里。
2. 用 SteamCMD 安装并校验 App 222860。参考部署脚本的 Windows 资源校验后切回 Linux 流程。此步应在恢复模组前完成。
3. 校验私密恢复包的 SHA256。先解压到 `/home/l4d2/restore-staging` 检查内容，再恢复到 `/home/l4d2` 下对应相对路径。保留 `private_server.cfg` 的 600 权限、目录和文件归属 l4d2。不要把恢复包公开或提交到 Git。
4. 按需重新拉取固定版本上游源码到 `/home/l4d2/l4d2-mod`。私密包包含当前运行插件，源码仓库另包含自定义源码；用匹配的 SourceMod 编译器重新编译。
5. 搜索并替换旧 IP `YOUR_SERVER_IP`：重点是 `jjd_server.sp` 的欢迎页 URL、`apply-customization.py`、myhost/mymotd 地址，以及本地 SSH 配置。修改源码后重新编译。路径若不沿用 `/home/l4d2`，还需修改部署脚本和 systemd 文件。
6. 新 nginx 站点加入 `deploy/nginx-l4d2-location.conf` 的路由。`enable-motd-route.py` 仅适用于默认站点结构符合其断言的环境，先审查再执行。开放 UDP 27015、欢迎页 TCP 80 和实际 SSH 端口。
7. 运行定制配置生成器、`systemctl --user daemon-reload`，启用 `l4d2.service`、`l4d2-motd.service` 与 `l4d2-idle-check.timer`。检查运行进程归属 l4d2。
8. 验证公网查询、欢迎页、管理员、ZoneMod、默认地图、换图及一次空服重启，最后进行真人测试。

基础游戏文件不在轻量恢复包里，需要重新下载。完整系统快照可作为同平台快速恢复手段，但跨云迁移优先使用上述文件与环境重建方式。

在重大配置变更后和服务器到期前各保留一份恢复包，并至少保存两份不同时间点的可用副本。尚未配置自动备份任务。
