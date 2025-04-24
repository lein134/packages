#!/bin/bash
set -euo pipefail

# ===================== 用户配置区 =====================
SOURCE_REPO="https://github.com/kenzok8/small-package.git"
TARGET_USER="RayleanB"
TARGET_REPO_NAME="packages"

# ===================== 精准路径配置 =====================
WORKSPACE="$PWD/sync_workspace"
SRC_DIR="$WORKSPACE/source_content"
TARGET_DIR="$WORKSPACE/target_repo"

CLONE_PATHS=(
    # 包含目标目录及其所有内容
    "/luci-app-argon-config"
    "/luci-theme-argon"









    
    # 排除根目录指定文件（关键修改）
    "!/LICENSE"
    "!/README.md"
)

# ===================== 智能克隆函数 =====================
git_smart_clone() {
    # 禁用cone模式实现精准控制
    git clone --depth 1 --filter=blob:none --sparse "$SOURCE_REPO" "$SRC_DIR"
    (
        cd "$SRC_DIR"
        git sparse-checkout init --no-cone
        git sparse-checkout set "${CLONE_PATHS[@]}" 2>/dev/null
        
        # 验证排除结果
        [ ! -f "LICENSE" ] || { echo "::error::根目录LICENSE未被排除"; exit 20; }
        [ ! -f "README.md" ] || { echo "::error::根目录README.md未被排除"; exit 21; }
    )
}

# ===================== 主流程 =====================
main() {
    rm -rf "$WORKSPACE" && mkdir -p "$WORKSPACE"
    
    # 克隆源仓库
    echo "🔍 开始精准克隆..."
    if ! git_smart_clone; then
        echo "::error::克隆过程出错"
        exit 10
    fi

    # 克隆目标仓库
    git clone --depth 1 "https://${TARGET_USER}:${TARGET_PAT}@github.com/${TARGET_USER}/${TARGET_REPO_NAME}.git" "$TARGET_DIR"
    
    # 同步文件（二次确认排除）
    rsync -av --delete \
          --exclude='.git' \
          --exclude='/LICENSE' \     # 仅排除根目录文件
          --exclude='/README.md' \
          "$SRC_DIR/" "$TARGET_DIR/"
    
    # 提交变更
    (
        cd "$TARGET_DIR"
        git config user.name "Auto Sync"
        git config user.email "auto@github.com"
        
        # 验证目标仓库内容
        [ ! -f "LICENSE" ] || { echo "::error::检测到LICENSE文件残留"; exit 30; }
        [ ! -f "README.md" ] || { echo "::error::检测到README.md残留"; exit 31; }
        
        git add .
        if git commit -m "Sync: $(date +'%Y-%m-%d %H:%M:%S')"; then
            git push origin main
        else
            echo "🟢 无变更需要提交"
        fi
    )
}

# ===================== 执行入口 =====================
trap "echo '❌ 进程被中断'; exit 130" INT TERM
main
trap - EXIT
echo "✅ 同步成功完成"
