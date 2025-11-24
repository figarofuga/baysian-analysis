#!/bin/bash
set -e

# -----------------------------------------------------------------------------
# 1. R Setup (CmdStan & brms)
# -----------------------------------------------------------------------------

echo ">>> 1. R Setup (CmdStan & brms) <<<"
# CmdStanRのインストールとCmdStan本体のセットアップ
Rscript -e "install.packages('cmdstanr', repos = c('https://mc-stan.org/r-packages/', getOption('repos')))"
Rscript -e "library(cmdstanr); check_cmdstan_toolchain(fix = TRUE); install_cmdstan(cores = 4)"
# brms等のインストール (Linuxバイナリを使う設定になっているので高速です)
Rscript -e "install.packages(c('brms', 'tidyverse', 'posterior', 'bayesplot'))"

# -----------------------------------------------------------------------------
# 2. Python Setup (uv & PyMC/Bambi)
# -----------------------------------------------------------------------------

echo ">>> 2. Python Setup (uv & PyMC/Bambi) <<<"
# uvのインストール
# uv のインストール
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # このスクリプト内ですぐ使えるように一時的にsourceする
    export PATH="$HOME/.local/bin:$PATH"
fi


# プロジェクトのセットアップ
if [ -f "pyproject.toml" ]; then
    echo "Found pyproject.toml. Syncing environment..."
    uv sync
else
    echo "No pyproject.toml found. Initializing new environment..."
    uv init --no-package --vcs none --bare
    uv venv
    
    echo "Adding packages: pymc, bambi, arviz, jupyter..."
    uv add pymc arviz bambi jupyter pandas numpy matplotlib
fi

# 仮想環境のアクティベート
source .venv/bin/activate


# -----------------------------------------------------------------------------
# 3. Julia Setup (Turing)
# -----------------------------------------------------------------------------
echo ">>> [Julia] Setting up Environment..."

if [ -f "Project.toml" ]; then
    echo "Found Project.toml. Instantiating environment..."
    julia --project=. -e 'using Pkg; Pkg.instantiate()'
else
    echo "No Project.toml found. Adding packages..."
    julia --project=. -e 'using Pkg; Pkg.add(["Turing", "DataFrames", "StatsPlots", "IJulia"])'
fi

# IJuliaカーネル登録
julia --project=. -e 'using IJulia; IJulia.installkernel("Julia")'

echo ">>> Setup Complete! <<<"
