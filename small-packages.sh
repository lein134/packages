#!/bin/bash
set -euo pipefail

# ===================== 用户配置区 =====================
SOURCE_REPO="https://github.com/kenzok8/small-package.git"  # 源仓库地址
TARGET_USER="your-target-username"                          # 目标账户用户名
TARGET_REPO_NAME="your-target-repo"                         # 目标仓库名称
TARGET_TOKEN="${TARGET_PAT}"                    # 从Secrets读取PAT

# 要克隆的文件夹数组（每行一个，支持#注释）
CLONE_FOLDERS=(
    "luci-app-argon-config"     # 主题配置插件
    "luci-theme-argon"          # Argon主题
    # "luci-app-openclash"       # 取消注释添加更多
    # "luci-app-adguardhome"
)

# ===================== 稀疏克隆函数 =====================
git_sparse_clone() {
    local branch="$1" rurl="$2" localdir="$3" && shift 3
    local folders=("$@")

    echo "🗃️  开始稀疏克隆，分支: $branch | 文件夹: ${folders[*]}"
    
    git clone -b $branch --depth 1 --filter=blob:none --sparse $rurl $localdir
    cd $localdir
    git sparse-checkout init --cone
    git sparse-checkout set "${folders[@]}"
    mv -n "${folders[@]}" ../
    cd ..
    rm -rf $localdir
}

# ===================== 主执行流程 =====================
main() {
    # 初始化目标仓库
    TARGET_REPO="https://${TARGET_TOKEN}@github.com/${TARGET_USER}/${TARGET_REPO_NAME}.git"
    WORK_DIR="sync_temp"
    
    # 清理并创建目录
    rm -rf $WORK_DIR && mkdir -p $WORK_DIR
    cd $WORK_DIR
    
    # 执行稀疏克隆
    git_sparse_clone main "$SOURCE_REPO" "source_repo" "${CLONE_FOLDERS[@]}"
    
    # 初始化目标仓库
    git clone --depth 1 $TARGET_REPO target_repo
    rsync -av --delete ./ target_repo/
    
    # 提交变更
    cd target_repo
    git config user.name "GitHub Actions"
    git config user.email "actions@github.com"
    git add .
    git commit -m "Sync: $(date +'%Y-%m-%d %H:%M:%S')" || echo "🟢 无变更可提交"
    git push origin main
}

# 异常处理
trap "echo '❌ 脚本执行失败！退出码: $?'" EXIT
main
trap - EXIT
echo "✅ 同步完成！"
