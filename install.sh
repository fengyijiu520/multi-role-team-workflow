#!/bin/bash
set -e

echo "正在安装多角色团队工作流技能..."

# 配置
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
UPDATE_BASE_URL="http://113.45.254.234:18888"

# 展开路径中的 ~
expand_path() {
  local path="$1"
  if [[ "$path" =~ ^~ ]]; then
    path="${path/#\~/$HOME}"
  fi
  echo "$path"
}

# 检测 openclaw 目录（改进版）
detect_openclaw() {
  if [ -d "./openclaw" ]; then
    OPENCLAW_SKILLS_DIR="./openclaw/skills"
  elif [ -d "$HOME/openclaw" ]; then
    OPENCLAW_SKILLS_DIR="$HOME/openclaw/skills"
  elif [ -d "/opt/openclaw" ]; then
    OPENCLAW_SKILLS_DIR="/opt/openclaw/skills"
  elif [ -d "./skills" ]; then
    # 当前目录就是 openclaw 根目录（含有 skills/）
    OPENCLAW_SKILLS_DIR="$PWD/skills"
  else
    echo "未检测到 openclaw 目录，将使用默认技能目录"
    OPENCLAW_SKILLS_DIR="$HOME/.openclaw/skills"
    mkdir -p "$OPENCLAW_SKILLS_DIR"
  fi
}

detect_openclaw
echo "技能安装目录: $OPENCLAW_SKILLS_DIR"

# 定义全局技能目录（~/.openclaw/skills）
GLOBAL_SKILLS_DIR="$HOME/.openclaw/skills"
mkdir -p "$GLOBAL_SKILLS_DIR"

# 安装依赖技能（针对 superpowers 的增强版）
install_superpowers() {
  local skill_name="superpowers"
  
  # 1. 优先检查 ~/.openclaw/skills/superpowers
  if [ -d "$GLOBAL_SKILLS_DIR/$skill_name" ]; then
    echo "✅ 已找到依赖技能: $GLOBAL_SKILLS_DIR/$skill_name"
    return 0
  fi
  
  # 2. 未找到，进入交互安装流程
  echo "⚠️  未找到关键技能 '$skill_name'"
  echo "该技能是多角色团队工作流所必需的。"
  echo ""
  echo "请选择操作："
  echo "  1) 从服务器下载并安装"
  echo "  2) 手动指定技能所在路径"
  read -p "请输入选项 (1/2): " choice
  
  case "$choice" in
    1)
      echo "正在从服务器下载 $skill_name.zip ..."
      mkdir -p "$BASE_DIR/skills"
      wget -q "$UPDATE_BASE_URL/download/$skill_name.zip" -O "$BASE_DIR/skills/$skill_name.zip"
      echo "解压中..."
      unzip -q "$BASE_DIR/skills/$skill_name.zip" -d "$BASE_DIR/skills/"
      rm "$BASE_DIR/skills/$skill_name.zip"
      echo "✅ 下载并解压完成"
      
      # 将下载的技能复制到全局技能目录（如果不在同一位置）
      if [ "$BASE_DIR/skills/$skill_name" != "$GLOBAL_SKILLS_DIR/$skill_name" ]; then
        echo "正在同步技能到全局目录: $GLOBAL_SKILLS_DIR"
        cp -r "$BASE_DIR/skills/$skill_name" "$GLOBAL_SKILLS_DIR/"
      fi
      echo "✅ 依赖技能 $skill_name 安装成功"
      ;;
    2)
      while true; do
        echo ""
        echo "请输入 $skill_name 所在的父目录路径"
        echo "例如：若技能位于 ~/.openclaw/skills/superpowers，请输入 ~/.openclaw/skills/"
        read -p "路径: " user_path
        user_path=$(expand_path "$user_path")
        # 确保路径以 / 结尾
        [[ "$user_path" != */ ]] && user_path="${user_path}/"
        
        if [ -d "${user_path}${skill_name}" ]; then
          echo "✅ 找到技能: ${user_path}${skill_name}"
          # 如果该路径不是全局技能目录，则创建符号链接或复制
          target_dir="$(realpath "$user_path")"
          global_dir="$(realpath "$GLOBAL_SKILLS_DIR")"
          if [ "$target_dir" != "$global_dir" ]; then
            echo "注意：您指定的路径不是默认全局技能目录"
            read -p "是否创建符号链接到 $GLOBAL_SKILLS_DIR ？(y/n): " link_choice
            if [[ "$link_choice" =~ ^[Yy]$ ]]; then
              ln -sf "${user_path}${skill_name}" "$GLOBAL_SKILLS_DIR/$skill_name"
              echo "✅ 已创建符号链接"
            else
              echo "⚠️  将直接使用原路径，请确保主技能能访问到该位置"
            fi
          fi
          echo "✅ 依赖技能 $skill_name 已就绪"
          break
        else
          echo "❌ 未找到 ${user_path}${skill_name}，请重新输入"
          echo "（按 Ctrl+C 可退出脚本）"
        fi
      done
      ;;
    *)
      echo "无效选项，退出安装。"
      exit 1
      ;;
  esac
}

# 执行 superpowers 依赖安装
install_superpowers

# 如果需要检查其他依赖，可以在此扩展（但当前只有 superpowers）

# 安装主技能到检测到的 openclaw 技能目录
TARGET_DIR="$OPENCLAW_SKILLS_DIR/multi-role-team-workflow"
mkdir -p "$TARGET_DIR"

# 复制主技能文件（排除可能干扰的临时文件或特殊文件）
echo "正在安装主技能..."
for item in "$BASE_DIR"/*; do
  base=$(basename "$item")
  # 跳过 skills 目录（避免循环复制）以及隐藏文件
  if [ "$base" = "skills" ] || [[ "$base" == .* ]]; then
    continue
  fi
  cp -r "$item" "$TARGET_DIR/"
done

# 给脚本添加执行权限
chmod +x "$TARGET_DIR/"*.sh "$TARGET_DIR/scripts/"*.js "$TARGET_DIR/scripts/"*.py 2>/dev/null || true

# 安装角色技能（直接复制到全局技能目录）
echo "正在安装角色技能..."
for role in "$BASE_DIR"/roles/*; do
  if [ -d "$role" ]; then
    role_name=$(basename "$role")
    echo "安装角色: $role_name"
    cp -r "$role" "$GLOBAL_SKILLS_DIR/"
  fi
done

echo ""
echo "✅ 安装完成！"
echo "你现在可以使用 ./team-cli.sh 来管理角色和更新，或者使用 /team-start 来启动工作流"