#!/bin/bash
# hermes gateway launcher
export PATH=/root/.local/bin:/root/.hermes/tools/uv-0.12.3-linux-x64:$PATH
cd /root
exec hermes gateway run --external-supervisor --no-supervise >> /root/.hermes/gw.log 2>&1
