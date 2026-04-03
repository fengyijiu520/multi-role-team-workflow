#!/bin/bash
# 简单的通知检查脚本，用于文员角色的办公自动化

echo "检查团队任务通知..."
NOTIFICATIONS_FILE=~/.team/notifications.json
if [ -f "$NOTIFICATIONS_FILE" ]; then
    cat "$NOTIFICATIONS_FILE" | jq '.[] | select(.read == false)'
else
    echo "没有未读通知"
fi
