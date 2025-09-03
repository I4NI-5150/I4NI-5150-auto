#!/usr/bin/env bash
set -euo pipefail
pip install --upgrade pip >/dev/null 2>&1 || true

# Python tools
pip install black ruff md-toc >/dev/null 2>&1 || true

# Node tools
npm -g install prettier markdownlint-cli >/dev/null 2>&1 || true
