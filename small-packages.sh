#!/bin/bash
set -exo pipefail

# ===================== 用户配置区 =====================
SOURCE_REPO="https://github.com/kenzok8/small-package.git"  # 源仓库地址
TARGET_USER="RayleanB"                       # 目标账户用户名
TARGET_REPO_NAME="packages"                         # 目标仓库名称
# ===================== 核心修复点 =====================
WORKSPACE="sync_workspace"  # 固定工作目录
SRC_DIR="source_content"    # 源内容目录
TARGET_DIR="target_repo"    # 目标仓库目录

CLONE_FOLDERS=(
    "luci-app-argon-config"
    "luci-theme-argon"
)

# ===================== 路径清理函数 =====================
clean_workspace() {
    rm -rf "$WORKSPACE"
    mkdir -p "$WORKSPACE"
    cd "$WORKSPACE"
}

# ===================== 安全同步函数 =====================
safe_sync() {
    # 确保在WORKSPACE目录下操作
    cd "$WORKSPACE"
    
    # 精确同步到目标仓库根目录
    rsync -av --delete \
          --exclude='.git' \
          --exclude='.github' \
          --exclude='target_repo' \  # 关键修复：排除自身目录
          "$SRC_DIR/" "$TARGET_DIR/"
}

# ===================== 主流程 =====================
main() {
    clean_workspace
    
    # 克隆源仓库内容
    git clone --depth 1 --filter=blob:none --sparse "$SOURCE_REPO" "$SRC_DIR"
    cd "$SRC_DIR"
    git sparse-checkout set "${CLONE_FOLDERS[@]}"
    cd ..
    
    # 克隆目标仓库
    git clone "https://${TARGET_USER}:${TARGET_PAT}@github.com/${TARGET_USER}/${TARGET_REPO_NAME}.git" "$TARGET_DIR"
    
    # 执行同步
    if ! safe_sync; then
        echo "::error::同步失败"
        exit 20
    fi
    
    # 提交变更
    cd "$TARGET_DIR"
    git add .
    git commit -m "Sync: $(date +'%Y-%m-%d %H:%M:%S')"
    git push origin main
}

# ===================== 执行入口 =====================
trap "echo '❌ 进程被中断'; exit 130" INT TERM
main
trap - EXIT
echo "✅ 同步成功完成"
