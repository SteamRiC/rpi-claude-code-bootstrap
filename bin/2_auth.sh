#!/bin/bash
set -e

SESSION="claude-auth-manual"
PORT=8888
SERVER_PID=""
CLAUDE_BIN="$HOME/.asdf/shims/claude"

cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill $SERVER_PID 2>/dev/null || true
  fi
  tmux kill-session -t "$SESSION" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Claude Code Authentication Test ==="
echo ""
echo "This script will automatically navigate the auth flow."
echo "You just need to scan two QR codes on your phone."
echo ""
read -p "Press ENTER to start..."

rm -f ~/.claude/.credentials.json

echo ""
echo "Starting Claude in tmux..."
tmux new-session -d -s "$SESSION" "$CLAUDE_BIN"
sleep 3

capture_screen() {
  tmux capture-pane -t "$SESSION" -p -S -100 | grep -v "^$" | tail -20
}

check_for() {
  capture_screen | grep -q "$1"
}

echo "Checking for theme selector..."
if check_for "Choose the text style"; then
  echo "Theme selector found, selecting dark theme..."
  tmux send-keys -t "$SESSION" Enter
  sleep 2
else
  echo "Theme selector not found, continuing..."
fi

echo "Checking for auth method selector..."
if check_for "Select login method"; then
  echo "Auth method selector found, selecting subscription..."
  tmux send-keys -t "$SESSION" Enter
  sleep 4
else
  echo "Auth method selector not found, continuing..."
fi

echo "Extracting OAuth URL..."

OAUTH_URL=""
for i in {1..5}; do
  CONTENT=$(tmux capture-pane -t "$SESSION" -p -S -1000 2>/dev/null || echo "")
  if echo "$CONTENT" | grep -q "https://"; then
    OAUTH_URL=$(echo "$CONTENT" | grep -A5 "https://" | tr -d '\n\r' | grep -o "https://[^ ]*" | head -1)
    break
  fi
  sleep 1
done

if [ -z "$OAUTH_URL" ]; then
  echo "Could not extract OAuth URL. Please check tmux session manually:"
  echo "  tmux attach -t $SESSION"
  exit 1
fi

echo "OAuth URL extracted"
echo ""
echo "========================================="
echo "STEP 1: Scan this QR code"
echo "========================================="
echo ""
echo "$OAUTH_URL" | qrencode -t UTF8
echo ""
echo "URL: $OAUTH_URL"
echo ""
read -p "Press ENTER after you've authenticated..."

export TMUX_SESSION="$SESSION"
export AUTH_PORT="$PORT"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTH_SERVER="$SCRIPT_DIR/lib/auth-server.py"

if [ ! -f "$AUTH_SERVER" ]; then
  echo "Error: Cannot find auth-server.py at $AUTH_SERVER"
  exit 1
fi

echo ""
echo "Starting web server..."
python3 "$AUTH_SERVER" &
SERVER_PID=$!

sleep 2

IP=$(hostname -I | awk '{print $1}')
WEB_URL="http://${IP}:${PORT}"

echo ""
echo "========================================="
echo "STEP 2: Scan this QR to submit code"
echo "========================================="
echo ""
echo "$WEB_URL" | qrencode -t UTF8
echo ""
echo "URL: $WEB_URL"
echo ""
echo "Waiting for code submission..."
echo ""
echo "To watch Claude live, run in another terminal:"
echo "  tmux attach -t $SESSION"

wait $SERVER_PID 2>/dev/null || true

echo ""
echo "Code submitted. Monitoring for completion..."

CREDS_FILE="$HOME/.claude/.credentials.json"
for i in {1..15}; do
  sleep 1

  if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "Claude session ended"
    break
  fi

  if [ -f "$CREDS_FILE" ]; then
    echo "Credentials file created at attempt $i"
    break
  fi

  echo "  Attempt $i: waiting for credentials..."
done

if [ -f "$CREDS_FILE" ]; then
  echo ""
  echo "Handling post-authentication prompts..."
  sleep 2

  if check_for "Press Enter to continue"; then
    echo "  1/2: Acknowledging auth success..."
    tmux send-keys -t "$SESSION" Enter
    sleep 2
  fi

  if check_for "Security notes" || check_for "Claude can make mistakes"; then
    echo "  2/2: Acknowledging security notes..."
    tmux send-keys -t "$SESSION" Enter
    sleep 2
  fi

  echo "Post-auth prompts completed"
  echo ""
  echo "Note: Claude will ask about trusting the folder."
  echo "This is a security decision you should make manually."
fi

echo ""
if [ -f "$CREDS_FILE" ]; then
  echo "Authentication successful!"
  echo "Credentials saved to $CREDS_FILE"
  echo ""
  echo "Testing authentication..."

  if $CLAUDE_BIN --version >/dev/null 2>&1; then
    echo "Claude CLI authenticated and working"
    $CLAUDE_BIN --version
  else
    echo "Warning: claude --version failed"
  fi
else
  echo "Credentials file not created"
  echo "Authentication may have failed"
fi

echo ""
echo "========================================="
echo "Session kept alive for inspection"
echo "========================================="
echo ""
echo "To see what Claude is showing, open another terminal and run:"
echo "  tmux attach -t $SESSION"
echo ""
echo "Press Ctrl+C to cleanup and exit..."
echo ""

trap "echo 'Cleaning up...'; tmux kill-session -t $SESSION 2>/dev/null; exit 0" INT
while true; do
  if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "Claude session ended"
    break
  fi
  sleep 5
done
