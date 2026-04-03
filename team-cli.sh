#!/bin/bash
set -e

# 配置
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
ROLES_DIR="$BASE_DIR/roles"
SKILLS_DIR="$BASE_DIR/skills"
OPENCLAW_SKILLS_DIR=""
UPDATE_BASE_URL="http://113.45.254.234:18888"

# 检测 openclaw 目录
detect_openclaw() {
  if [ -d "./openclaw" ]; then
    OPENCLAW_SKILLS_DIR="./openclaw/skills"
  elif [ -d "~/openclaw" ]; then
    OPENCLAW_SKILLS_DIR="~/openclaw/skills"
  elif [ -d "/opt/openclaw" ]; then
    OPENCLAW_SKILLS_DIR="/opt/openclaw/skills"
  else
    echo "警告: 未检测到 openclaw 目录，将使用默认技能目录"
    OPENCLAW_SKILLS_DIR="~/.openclaw/skills"
  fi
}

# 检查依赖技能
check_dependency() {
  local skill_name=$1
  # 先检查当前技能的本地skills
  if [ -d "$SKILLS_DIR/$skill_name" ]; then
    return 0
  fi
  # 再检查openclaw的全局skills
  if [ -d "$OPENCLAW_SKILLS_DIR/$skill_name" ]; then
    return 0
  fi
  # 未找到，询问是否安装
  echo "依赖技能 $skill_name 未安装，是否需要从服务器下载？(y/n)"
  read -r answer
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    mkdir -p "$SKILLS_DIR"
    echo "正在下载 $skill_name..."
    wget -q "$UPDATE_BASE_URL/download/$skill_name.zip" -O "$SKILLS_DIR/$skill_name.zip"
    unzip -q "$SKILLS_DIR/$skill_name.zip" -d "$SKILLS_DIR/"
    rm "$SKILLS_DIR/$skill_name.zip"
    echo "✅ 依赖技能 $skill_name 安装完成"
  else
    echo "❌ 未安装依赖技能，可能无法正常使用"
    return 1
  fi
}

# 查看所有角色
list_roles() {
  echo "=== 当前所有角色 ==="
  for role in "$ROLES_DIR"/*; do
    if [ -d "$role" ]; then
      role_name=$(basename "$role")
      # 检查是否是内置角色
      if [ "$role_name" = "manager" ] || [ "$role_name" = "security_gateway" ]; then
        echo "  ✅ $role_name (内置角色，不可删除)"
      else
        echo "  ⚙️  $role_name (用户角色，可删除)"
      fi
    fi
  done
}

# 增加角色
add_role() {
  echo "=== 新增角色 ==="
  echo "请输入要新增的角色名称:"
  read -r role_name
  
  if [ -d "$ROLES_DIR/$role_name" ]; then
    echo "❌ 角色 $role_name 已存在"
    return
  fi
  
  echo "请选择角色类型:"
  echo "  1) 纯净角色 (仅基础角色卡)"
  echo "  2) 基础角色 (角色卡+基础技能)"
  echo "  3) 完整角色 (角色卡+完整技能库)"
  read -r type_choice
  
  local type_dir=""
  case $type_choice in
    1) type_dir="Clean" ;;
    2) type_dir="Basic" ;;
    3) type_dir="Full" ;;
    *) echo "❌ 无效选项"; return ;;
  esac
  
  local download_url="$UPDATE_BASE_URL/roles/$role_name/$type_dir/"
  echo "正在从 $download_url 下载角色 $role_name..."
  
  # 下载角色包
  wget -q "$UPDATE_BASE_URL/roles/$role_name/$type_dir.zip" -O "/tmp/$role_name.zip"
  unzip -q "/tmp/$role_name.zip" -d "$ROLES_DIR/"
  rm "/tmp/$role_name.zip"
  
  echo "✅ 角色 $role_name 新增完成"
}

# 删除角色
delete_role() {
  echo "=== 删除角色 ==="
  echo "请输入要删除的角色名称:"
  read -r role_name
  
  # 检查是否是内置角色
  if [ "$role_name" = "manager" ] || [ "$role_name" = "security_gateway" ]; then
    echo "❌ 经理和安全网关是内置角色，不允许删除"
    return
  fi
  
  if [ ! -d "$ROLES_DIR/$role_name" ]; then
    echo "❌ 角色 $role_name 不存在"
    return
  fi
  
  rm -rf "$ROLES_DIR/$role_name"
  echo "✅ 角色 $role_name 已删除"
}

# 更新技能
update_skill() {
  echo "=== 更新技能 ==="
  # 读取当前版本
  local current_version=$(cat "$BASE_DIR/version.json" | grep -o '"version": "[^"]*"' | cut -d'"' -f4)
  echo "当前版本: $current_version"
  
  # 检查最新版本
  echo "正在检查更新..."
  local latest_version=$(wget -qO- "$UPDATE_BASE_URL/check_version?current=$current_version")
  
  if [ "$current_version" = "$latest_version" ]; then
    echo "✅ 当前为最新版本，无需更新"
    return
  fi
  
  echo "发现新版本: $latest_version，是否更新？(y/n)"
  read -r answer
  if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    return
  fi
  
  # 下载更新包
  echo "正在下载更新..."
  wget -q "$UPDATE_BASE_URL/update/$latest_version.zip" -O "/tmp/update.zip"
  unzip -q -o "/tmp/update.zip" -d "$BASE_DIR/"
  rm "/tmp/update.zip"
  
  echo "✅ 更新完成！"
  echo "提示: 更新后的第一次使用，请向智能体发送: '我的 multi-role-team-workflow 技能已更新，需要你使用更新后的技能来进行使用。'"
}

# 主菜单
main() {
  detect_openclaw
  
  echo "=================================="
  echo "  多角色团队工作流 CLI 管理工具"
  echo "=================================="
  
  while true; do
    echo ""
    echo "请选择操作:"
    echo "  1) 查看当前所有角色"
    echo "  2) 增加指定角色"
    echo "  3) 删除指定角色"
    echo "  4) 更新技能"
    echo "  5) 检查依赖技能"
    echo "  0) 退出"
    read -r choice
    
    case $choice in
      1) list_roles ;;
      2) add_role ;;
      3) delete_role ;;
      4) update_skill ;;
      5) 
        echo "正在检查依赖..."
        check_dependency "superpowers"
        check_dependency "other_skills"
        echo "✅ 依赖检查完成"
        ;;
      0) echo "退出"; exit 0 ;;
      *) echo "❌ 无效选项" ;;
    esac
  done
}

main
