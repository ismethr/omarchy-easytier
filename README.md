# Omarchy EasyTier

[English](README.en.md) · [MIT License](LICENSE)

为使用 Quickshell 的 Omarchy 提供 EasyTier 状态栏插件：查看组网状态、虚拟 IP、节点与延迟，并快速启动、停止或重新连接。

插件 ID：`wdleo.easytier`。已在 **Omarchy 4.0.4 + EasyTier 2.6.4** 上验证。
这是社区插件，与 EasyTier、Omarchy 官方无隶属关系。

## 功能

- 状态栏显示运行、连接中和关闭状态；悬停查看状态与组网 IP。
- 中文详情面板：组网 IP、共享子网、开机自启状态。
- 节点列表区分直连和中继，显示延迟；本机不计入远端节点。
- 左键详情、右键开关、中键复制本机 IP；点击节点复制它的 IP。
- 刷新、重连、日志按钮；面板快捷键 `T` 开关、`R` 刷新、`C` 复制 IP、`Esc` 关闭。
- 使用 Omarchy 原生控件和主题颜色，节点列表支持滚动。

## 前提

- 带有 `omarchy plugin` 命令的 Quickshell 版 Omarchy，旧版 Waybar 不适用。
- `easytier-core`、`easytier-cli`，以及已配置的系统服务 **`easytier.service`**。
- Python 3.9+、systemd、polkit；复制功能需要 `wl-copy`，日志按钮需要 `xdg-terminal-exec`。
- EasyTier 本机管理接口 **`127.0.0.1:15888`**，即 CLI 默认地址。

插件负责状态显示和服务控制。请先配置自己的 EasyTier 网络：

```bash
omarchy pkg add easytier-core easytier-cli wl-clipboard
sudoedit /etc/easytier/config.toml
# 填入你自己的组网信息，然后运行：
sudo chmod 600 /etc/easytier/config.toml
sudo systemctl enable --now easytier.service
easytier-cli peer
```

配置方法见 [EasyTier 官方文档](https://easytier.cn/guide/network/config-file.html)。不要使用别人的组网密钥。

## 安装插件

```bash
omarchy plugin add https://github.com/ismethr/omarchy-easytier --enable
# 可选：放到网络图标前面
omarchy plugin enable wdleo.easytier --section right --before omarchy.network
```

状态读取无需额外权限。启用无需重复输入管理员密码的开关，需要为自己的桌面账号安装一条专用权限规则：

```bash
# 先预览规则：
python3 "$HOME/.config/omarchy/plugins/wdleo.easytier/scripts/setup-permissions" install --user "$USER" --dry-run

sudo python3 "$HOME/.config/omarchy/plugins/wdleo.easytier/scripts/setup-permissions" install --user "$USER"
```

规则只允许指定本地账号对 **`easytier.service`** 执行 `start`、`stop`、`restart`，不授予修改配置、修改服务文件或控制其他服务的权限。Polkit 自动加载规则，无需重启。

## 使用与设置

| 操作 | 功能 |
| --- | --- |
| 左键图标 | 打开／关闭详情 |
| 右键图标或面板开关 | 启动／停止当前服务 |
| 中键图标 | 复制本机组网 IP |
| 点击节点 | 复制节点 IP |
| 重连 | 重启 EasyTier 服务 |
| 日志 | 在终端查看服务日志 |

**开关控制当前运行，保留已有开机自启设置。** 自启可独立管理：

```bash
sudo systemctl enable easytier.service   # 开机自启
sudo systemctl disable easytier.service  # 取消开机自启
```

在 `~/.config/omarchy/shell.json` 的状态栏布局条目中设置刷新间隔：

```json
{ "id": "wdleo.easytier", "pollSeconds": 5 }
```

范围为 3–60 秒；面板打开时每 3 秒刷新一次。

## 更新和卸载

```bash
omarchy plugin update wdleo.easytier
```

卸载前先移除可选权限规则，再移除插件：

```bash
sudo python3 "$HOME/.config/omarchy/plugins/wdleo.easytier/scripts/setup-permissions" remove
omarchy plugin remove wdleo.easytier
```

EasyTier 程序、配置和开机自启状态会保留。权限安装器会将它替换或移除的旧规则备份到 `/var/backups/omarchy-easytier/`。

## 排错

- **服务未安装**：检查 `systemctl status easytier.service`，当前版本支持这个标准系统服务名。
- **管理接口未就绪**：检查 `easytier-cli node info`，本机 RPC 应使用默认地址 `127.0.0.1:15888`。
- **开关失败**：检查规则是否为当前桌面账号安装，并查看 `journalctl -u easytier.service`。
- **节点为空**：检查其他节点是否在线，用 `easytier-cli peer` 对照。

## 隐私与开发

适配器只输出明确允许的状态字段。`node info` 含有完整配置，插件会丢弃其中的组网名称、密钥、STUN 信息和其他配置字段。仓库不包含真实组网配置或私人节点数据。提交问题前请移除密钥，不要粘贴完整的 `node info` 输出。

```bash
python3 -m unittest discover -s tests -p 'test_*.py' -v
node tests/test_policy.js
omarchy plugin validate .
```

测试覆盖状态隐私、关闭／RPC 不可用状态、本机节点排除、非法操作拒绝、权限边界，以及权限规则的预览、安装、备份和卸载。界面更改还应在 Omarchy 中验证面板和实际开关。欢迎提交 Issues 和 Pull Requests。
