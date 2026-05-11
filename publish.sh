#!/usr/bin/env bash

set -e

# ==================== 此处默认值应被替换 ====================
REPO_NAME="lore-pages-example"
REPO="git@github.com:FleetingLore/${REPO_NAME}.git"
# =====================================================

DEPLOY_BRANCH="gh-pages"

echo "=========================================="
echo "Deploying Lore project: $REPO_NAME"
echo "=========================================="

BUILD_TMP=$(mktemp -d)
cleanup() { rm -rf "$BUILD_TMP"; }
trap cleanup EXIT

# 构建 Lore 内容
echo ">>> Building Lore project"
lore-pages

if [ -d "./docs-target" ]; then
    rsync -av --exclude='.DS_Store' ./docs-target/ "$BUILD_TMP/"
fi

# 部署到 gh-pages
echo ">>> Deploying to branch: $DEPLOY_BRANCH"

GIT_TMP=$(mktemp -d)

if git ls-remote --heads "$REPO" "$DEPLOY_BRANCH" | grep -q "$DEPLOY_BRANCH"; then
    git clone --depth 1 --branch "$DEPLOY_BRANCH" "$REPO" "$GIT_TMP"
else
    git clone "$REPO" "$GIT_TMP"
    cd "$GIT_TMP"
    git checkout --orphan "$DEPLOY_BRANCH"
    git rm -rf . >/dev/null 2>&1 || true
    cd - >/dev/null
fi

cd "$GIT_TMP"
find . -mindepth 1 -not -path './.git*' -delete
cd - >/dev/null

rsync -av --exclude='.git' --exclude='.DS_Store' "$BUILD_TMP/" "$GIT_TMP/"

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
