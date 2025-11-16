#!/bin/bash
set -e

ASDF_VERSION="v0.18.0"
NODE_MAJOR="24"

echo "========================================="
echo "Claude Code + Haiku Bootstrap"
echo "========================================="
echo ""

if ! command -v qrencode &> /dev/null || ! command -v tmux &> /dev/null; then
  echo "[0/5] Installing dependencies (qrencode, tmux)..."
  sudo apt-get update -qq
  [ ! -x "$(command -v qrencode)" ] && sudo apt-get install -y qrencode
  [ ! -x "$(command -v tmux)" ] && sudo apt-get install -y tmux
else
  echo "[0/5] Dependencies already installed, skipping..."
fi

ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
  echo "Warning: This script is designed for ARM64 architecture."
  echo "Detected: $ARCH"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

if [ -f "/usr/local/bin/asdf" ]; then
  echo "[1/5] asdf already installed, skipping..."
else
  echo "[1/5] Installing asdf..."
  ASDF_TARBALL="asdf-${ASDF_VERSION}-linux-arm64.tar.gz"
  ASDF_URL="https://github.com/asdf-vm/asdf/releases/download/${ASDF_VERSION}/${ASDF_TARBALL}"

  cd /tmp
  wget -q "$ASDF_URL"
  tar -xzf "$ASDF_TARBALL"
  sudo mv asdf /usr/local/bin/
  rm "$ASDF_TARBALL"
fi

if ! grep -q "# asdf v0.18" ~/.bashrc; then
  if grep -q "asdf.sh" ~/.bashrc; then
    echo "Cleaning up old asdf configuration from .bashrc..."
    sed -i "/^# asdf$/,/asdf\.sh$/d" ~/.bashrc
  fi

  echo "" >> ~/.bashrc
  echo "# asdf v0.18+ (standalone binary)" >> ~/.bashrc
  echo 'export PATH="$HOME/.asdf/shims:/usr/local/bin:$PATH"' >> ~/.bashrc
fi

export PATH="$HOME/.asdf/shims:/usr/local/bin:$PATH"

if asdf plugin list | grep -q nodejs; then
  echo "[2/5] Node.js plugin already added, skipping..."
else
  echo "[2/5] Adding Node.js plugin to asdf..."
  asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
fi

if asdf list nodejs 2>/dev/null | grep -q "${NODE_MAJOR}\."; then
  echo "[3/5] Node.js ${NODE_MAJOR}.x already installed, skipping..."
  NODE_VERSION=$(asdf list nodejs | grep "${NODE_MAJOR}\." | tail -1 | tr -d ' *')
else
  echo "[3/5] Installing Node.js ${NODE_MAJOR}.x (this may take a while)..."
  asdf install nodejs latest:${NODE_MAJOR}
  NODE_VERSION=$(asdf list nodejs | grep "${NODE_MAJOR}\." | tail -1 | tr -d ' *')
fi

echo "[4/5] Setting Node.js as current version..."
asdf set nodejs "$NODE_VERSION" --home

if command -v claude &> /dev/null; then
  echo "[5/5] Claude Code already installed, updating..."
else
  echo "[5/5] Installing Claude Code..."
fi
npm install -g @anthropic-ai/claude-code

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"

if [ ! -d "$CLAUDE_DIR" ]; then
  mkdir -p "$CLAUDE_DIR"
fi

if [ ! -f "$CLAUDE_DIR/CLAUDE.md" ] && [ -f "$SCRIPT_DIR/config/CLAUDE.md" ]; then
  cp "$SCRIPT_DIR/config/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  echo "Copied CLAUDE.md to $CLAUDE_DIR"
elif [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  echo "Note: config/CLAUDE.md not found. Run this script from the repository directory."
fi

if [ ! -f "$CLAUDE_DIR/settings.json" ] && [ -f "$SCRIPT_DIR/config/settings.json" ]; then
  cp "$SCRIPT_DIR/config/settings.json" "$CLAUDE_DIR/settings.json"
  echo "Copied settings.json to $CLAUDE_DIR"
elif [ ! -f "$CLAUDE_DIR/settings.json" ]; then
  echo "Note: config/settings.json not found. Run this script from the repository directory."
fi

echo ""
echo "========================================="
echo "Installation complete!"
echo "========================================="
echo ""
echo "Authenticate with:"
echo "  claude setup-token"
echo ""
echo "For QR code authentication, see README.md"
echo ""
echo "Starting new shell session..."
sleep 1

exec bash
