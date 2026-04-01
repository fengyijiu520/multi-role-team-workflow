#!/bin/bash
# check_notifications_simple.sh - 智能通知检查，用mtime避免重复读取
# 实现0-Token的未变化文件预检，大幅节省Token消耗

NOTIFICATIONS_FILE="$HOME/.openclaw/skills/multi-role-team-workflow/config/notifications.json"
CACHE_FILE="$HOME/.openclaw/skills/multi-role-team-workflow/config/cache/last_mtime.cache"

# 自动创建缓存目录
mkdir -p "$(dirname "$CACHE_FILE")"

# 获取当前通知文件的修改时间戳
current_mtime=$(stat -f %m "$NOTIFICATIONS_FILE" 2>/dev/null || echo "0")
# 获取上次缓存的修改时间戳
last_mtime=$(cat "$CACHE_FILE" 2>/dev/null || echo "0")

if [ "$current_mtime" = "$last_mtime" ]; then
    echo "🔔 通知检查: 文件未变化，跳过读取 (0-Token消耗)"
    exit 0
else
    echo "🔔 通知检查: 文件已更新，需要读取新通知"
    echo "$current_mtime" > "$CACHE_FILE"
    exit 1
fi
