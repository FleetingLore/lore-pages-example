#!/usr/bin/env bash

set -e

REPO_PREFIX="git@github.com:FleetingLore/"  # 根据你的实际地址调整
DEPLOY_BRANCH="gh-pages"
SRC_DIR="./src"

usage() {
    echo "Usage: $0 <repo-name>"
    echo "Example: $0 my-lore-site"
    exit 1
}

if [ $# -ne 1 ]; then
    usage
fi

REPO_NAME="$1"
REPO="${REPO_PREFIX}${REPO_NAME}.git"
PROJECT_PATH="${SRC_DIR}/${REPO_NAME}"

echo "=========================================="
echo "Deploying Lore project: $REPO_NAME"
echo "=========================================="

# 检查是否是有效的 Lore 项目
if [ ! -f "${PROJECT_PATH}/Lore.toml" ] && [ ! -f "${PROJECT_PATH}/local.lore" ]; then
    echo "Error: No Lore.toml or local.lore found in ${PROJECT_PATH}"
    echo "This doesn't appear to be a valid Lore project."
    exit 1
fi

BUILD_TMP=$(mktemp -d)
cleanup() { rm -rf "$BUILD_TMP"; }
trap cleanup EXIT

# ==================== 1. 处理 Lore 内容 ====================
echo ">>> Building Lore project: $REPO_NAME"

cd "$PROJECT_PATH"

# 处理 Lore.toml（如果存在）
if [ -f "Lore.toml" ]; then
    echo ">>> Building from Lore.toml"
    lore-pages
    if [ -d "./docs-target" ]; then
        rsync -av --exclude='.DS_Store' ./docs-target/ "$BUILD_TMP/"
    fi
fi

# 处理 local.lore（如果存在）
if [ -f "local.lore" ]; then
    echo ">>> Processing local.lore"
    # 复制整个目录保留结构
    rsync -av --exclude='.DS_Store' --exclude='Lore.toml' ./ "$BUILD_TMP/"
fi

cd - >/dev/null

# ==================== 2. 部署到 gh-pages ====================
echo ">>> Deploying to branch: $DEPLOY_BRANCH"

GIT_TMP=$(mktemp -d)

# 克隆或初始化 gh-pages 分支
if git ls-remote --heads "$REPO" "$DEPLOY_BRANCH" | grep -q "$DEPLOY_BRANCH"; then
    git clone --depth 1 --branch "$DEPLOY_BRANCH" "$REPO" "$GIT_TMP"
else
    git clone "$REPO" "$GIT_TMP"
    cd "$GIT_TMP"
    git checkout --orphan "$DEPLOY_BRANCH"
    git rm -rf . >/dev/null 2>&1 || true
    cd - >/dev/null
fi

# 清空目标目录（保留 .git）
cd "$GIT_TMP"
find . -mindepth 1 -not -path './.git*' -delete
cd - >/dev/null

# 复制新内容
rsync -av --exclude='.git' --exclude='.DS_Store' "$BUILD_TMP/" "$GIT_TMP/"

# 检查是否有实际变化，无变化则跳过提交
cd "$GIT_TMP"
if git diff --quiet && git diff --cached --quiet; then
    echo "No content changes detected. Skipping commit and push."
else
    git add --all
    git rm --cached -f .DS_Store >/dev/null 2>&1 || true
    git commit -m "Deploy Lore at $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    git push "$REPO" "$DEPLOY_BRANCH"
    echo "Successfully deployed to $DEPLOY_BRANCH"
fi

cd - >/dev/null
rm -rf "$GIT_TMP"

echo "=========================================="
echo "Done!"
echo "=========================================="
