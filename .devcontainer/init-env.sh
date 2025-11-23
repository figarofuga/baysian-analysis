#!/bin/bash
set -e

echo ">>> 1. R Setup (CmdStan & brms) <<<"
# CmdStanRのインストールとCmdStan本体のセットアップ
Rscript -e "install.packages('cmdstanr', repos = c('https://mc-stan.org/r-packages/', getOption('repos')))"
Rscript -e "library(cmdstanr); check_cmdstan_toolchain(fix = TRUE); install_cmdstan(cores = 4)"
# brms等のインストール (Linuxバイナリを使う設定になっているので高速です)
Rscript -e "install.packages(c('brms', 'tidyverse', 'posterior', 'bayesplot'))"


echo ">>> 2. Python Setup (uv & PyMC/Bambi) <<<"
# uvのインストール
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

# 仮想環境作成とパッケージインストール
uv init --no-package --vcs none --bare
uv venv
source .venv/bin/activate

# QuartoでPythonを使うには 'jupyter' が必須です
uv pip install pymc arviz bambi jupyter pandas numpy matplotlib


echo ">>> 3. Julia Setup (Turing) <<<"
# QuartoでJuliaを使うには 'IJulia' が必須です
julia -e 'using Pkg; Pkg.add(["Turing", "DataFrames", "StatsPlots", "IJulia"])'


echo ">>> Setup Complete! <<<"
