# rpi-claude-code-bootstrap

Bootstrap script for installing Claude Code with Haiku 4.5 on Raspberry Pi OS Lite.

## Purpose

Installs Claude Code configured with Haiku 4.5 as the default model for cost-effective AI assistance in terminal.

## Requirements

- Raspberry Pi OS Lite (Debian 12 Bookworm)
- Fresh installation recommended
- Internet connection
- Keyboard and monitor or SSH access

## Installation

```bash
sudo apt install -y git
git clone https://github.com/SteamRiC/rpi-claude-code-bootstrap.git
cd rpi-claude-code-bootstrap
bin/1_setup.sh
```

## Authentication

After installation completes, authenticate with Claude:

```bash
bin/2_auth.sh
```

Scan the two QR codes with your phone to complete authentication.

## License

MIT
