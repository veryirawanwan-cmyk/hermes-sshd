#!/bin/bash
# Entrypoint: start sshd + ttyd, restore/persist hermes state in /data volume, then run gateway
set -m

echo "[entrypoint] Starting SSH server..."
/usr/sbin/sshd

echo "[entrypoint] Starting ttyd on :7681..."
ttyd -p 7681 bash &
TTYD_PID=$!

mkdir -p /data

# ---- hermes state persistence via /data volume ----
# hermes program lives in /root/.hermes (3GB, rebuildable).
# State (config, memories, sessions, kanban) is kept as /data/state.tar.gz so a
# container restart never loses it on a free plan (volume capped at 500MB).

export PATH=/root/.local/bin:$PATH

# 1) restore state if we have a saved copy and hermes has no live profile yet
if [ ! -f /root/.hermes/config.yaml ] && [ -f /data/state.tar.gz ]; then
  echo "[entrypoint] Restoring hermes state from /data..."
  mkdir -p /root/.hermes
  tar xzf /data/state.tar.gz -C /root/ 2>/dev/null || echo "[entrypoint] partial restore (state dirs)"
  echo "[entrypoint] state restore done"
fi

# 2) automatic state back-up after gateway exits / periodically handled below.
#    We prune noisy logs from the tarball to keep it small.

# backup function (run once hermes exists — see watchdog below)
backup_hermes() {
  [ -d /root/.hermes ] || return 0
  cd /root/.hermes
  tar czf /data/state.tar.gz \
    --transform 's|^|.hermes/|' \
    config.yaml auth.json SOUL.md channel_directory.json gateway_state.json \
    memories sessions skills plugins cron profiles logs state.db shared-state.db kanban.db \
    kanban.db-shm kanban.db-wal 2>/dev/null
  echo "[entrypoint] state backed up to /data/state.tar.gz $(du -h /data/state.tar.gz | cut -f1)"
}

# 3) bootstrap hermes if missing
if [ ! -d /root/.hermes/hermes-agent ]; then
  echo "[entrypoint] Installing hermes (first boot)..."
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh 2>/dev/null | bash \
    || echo "[entrypoint] hermes install failed (will retry next boot)"
  echo "[entrypoint] install done"
fi

# 4) run gateway, then snapshot state back to /data
if command -v hermes >/dev/null 2>&1 || [ -x /root/.hermes/hermes-agent/hermes_cli/hermes ]; then
  echo "[entrypoint] Starting hermes gateway..."
  bash /root/hermes-gw.sh &
  GW=$!
  # watchdog: snapshot when gateway exits (redeploy/restart), then go again
  while kill -0 $GW 2>/dev/null; do sleep 30; done
  echo "[entrypoint] gateway exited, saving state..."
  backup_hermes
else
  echo "[entrypoint] hermes binary missing, skipping gateway"
fi

# keep ttyd alive
wait $TTYD_PID
