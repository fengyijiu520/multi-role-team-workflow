#!/bin/bash
set -e

echo "正在卸载多角色团队工作流技能..."

# 检测 openclaw 目录
detect_openclaw() {
  if [ -d "./openclaw" ]; then
    OPENCLAW_SKILLS_DIR="./openclaw/skills"
  elif [ -d "~/openclaw" ]; then
    OPENCLAW_SKILLS_DIR="~/openclaw/skills"
  elif [ -d "/opt/openclaw" ]; then
    OPENCLAW_SKILLS_DIR="/opt/openclaw/skills"
  else
    OPENCLAW_SKILLS_DIR="~/.openclaw/skills"
  fi
}

detect_openclaw

# 删除主技能
rm -rf "$OPENCLAW_SKILLS_DIR/multi-role-team-workflow"

# 删除角色技能
for role in manager developer clerk security_gateway; do
  # 只删除用户没有修改的内置角色，如果是用户自己加的同名的，不删？不对，用户的角色是在本地的，所以全局的角色是安装的时候复制的，所以卸载的时候删除全局的
  rm -rf "$OPENCLAW_SKILLS_DIR/$role"
done

echo "✅ 卸载完成！"
