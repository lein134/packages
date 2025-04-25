#!/bin/bash
set -euo pipefail

TARGET_USER="RayleanB"
TARGET_REPO_NAME="packages"

# ===================== 增强稀疏克隆 =====================
WORKSPACE="$PWD/sync_workspace"
SRC_DIR="$WORKSPACE/source_content"
TARGET_DIR="$WORKSPACE/target_repo"

function git_clone() {
  git clone --depth 1 $1 $2 || true
 }
function git_sparse_clone() {
  branch="$1" rurl="$2" localdir="$3" && shift 3
  git clone -b $branch --depth 1 --filter=blob:none --sparse $rurl $localdir
  cd $localdir
  git sparse-checkout init --cone
  git sparse-checkout set $@
  mv -n $@ ../
  cd ..
  rm -rf $localdir
  }
function mvdir() {
mv -n `find $1/* -maxdepth 0 -type d` ./
rm -rf $1
}



# ===================== 主流程 =====================
main() {
    rm -rf "$WORKSPACE" && mkdir -p "$WORKSPACE"
    git_sparse_clone master "https://github.com/sbwml/openwrt_pkgs" "openwrt_pkgs" luci-app-gowebdav luci-app-ota luci-app-socat

    # 同步到目标仓库
    git clone --depth 1 "https://${TARGET_USER}:${TARGET_PAT}@github.com/${TARGET_USER}/${TARGET_REPO_NAME}.git" "$TARGET_DIR"
    # 将文件从源目录同步到目标仓库中的 指定文件夹 文件夹
    mkdir -p "$TARGET_DIR/18.06/small-packages/"
    rsync -av --delete --exclude='.git' "$SRC_DIR/" "$TARGET_DIR/18.06/small-packages/"
    
    # 提交变更
    (
        cd "$TARGET_DIR/18.06/small-packages"
        rm -rf LICENSE
        rm -rf README.md
        cd ..
        cd ..
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
