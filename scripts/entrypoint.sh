#!/bin/bash
# Entrypoint: start sshd + ttyd, then bootstrap hermes (idempotent)
set -m

echo "[entrypoint] Starting SSH server..."
/usr/sbin/sshd

echo "[entrypoint] Starting ttyd on :7681..."
ttyd -p 7681 bash &
TTYD_PID=$!

# Bootstrap hermes if not installed
if [ ! -d /root/.hermes/hermes-agent ]; then
  echo "[entrypoint] Installing hermes..."
  export PATH=/root/.local/bin:$PATH
  # hermes installer (auto-detects)
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh 2>/dev/null | bash || echo "[entrypoint] hermes install failed (non-fatal)"
  echo "[entrypoint] hermes install done"
fi

# Start hermes gateway if hermes binary exists
if command -v hermes >/dev/null 2>&1 || [ -x /root/.hermes/hermes-agent/hermes ]; then
  echo "[entrypoint] Starting hermes gateway..."
  bash /root/hermes-gw.sh &
else
  echo "[entrypoint] hermes not present, skip"
fi

echo "[entrypoint] Container ready."
# keep alive
wait
