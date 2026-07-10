#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$HOME/softwares/ai-cli-complete-notify"
LOG_FILE="$HOME/ai-cli-notify.watch.log"
PID_FILE="$HOME/.ai-cli-notify.watch.pid"
CONDA_ENV="py312"

# 激活 conda 环境，确保能找到 node/npm
if command -v conda >/dev/null 2>&1; then
    eval "$(conda shell.bash hook)"
    conda activate "$CONDA_ENV"
fi

cd "$PROJECT_DIR"

# 避免重复启动
if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Watcher 已经在运行，PID: $(cat "$PID_FILE")"
    echo "查看日志：tail -f $LOG_FILE"
    exit 0
fi

nohup node ai-reminder.js watch --sources codex --interval-ms 1000 \
    > "$LOG_FILE" 2>&1 &

echo $! > "$PID_FILE"

echo "Codex watcher 已启动，PID: $(cat "$PID_FILE")"
echo "日志文件：$LOG_FILE"
echo "查看日志：tail -f $LOG_FILE"
