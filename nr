#!/usr/bin/env bash

if [ "$#" -eq 0 ]; then
    echo "Usage: notify-run <command> [args...]"
    exit 2
fi

start_epoch=$(date +%s)
start_time=$(date '+%Y-%m-%d %H:%M:%S')
host=$(hostname)
workdir=$(pwd)

printf -v command_str '%q ' "$@"
command_str=${command_str% }

"$@" </dev/null
exit_code=$?

end_epoch=$(date +%s)
end_time=$(date '+%Y-%m-%d %H:%M:%S')
elapsed=$((end_epoch - start_epoch))

hours=$((elapsed / 3600))
minutes=$(((elapsed % 3600) / 60))
seconds=$((elapsed % 60))
elapsed_str=$(printf '%02d:%02d:%02d' "$hours" "$minutes" "$seconds")

if [ "$exit_code" -eq 0 ]; then
    status="✅ 任务完成"
else
    status="❌ 任务失败"
fi

body=$(printf '%s\n\nHost: %s\nDirectory: %s\nCommand: %s\n\nStart: %s\nEnd: %s\nElapsed: %s\nExit code: %d' \
    "$status" "$host" "$workdir" "$command_str" "$start_time" "$end_time" "$elapsed_str" "$exit_code")

# 通知失败不能静默，也不能覆盖原任务的退出码。
if ! command -v apprise >/dev/null 2>&1; then
    printf 'nr: 无法发送通知：当前 PATH 中找不到 apprise，请检查安装及运行环境。\n' >&2
elif ! apprise -t "任务通知 | ${host}" -b "$body"; then
    printf 'nr: 通知发送失败，请检查上方错误及 apprise 配置。\n' >&2
fi

exit "$exit_code"
