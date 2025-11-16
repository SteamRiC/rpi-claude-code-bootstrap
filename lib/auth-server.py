#!/usr/bin/env python3
import os
import subprocess
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs

SESSION_NAME = os.environ.get('TMUX_SESSION', 'claude-auth')
PORT = int(os.environ.get('AUTH_PORT', '8888'))

HTML_FORM = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Claude Authentication</title>
  <style>
    body {
      font-family: system-ui, -apple-system, sans-serif;
      max-width: 500px;
      margin: 50px auto;
      padding: 20px;
      background: #f5f5f5;
    }
    .container {
      background: white;
      padding: 30px;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    h1 { margin-top: 0; color: #333; }
    input[type="text"] {
      width: 100%;
      padding: 12px;
      font-size: 16px;
      border: 2px solid #ddd;
      border-radius: 4px;
      box-sizing: border-box;
      font-family: monospace;
    }
    button {
      width: 100%;
      padding: 12px;
      font-size: 16px;
      background: #007aff;
      color: white;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      margin-top: 10px;
    }
    button:hover { background: #0051d5; }
    .success { color: #28a745; font-weight: bold; }
    .error { color: #dc3545; font-weight: bold; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Claude Authentication</h1>
    <p>Enter the authentication code from your phone:</p>
    <form method="POST" action="/">
      <input type="text" name="code" placeholder="Authentication code" autofocus required>
      <button type="submit">Submit Code</button>
    </form>
  </div>
</body>
</html>
"""

SUCCESS_HTML = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Authentication Complete</title>
  <style>
    body {
      font-family: system-ui, -apple-system, sans-serif;
      max-width: 500px;
      margin: 50px auto;
      padding: 20px;
      background: #f5f5f5;
    }
    .container {
      background: white;
      padding: 30px;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      text-align: center;
    }
    h1 { color: #28a745; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Code Submitted</h1>
    <p>The authentication code has been sent to Claude.</p>
    <p>You can close this page and return to your terminal.</p>
  </div>
</body>
</html>
"""

class AuthHandler(BaseHTTPRequestHandler):
  def log_message(self, format, *args):
    pass

  def do_GET(self):
    self.send_response(200)
    self.send_header('Content-type', 'text/html')
    self.end_headers()
    self.wfile.write(HTML_FORM.encode())

  def do_POST(self):
    content_length = int(self.headers['Content-Length'])
    post_data = self.rfile.read(content_length).decode('utf-8')
    params = parse_qs(post_data)

    code = params.get('code', [''])[0].strip()

    if code:
      try:
        print(f"Received code: {code[:10]}...", flush=True)
        print(f"Sending to tmux session '{SESSION_NAME}'...", flush=True)

        import time

        subprocess.run(
          ['tmux', 'send-keys', '-t', SESSION_NAME, 'C-u'],
          check=True,
          capture_output=True,
          text=True
        )

        time.sleep(0.2)

        result = subprocess.run(
          ['tmux', 'send-keys', '-t', SESSION_NAME, '-l', code],
          check=True,
          capture_output=True,
          text=True
        )

        time.sleep(0.3)

        result = subprocess.run(
          ['tmux', 'send-keys', '-t', SESSION_NAME, 'Enter'],
          check=True,
          capture_output=True,
          text=True
        )

        print(f"Code sent successfully", flush=True)

        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(SUCCESS_HTML.encode())

        sys.exit(0)
      except subprocess.CalledProcessError as e:
        self.send_response(500)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(f'Error: {e}'.encode())
    else:
      self.send_response(400)
      self.send_header('Content-type', 'text/plain')
      self.end_headers()
      self.wfile.write(b'Error: No code provided')

def main():
  server = HTTPServer(('0.0.0.0', PORT), AuthHandler)
  print(f"Auth server listening on port {PORT}", flush=True)
  try:
    server.serve_forever()
  except KeyboardInterrupt:
    pass

if __name__ == '__main__':
  main()
