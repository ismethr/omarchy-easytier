# Omarchy EasyTier

[简体中文](README.md) · [MIT License](LICENSE)

A native EasyTier widget for Omarchy's Quickshell bar, with a Chinese status panel, peer list and service controls. Tested on **Omarchy 4.0.4 and EasyTier 2.6.4**.

Plugin ID: `wdleo.easytier`. An independent community project, not an official EasyTier or Omarchy component.

## Features

- Service status, virtual IP, shared subnets and boot autostart status.
- Remote peers, direct/relay connections and latency; the local node is excluded.
- Left click for details, right click to start/stop, middle click to copy the local IP.
- Click a peer to copy its IP; refresh, reconnect and live journal buttons.
- Panel shortcuts: `T` toggle, `R` refresh, `C` copy IP, `Esc` close.
- Native theme colors and controls; scrollable peer list.

## Requirements

- Omarchy with Quickshell and `omarchy plugin`; older Waybar setups are unsupported.
- A configured system service named **`easytier.service`**, with `easytier-core` and `easytier-cli` installed.
- EasyTier RPC at **`127.0.0.1:15888`** (the CLI default).
- Python 3.9+, systemd and polkit. Clipboard actions use `wl-copy`; the journal button uses `xdg-terminal-exec`.

Install prerequisites and configure **your own** network first:

```bash
omarchy pkg add easytier-core easytier-cli wl-clipboard
sudoedit /etc/easytier/config.toml
sudo chmod 600 /etc/easytier/config.toml
sudo systemctl enable --now easytier.service
easytier-cli peer
```

See the [EasyTier documentation](https://easytier.cn/en/guide/network/config-file.html) for network configuration.

## Install

```bash
omarchy plugin add https://github.com/ismethr/omarchy-easytier --enable
# Optional placement:
omarchy plugin enable wdleo.easytier --section right --before omarchy.network
```

Status works without an extra permission rule. For passwordless controls, review and install the optional rule for **your desktop account**:

```bash
python3 "$HOME/.config/omarchy/plugins/wdleo.easytier/scripts/setup-permissions" install --user "$USER" --dry-run
sudo python3 "$HOME/.config/omarchy/plugins/wdleo.easytier/scripts/setup-permissions" install --user "$USER"
```

The rule permits only `start`, `stop` and `restart` of `easytier.service` for the selected local account. It does not grant configuration changes, unit-file changes or control over other services. Polkit reloads rules automatically.

## Settings

Set the polling interval in the bar entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "wdleo.easytier", "pollSeconds": 5 }
```

The interval is clamped to 3–60 seconds; an open panel refreshes every 3 seconds.

The switch controls the current service state and preserves boot autostart. Manage autostart separately with `sudo systemctl enable easytier.service` or `sudo systemctl disable easytier.service`.

## Update / uninstall

```bash
omarchy plugin update wdleo.easytier
```

Remove the optional permission rule before removing the plugin:

```bash
sudo python3 "$HOME/.config/omarchy/plugins/wdleo.easytier/scripts/setup-permissions" remove
omarchy plugin remove wdleo.easytier
```

EasyTier, its configuration and boot autostart are preserved. Replaced or removed rules are backed up under `/var/backups/omarchy-easytier/`.

## Troubleshooting / privacy

Check `systemctl status easytier.service`, `easytier-cli peer` and `journalctl -u easytier.service`. For control errors, install the rule for the correct desktop user; for RPC errors, check the default localhost endpoint.

The adapter emits only allowlisted fields. EasyTier's `node info` includes its full configuration, but the widget never receives its network secret, network name or STUN details. No real network configuration or private peer data is included. Redact secrets from bug reports; do not paste complete `node info` output.

## Development

```bash
python3 -m unittest discover -s tests -p 'test_*.py' -v
node tests/test_policy.js
omarchy plugin validate .
```

Tests cover privacy, stopped/unavailable states, local peer exclusion, invalid actions, policy scope, and permission-rule preview, installation, backups and removal. UI changes also require a live Omarchy check. Contributions via issues and pull requests are welcome.
