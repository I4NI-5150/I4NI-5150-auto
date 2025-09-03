#!/usr/bin/env bash
set -euo pipefail

# === 0) Prereqs (no pip self-upgrade) ===
pkg update -y && pkg upgrade -y
pkg install -y git python python-pip nodejs gh cronie jq curl

# User-level bins on PATH (Termux-safe)
mkdir -p ~/.local/bin ~/.npm-global/bin
grep -q 'LOCAL BIN' ~/.bashrc || cat >> ~/.bashrc <<'RC'
# --- LOCAL BIN PATHS (AUTO) ---
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
RC
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

# Node globals to user prefix
npm config set prefix ~/.npm-global >/dev/null 2>&1 || true

# Tools (user scope; no pip upgrade)
python -m pip install --user black ruff md-toc >/dev/null 2>&1 || true
npm -g install prettier markdownlint-cli >/dev/null 2>&1 || true

mkdir -p ~/auto-git && cd ~/auto-git

# === 1) Config ===
cat > config.yaml << 'YAML'
repo_url: "https://github.com/USERNAME/REPO.git"   # <-- EDIT
branch: "main"
workdir: "./repo"
author_name: "Your Name"
author_email: "you@example.com"

improve:
  python_black: true
  python_ruff: true
  js_prettier: true
  md_lint: true
  add_editorconfig: true
  add_gitattributes: true
  refresh_readme_toc: true
  inject_badges: true

include_globs:
  - "**/*.py"
  - "**/*.js"
  - "**/*.ts"
  - "**/*.json"
  - "**/*.md"
  - "**/*.yml"
  - "**/*.yaml"

exclude_globs:
  - "node_modules/**"
  - ".git/**"
  - "**/.venv/**"
  - "**/__pycache__/**"

commit_prefix: "chore(auto):"
min_changed_lines_for_commit: 1
cron_expr: "*/15 * * * *"
YAML

# === 2) Workflow (pull → improve → commit → push) ===
cat > workflow.sh << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
CFG="config.yaml"
repo_url=$(grep '^repo_url' $CFG | awk '{print $2}' | tr -d '"')
branch=$(grep '^branch' $CFG | awk '{print $2}' | tr -d '"')
workdir=$(grep '^workdir' $CFG | awk '{print $2}' | tr -d '"')
author_name=$(grep '^author_name' $CFG | cut -d'"' -f2)
author_email=$(grep '^author_email' $CFG | cut -d'"' -f2)
commit_prefix=$(grep '^commit_prefix' $CFG | cut -d'"' -f2)

mkdir -p "$workdir"
if [ ! -d "$workdir/.git" ]; then
  git clone --branch "$branch" "$repo_url" "$workdir"
fi

cd "$workdir"
git config user.name "$author_name"
git config user.email "$author_email"

# Safe rebase
git fetch --all --prune
git checkout "$branch"
git rebase "origin/$branch" || (git rebase --abort || true; git reset --hard "origin/$branch")

# Ensure editorconfig / gitattributes
cat > .editorconfig << 'EC'
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
cat > .gitattributes << 'GA'
*.sh text eol=lf
*.py text eol=lf
*.md text eol=lf
*.js text eol=lf
*.ts text eol=lf
GA

# Python format/lint (user-scope bins)
command -v black >/dev/null 2>&1 && find . -name "*.py" -not -path "./.git/*" -exec black {} + || true
command -v ruff >/dev/null 2>&1 && find . -name "*.py" -not -path "./.git/*" -exec ruff --fix {} + || true

# JS/TS/JSON/YAML
command -v prettier >/dev/null 2>&1 && \
find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.json" -o -name "*.yml" -o -name "*.yaml" \) \
  -not -path "./.git/*" -not -path "./node_modules/*" -exec prettier --write {} + || true

# Markdown
command -v markdownlint >/dev/null 2>&1 && find . -name "*.md" -not -path "./.git/*" -exec markdownlint -f {} + || true
command -v md_toc >/dev/null 2>&1 && [ -f README.md ] && md_toc --in-place README.md || true
[ -f README.md ] && grep -q "![Auto]" README.md || sed -i '1s/^/![Auto](https:\/\/img.shields.io\/badge\/AI_Auto-Enabled-brightgreen)\n/' README.md

git add -A
if ! git diff --cached --quiet; then
  git commit -m "$commit_prefix automated update $(date +%F)"
  git push origin "$branch" || true
fi
