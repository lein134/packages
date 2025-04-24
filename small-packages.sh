#!/bin/bash
set -exo pipefail

# ===================== 用户配置区 =====================
SOURCE_REPO="https://github.com/kenzok8/small-package.git"  # 源仓库地址
TARGET_USER="RayleanB"                       # 目标账户用户名
TARGET_REPO_NAME="packages"                         # 目标仓库名称
MAX_RETRY=3
CLONE_FOLDERS=(
    "luci-app-argon-config"
    "luci-theme-argon"
)

# ===================== 函数定义 =====================
git_sparse_clone() {
    local branch="$1" rurl="$2" localdir="$3" && shift 3
    local folders=("$@")
    
    echo "🔍 正在克隆分支 [$branch] 的以下目录:"
    printf ' - %s\n' "${folders[@]}"
    
    git clone -b "$branch" --depth 1 --filter=blob:none --sparse "$rurl" "$localdir"
    cd "$localdir"
    git sparse-checkout init --cone
    git sparse-checkout set "${folders[@]}"
    mv -n "${folders[@]}" ../
    cd ..
    rm -rf "$localdir"
}

robust_rsync() {
    local retry=0
    until [ $retry -ge $MAX_RETRY ]
    do
        if rsync -av --ignore-missing-args --delay-updates --delete \
           --exclude='.git' --exclude='.github' \
           ./ target_repo/ ; then
            return 0
        fi
        echo "⚠️ 第 $((retry+1)) 次同步失败，等待重试..."
        sleep $(( (retry + 1) * 10 ))
        ((retry++))
    done
    echo "❌ 达到最大重试次数 $MAX_RETRY"
    return 1
}

# ===================== 主流程 =====================
main() {
    # 初始化目录
    WORK_DIR="sync_temp"
    rm -rf "$WORK_DIR" && mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"

    # 稀疏克隆源仓库
    git_sparse_clone main "$SOURCE_REPO" "source_repo" "${CLONE_FOLDERS[@]}"

    # 克隆目标仓库
    git clone --quiet "https://${TARGET_USER}:${TARGET_PAT}@github.com/${TARGET_USER}/${TARGET_REPO_NAME}.git" target_repo

    # 增强同步
    if ! robust_rsync; then
        echo "::warning::部分文件同步失败，但继续提交"
    fi

    # 提交变更
    cd target_repo
    git config --local user.name "Auto Syncer"
    git config --local user.email "auto-sync@github.com"
    
    if [ -z "$(git status --porcelain)" ]; then
        echo "🟢 无变更需要提交"
        exit 0
    fi

    git add .
    git commit -m "Sync: $(date +'%Y-%m-%d %H:%M:%S')"
    git push origin main
}

# ===================== 执行入口 =====================
trap "echo '❌ 进程被中断'; exit 130" INT TERM
main
trap - EXIT
echo "✅ 所有操作成功完成"
