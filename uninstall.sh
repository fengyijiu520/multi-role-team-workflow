#!/bin/bash
# Multi-Role Team Workflow 一键卸载脚本
# 完全卸载该技能，清除所有安装痕迹

set -e

# 定义路径，和安装脚本保持一致
SKILLS_DIR="$HOME/.openclaw/skills"
MY_SKILL_NAME="multi-role-team-workflow"
MY_SKILL_DIR="$SKILLS_DIR/$MY_SKILL_NAME"

echo "========================================"
echo "  Multi-Role Team Workflow 卸载程序"
echo "========================================"

# 检查技能目录是否存在
if [ ! -d "$MY_SKILL_DIR" ]; then
    echo "✅ 未检测到已安装的Multi-Role Team Workflow技能，无需卸载"
    exit 0
fi

# 确认卸载
read -p "⚠️ 即将删除所有该技能的文件，是否确认卸载？(y/N) " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ 已取消卸载"
    exit 0
fi

# 删除技能目录
echo "🗑️  正在删除技能文件..."
rm -rf "$MY_SKILL_DIR"

echo ""
echo "🎉 卸载完成！"
echo "✅ 已完全清除Multi-Role Team Workflow技能的所有安装痕迹，无残留。"
echo "注意：依赖的Superpowers技能未被删除，如果你还有其他技能使用它，可以保留。"
