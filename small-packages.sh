#!/bin/bash
set -euo pipefail

# ===================== 用户配置区 =====================
SOURCE_REPO="https://github.com/kenzok8/small-package.git"
TARGET_USER="RayleanB"
TARGET_REPO_NAME="packages"

# ===================== 增强稀疏克隆 =====================
WORKSPACE="$PWD/sync_workspace"
SRC_DIR="$WORKSPACE/source_content"
TARGET_DIR="$WORKSPACE/target_repo"

CLONE_PATHS=(
    "luci-app-openclash"
    "iptvhelper"
    "luci-app-iptvhelper"
    "luci-app-timecontrol"
    "cdnspeedtest"
    "luci-app-cloudflarespeedtest"
    "luci-app-dnsfilter"
    "luci-app-fileassistant"
    "luci-app-wolplus"
    "luci-app-wechatpush"
    "luci-app-poweroff"
    "luci-app-amlogic"
    "luci-app-argon-config"
)

# ===================== 智能克隆函数 =====================
git_smart_clone() {
    # 禁用干扰提示
    git config --global advice.updateSparsePath false
    
    # 稀疏克隆核心逻辑
    git clone --depth 1 --filter=blob:none --sparse "$SOURCE_REPO" "$SRC_DIR"
    (
        cd "$SRC_DIR"
        git sparse-checkout init --cone
        git sparse-checkout set "${CLONE_PATHS[@]}" 2>/dev/null
        
        # 二次校验路径
        for path in "${CLONE_PATHS[@]}"; do
            [ -e "$path" ] || echo "::warning::路径不存在: $path"
        done
    )
}

# ===================== 主流程 =====================
main() {
    rm -rf "$WORKSPACE" && mkdir -p "$WORKSPACE"
    
    # 克隆源仓库
    echo "🔍 开始智能克隆..."
    if ! git_smart_clone; then
        echo "::error::克隆失败"
        exit 10
    fi

    # 同步到目标仓库
    git clone --depth 1 "https://${TARGET_USER}:${TARGET_PAT}@github.com/${TARGET_USER}/${TARGET_REPO_NAME}.git" "$TARGET_DIR"
    # 将文件从源目录同步到目标仓库中的 指定文件夹 文件夹
    mkdir -p "$TARGET_DIR/18.06/small-packages/"
    rsync -av --delete --exclude='.git' "$SRC_DIR/" "$TARGET_DIR/18.06/small-packages/"
    
    # 提交变更
    (
        cd "$TARGET_DIR"
        rm -rf LICENSE
        rm -rf README.md
        git config user.name "Auto Sync"
        git config user.email "auto@github.com"
        git add .
        git commit -m "Sync: $(date +'%F %T')" || exit 0
        git push
    )
}

# ===================== 执行入口 =====================
trap "echo '❌ 进程中断'; exit 130" INT TERM
main
trap - EXIT
echo "✅ 同步成功"
