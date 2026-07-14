#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
用法：
  $(basename "$0") [选项]

选项：
  --home PATH         HOME 目录（默认：$HOME_DIR）
  --project-dir PATH  项目目录（默认：<HOME>/softwares/ai-cli-complete-notify）
  --log-file PATH     日志文件（默认：<HOME>/ai-cli-notify.watch.log）
  --pid-file PATH     PID 文件（默认：<HOME>/.ai-cli-notify.watch.pid）
  --conda-env NAME    conda 环境（默认：py312）
  -h, --help          显示此使用说明

说明：
  未指定 --project-dir、--log-file、--pid-file 时，<HOME> 使用 --home 的值。

示例：
  $(basename "$0") --home /path/to/home
EOF
}

HOME_DIR="$(getent passwd "$(id -u)" | cut -d: -f6)"
PROJECT_DIR=""
LOG_FILE=""
PID_FILE=""
CONDA_ENV="py312"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --home)
            [[ $# -ge 2 ]] || { echo "错误：--home 缺少参数" >&2; usage >&2; exit 1; }
            HOME_DIR="$2"
            shift 2
            ;;
        --project-dir)
            [[ $# -ge 2 ]] || { echo "错误：--project-dir 缺少参数" >&2; usage >&2; exit 1; }
            PROJECT_DIR="$2"
            shift 2
            ;;
        --log-file)
            [[ $# -ge 2 ]] || { echo "错误：--log-file 缺少参数" >&2; usage >&2; exit 1; }
            LOG_FILE="$2"
            shift 2
            ;;
        --pid-file)
            [[ $# -ge 2 ]] || { echo "错误：--pid-file 缺少参数" >&2; usage >&2; exit 1; }
            PID_FILE="$2"
            shift 2
            ;;
        --conda-env)
            [[ $# -ge 2 ]] || { echo "错误：--conda-env 缺少参数" >&2; usage >&2; exit 1; }
            CONDA_ENV="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "错误：未知参数 $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

PROJECT_DIR="${PROJECT_DIR:-$HOME_DIR/softwares/ai-cli-complete-notify}"
LOG_FILE="${LOG_FILE:-$HOME_DIR/ai-cli-notify.watch.log}"
PID_FILE="${PID_FILE:-$HOME_DIR/.ai-cli-notify.watch.pid}"

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
