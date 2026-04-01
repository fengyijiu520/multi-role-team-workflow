#!/bin/bash
# Multi-Role Team Workflow 一键安装脚本
# 自动检测Superpowers安装状态，自动部署所有组件

set -e

# 定义路径
SKILLS_DIR="$HOME/.openclaw/skills"
MY_SKILL_NAME="multi-role-team-workflow"
MY_SKILL_DIR="$SKILLS_DIR/$MY_SKILL_NAME"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILTIN_SUPERPOWERS="$SCRIPT_DIR/skills/superpowers"

echo "========================================"
echo "  Multi-Role Team Workflow 安装程序"
echo "========================================"

# 1. 检查技能目录是否存在
if [ ! -d "$SKILLS_DIR" ]; then
    echo "⚠️ 未检测到OpenClaw技能目录，正在创建..."
    mkdir -p "$SKILLS_DIR"
fi

# 2. 检测是否已安装Superpowers
echo "🔍 检测Superpowers安装状态..."
if [ -d "$SKILLS_DIR/superpowers" ]; then
    echo "✅ 检测到已安装Superpowers，跳过内置版本安装"
else
    echo "⚠️ 未检测到Superpowers，正在安装内置版本..."
    # 复制内置的Superpowers
    cp -r "$BUILTIN_SUPERPOWERS" "$SKILLS_DIR/"
    echo "✅ 内置Superpowers安装完成"
fi

# 3. 安装我们的技能
echo "📦 正在安装Multi-Role Team Workflow技能..."
mkdir -p "$MY_SKILL_DIR"
# 复制所有文件
cp -r "$SCRIPT_DIR/"* "$MY_SKILL_DIR/"

# 4. 给脚本添加执行权限
echo "🔧 配置执行权限..."
chmod +x "$MY_SKILL_DIR/scripts/check_notifications_simple.sh"
chmod +x "$MY_SKILL_DIR/install.sh"

# 5. 创建缓存目录
echo "⚙️ 初始化配置目录..."
mkdir -p "$MY_SKILL_DIR/config/cache"
# 初始化缓存文件
echo "0" > "$MY_SKILL_DIR/config/cache/last_mtime.cache"

echo ""
echo "🎉 安装完成！"
echo ""
echo "📝 后续配置说明："
echo "1. 自定义角色模型/API Key: 编辑 $MY_SKILL_DIR/config/role-config.json"
echo "2. 自定义安全规则: 编辑 $MY_SKILL_DIR/security-gateway-rules.md"
echo "3. 自定义Token优化策略: 编辑 $MY_SKILL_DIR/config/token-optimization.md"
echo ""
echo "🚀 现在你可以重启OpenClaw，然后使用这个技能了！"
