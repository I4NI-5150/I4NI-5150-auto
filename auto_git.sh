#!/usr/bin/env bash
set -euo pipefail

# --- CONFIG ---
REPO_DIR="${HOME}/auto-git"
REMOTE_URL="https://github.com/I4NI-5150/I4NI-5150-auto.git"
GIT_NAME="I4NI-5150"
GIT_EMAIL="lovellgregory1978@gmail.com"
BRANCH="main"
MSG="${1:-chore(auto): $(date -u +'%Y-%m-%dT%H:%M:%SZ')}"

# --- SETUP ---
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch "$BRANCH"

mkdir -p "$REPO_DIR"
cd "$REPO_DIR"

# init repo if needed
if [ ! -d .git ]; then
  git init
fi

# ensure branch exists
git checkout -B "$BRANCH"

# set remote
if git remote get-url origin >/dev/null 2>&1; then
  true
else
  git remote add origin "$REMOTE_URL"
fi

# fetch + rebase (handles first push gracefully)
git fetch origin "$BRANCH" || true
git pull --rebase origin "$BRANCH" || true

# stage + commit if there are changes
if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A
  git commit -m "$MSG"
else
  echo "No changes to commit."
fi

# push
git push -u origin "$BRANCH"
echo "✅ Pushed to $BRANCH."
