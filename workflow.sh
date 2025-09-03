#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
CFG="config.yaml"
repo_url=$(grep "^repo_url" $CFG | awk "{print \$2}" | tr -d "\"")
branch=$(grep "^branch" $CFG | awk "{print \$2}" | tr -d "\"")
workdir=$(grep "^workdir" $CFG | awk "{print \$2}" | tr -d "\"")
author_name=$(grep "^author_name" $CFG | cut -d"\"" -f2)
author_email=$(grep "^author_email" $CFG | cut -d"\"" -f2)
commit_prefix=$(grep "^commit_prefix" $CFG | cut -d"\"" -f2)

mkdir -p "$workdir"
if [ ! -d "$workdir/.git" ]; then
  git clone --branch "$branch" "$repo_url" "$workdir"
fi

cd "$workdir"
git config user.name "$author_name"
git config user.email "$author_email"

git fetch --all --prune
git checkout "$branch"
git rebase "origin/$branch" || (git rebase --abort || true; git reset --hard "origin/$branch")

cat > .editorconfig << "EC"
root = true
[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 2
[*.py]
indent_size = 4
EC
cat > .gitattributes << "GA"
*.sh text eol=lf
*.py text eol=lf
*.md text eol=lf
*.js text eol=lf
*.ts text eol=lf
GA

command -v black >/dev/null 2>&1 && find . -name "*.py" -not -path "./.git/*" -exec black {} + || true
command -v ruff >/dev/null 2>&1 && find . -name "*.py" -not -path "./.git/*" -exec ruff --fix {} + || true
command -v prettier >/dev/null 2>&1 && find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.json" -o -name "*.yml" -o -name "*.yaml" \) -not -path "./.git/*" -exec prettier --write {} + || true
command -v markdownlint >/dev/null 2>&1 && find . -name "*.md" -not -path "./.git/*" -exec markdownlint -f {} + || true
command -v md_toc >/dev/null 2>&1 && [ -f README.md ] && md_toc --in-place README.md || true
[ -f README.md ] && grep -q "![Auto]" README.md || sed -i "1s/^/![Auto](https:\/\/img.shields.io\/badge\/AI_Auto-Enabled-brightgreen)\n/" README.md

git add -A
if ! git diff --cached --quiet; then
  git commit -m "$commit_prefix automated update $(date +%F)"
  git push origin "$branch" || true
fi
