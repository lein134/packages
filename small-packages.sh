#!/bin/bash
set -exo pipefail

# ===================== 用户配置区 =====================
SOURCE_REPO="https://github.com/kenzok8/small-package.git"  # 源仓库地址
TARGET_USER="RayleanB"                       # 目标账户用户名
TARGET_REPO_NAME="packages"                         # 目标仓库名称
MAX_RETRY=3                                                 # 最大重试次数
CLONE_FOLDERS=(                                             # 要克隆的文件夹数组
    "luci-app-argon-config"
    "luci-theme-argon"
    # "luci-app-openclash"    # 示例注释
)

# ===================== 稀疏克隆函数 =====================
git_sparse_clone() {
    local branch="$1" rurl="$2" localdir="$3" && shift 3
    local folders=("$@")
    
    echo "🔍 开始克隆分支 [$branch] 的以下目录:"
    printf ' - %s\n' "${folders[@]}"
    
    for ((i=0; i<MAX_RETRY; i++)); do
        rm -rf "$localdir" && mkdir -p "$localdir"
        if git clone -b "$branch" --depth 1 --filter=blob:none --sparse "$rurl" "$localdir"; then
            cd "$localdir"
            git sparse-checkout init --cone
            git sparse-checkout set "${folders[@]}" || true
            if [ -d "../$localdir" ]; then
                find . -mindepth 1 -maxdepth 1 -exec mv -n {} .. \;
                cd ..
                rm -rf "$localdir"
                return 0
            fi
        fi
        echo "⚠️ 克隆失败，第 $((i+1)) 次重试..."
        sleep $((i*5+10))
    done
    echo "❌ 达到最大重试次数 $MAX_RETRY"
    return 1
}

# ===================== 安全推送函数 =====================
git_secure_push() {
    local remote_url="https://${TARGET_USER}:${TARGET_PAT}@github.com/${TARGET_USER}/${TARGET_REPO_NAME}.git"
    git remote add target-repo "$remote_url" || true
    
    echo "🚀 准备推送到目标仓库..."
    if ! git push target-repo HEAD:main; then
        echo "⚠️ 常规推送失败，尝试强制推送..."
        git push --force target-repo HEAD:main || {
            echo "❌ 强制推送失败"
            return 1
        }
    fi
    echo "✅ 推送成功"
}

# ===================== 主执行流程 =====================
main() {
    # 初始化工作目录
    WORK_DIR="sync_temp"
    rm -rf "$WORK_DIR" && mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"

    # 执行稀疏克隆
    if ! git_sparse_clone main "$SOURCE_REPO" "source_repo" "${CLONE_FOLDERS[@]}"; then
        echo "::error::克隆源仓库失败"
        exit 10
    fi

    # 克隆目标仓库
    if ! git clone --depth 1 "https://${TARGET_PAT}@github.com/${TARGET_USER}/${TARGET_REPO_NAME}.git" target_repo; then
        echo "::error::克隆目标仓库失败"
        exit 20
    fi

    # 同步文件
    echo "🔄 同步文件到目标仓库..."
    rsync -av --ignore-errors --delete-excluded \
          --exclude='.git' --exclude='.github' \
          ./ target_repo/

    # 提交变更
    cd target_repo
    git config --local user.name "GitHub Actions"
    git config --local user.email "actions@github.com"
    git add --all
    
    if [ -z "$(git status --porcelain)" ]; then
        echo "🟢 无变更需要提交"
        exit 0
    fi

    git commit -m "Auto Sync: $(date +'%Y-%m-%d %H:%M:%S')" || {
        echo "::warning::提交创建失败"
        exit 30
    }

    # 执行推送
    if ! git_secure_push; then
        echo "::error::最终推送失败"
        exit 40
    fi
}

# ===================== 执行入口 =====================
trap "echo '❌ 进程被中断'; exit 130" INT TERM
main
trap - EXIT
echo "✅ 所有操作成功完成"
