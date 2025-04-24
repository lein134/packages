#!/bin/bash
set -euo pipefail

# ===================== 用户配置区 =====================
SOURCE_REPO="https://github.com/kenzok8/small-package.git"
TARGET_USER="RayleanB"
TARGET_REPO_NAME="packages"

# ===================== 路径配置 =====================
WORKSPACE="$PWD/sync_workspace"  # 使用绝对路径
SRC_DIR="$WORKSPACE/source_content"
TARGET_DIR="$WORKSPACE/target_repo"

CLONE_FOLDERS=(
    "luci-app-argon-config"
    "luci-theme-argon"
)

# ===================== 增强路径处理 =====================
clean_workspace() {
    echo "🧹 清理工作目录..."
    rm -rf "$WORKSPACE"
    mkdir -p "$WORKSPACE"
    echo "工作目录: $WORKSPACE"
}

safe_clone() {
    local repo_url="$1" clone_dir="$2"
    echo "🔧 正在克隆仓库到: $clone_dir"
    git clone --depth 1 --filter=blob:none --sparse "$repo_url" "$clone_dir"
}

# ===================== 主流程 =====================
main() {
    # 清理并初始化目录
    clean_workspace
    
    # 克隆源仓库
    safe_clone "$SOURCE_REPO" "$SRC_DIR"
    (cd "$SRC_DIR" && git sparse-checkout set "${CLONE_FOLDERS[@]}")
    
    # 克隆目标仓库
    safe_clone "https://${TARGET_USER}:${TARGET_PAT}@github.com/${TARGET_USER}/${TARGET_REPO_NAME}.git" "$TARGET_DIR"
    
    # 同步文件
    echo "🔄 开始同步文件..."
    rsync -av --delete \
          --exclude='.git' \
          --exclude='.github' \
          "$SRC_DIR/" "$TARGET_DIR/"
    
    # 提交变更
    (cd "$TARGET_DIR" && {
        git add . 
        git commit -m "Sync: $(date +'%Y-%m-%d %H:%M:%S')"
        git push origin main
    })
}

# ===================== 执行入口 =====================
trap "echo '❌ 进程被中断'; exit 130" INT TERM
main
trap - EXIT
echo "✅ 同步成功完成"
