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

apprise \
    -t "任务通知 | ${host}" \
    -b "$body" >/dev/null 2>&1

exit "$exit_code"
