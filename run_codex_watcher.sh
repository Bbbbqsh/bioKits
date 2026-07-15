#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
用法：
  $(basename "$0") [命令] [选项]

命令：
  start               启动 watcher（默认）
  stop                终止 watcher
  status              查看 watcher 状态

选项：
  --home PATH         HOME 目录（默认：$HOME_DIR）
  --project-dir PATH  项目目录（默认：<HOME>/softwares/ai-cli-complete-notify）
  --log-file PATH     日志文件（默认：<HOME>/ai-cli-notify.watch.log）
  --pid-file PATH     PID 文件（默认：<HOME>/.ai-cli-notify.watch.pid）
  --node-path PATH    node 可执行文件路径（默认：从 PATH 查找）
  -h, --help          显示此使用说明

说明：
  未指定 --project-dir、--log-file、--pid-file 时，<HOME> 使用 --home 的值。

示例：
  $(basename "$0") start --home /path/to/home
  $(basename "$0") stop --home /path/to/home
EOF
}

HOME_DIR="$(getent passwd "$(id -u)" | cut -d: -f6)"
ACTION="start"
PROJECT_DIR=""
LOG_FILE=""
PID_FILE=""
NODE_BIN="node"

if [[ $# -gt 0 && "$1" != -* ]]; then
    ACTION="$1"
    shift
fi

case "$ACTION" in
    start|stop|status)
        ;;
    *)
        echo "错误：未知命令 $ACTION" >&2
        usage >&2
        exit 1
        ;;
esac

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
        --node-path)
            [[ $# -ge 2 ]] || { echo "错误：--node-path 缺少参数" >&2; usage >&2; exit 1; }
            NODE_BIN="$2"
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

is_watcher_running() {
    local pid="$1"

    kill -0 "$pid" 2>/dev/null || return 1
    [[ "$(ps -p "$pid" -o args= 2>/dev/null)" == *"node ai-reminder.js watch"* ]]
}

if [[ "$ACTION" == "stop" ]]; then
    if [[ ! -f "$PID_FILE" ]]; then
        echo "Watcher 未运行，PID 文件不存在：$PID_FILE"
        exit 0
    fi

    pid="$(<"$PID_FILE")"
    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        echo "错误：PID 文件内容无效：$PID_FILE" >&2
        exit 1
    fi

    if ! is_watcher_running "$pid"; then
        if kill -0 "$pid" 2>/dev/null; then
            echo "错误：PID $pid 不是当前 Codex watcher，未终止该进程" >&2
            exit 1
        fi
        rm -f "$PID_FILE"
        echo "Watcher 未运行，已清理过期 PID 文件：$PID_FILE"
        exit 0
    fi

    kill -TERM "$pid" 2>/dev/null || true
    for _ in {1..10}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f "$PID_FILE"
            echo "Codex watcher 已终止，PID：$pid"
            exit 0
        fi
        sleep 1
    done

    echo "错误：已发送终止信号，但 watcher 仍在运行，PID：$pid" >&2
    exit 1
fi

if [[ "$ACTION" == "status" ]]; then
    if [[ ! -f "$PID_FILE" ]]; then
        echo "Watcher 未运行，PID 文件不存在：$PID_FILE"
        exit 1
    fi

    pid="$(<"$PID_FILE")"
    if [[ "$pid" =~ ^[0-9]+$ ]] && is_watcher_running "$pid"; then
        echo "Watcher 正在运行，PID：$pid"
        echo "日志文件：$LOG_FILE"
        exit 0
    fi

    echo "Watcher 未运行，但 PID 文件仍存在：$PID_FILE"
    exit 1
fi

# 确定 node 可执行文件。默认从当前 PATH 查找，也可以通过 --node-path 指定绝对路径。
if [[ "$NODE_BIN" == */* ]]; then
    if [[ ! -x "$NODE_BIN" ]]; then
        echo "错误：node 不可执行或路径不存在：$NODE_BIN" >&2
        exit 1
    fi
else
    NODE_BIN="$(command -v "$NODE_BIN" || true)"
    if [[ -z "$NODE_BIN" || ! -x "$NODE_BIN" ]]; then
        echo "错误：找不到 node，请使用 --node-path 指定可执行文件路径" >&2
        exit 1
    fi
fi

cd "$PROJECT_DIR"

# 避免重复启动
if [[ -f "$PID_FILE" ]]; then
    pid="$(<"$PID_FILE")"
    if [[ "$pid" =~ ^[0-9]+$ ]] && is_watcher_running "$pid"; then
        echo "Watcher 已经在运行，PID: $pid"
        echo "查看日志：tail -f $LOG_FILE"
        exit 0
    fi
fi

nohup "$NODE_BIN" ai-reminder.js watch --sources codex --interval-ms 1000 \
    > "$LOG_FILE" 2>&1 &

echo $! > "$PID_FILE"

echo "Codex watcher 已启动，PID: $(cat "$PID_FILE")"
echo "日志文件：$LOG_FILE"
echo "查看日志：tail -f $LOG_FILE"
