#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Help Function
# -----------------------------------------------------------------------------
show_help() {
  echo "Usage: $0 [--what/-w all|r|python|julia|r_py] [--force/-f] [--help/-h]"
  echo "  --what/-w: Specify what to initialise (default: all)."
  echo "    all: Initialise R (renv), Python (uv), and Julia (project)."
  echo "    r: Initialise R (renv)."
  echo "    python: Initialise Python (uv)."
  echo "    julia: Initialise Julia (project)."
  echo "  --force/-f: Force initialisation regardless of existing files."
  echo "  --help/-h: Show this help message."
}

# -----------------------------------------------------------------------------
# R Initialisation (renv + CmdStan)
# -----------------------------------------------------------------------------
initialise_r() {
  local deps=$1
  # パッケージリストをRのベクトル形式に変換
  deps_vector=$(echo "${deps}" | sed 's/,/","/g')
  
  echo "----------------------------------------------------------------"
  echo "Initializing R environment..."

  # リポジトリ設定: 
  # 1. STAN: cmdstanr用
  # 2. PPM: Linux用バイナリ(高速インストール用)
  # 3. CRAN: バックアップ
  local R_REPO_SETUP="options(repos = c(STAN = 'https://mc-stan.org/r-packages/', PPM = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest', CRAN = 'https://cloud.r-project.org'))"
  
  # --- renv Setup ---
  if [ "${FORCE}" = false ] && [ -f "renv.lock" ]; then
    echo "Found renv.lock."
    
    # renvの足場(activate.R)がない場合の修復
    if [ ! -f "renv/activate.R" ]; then
      echo "renv infrastructure missing. Scaffolding..."
      Rscript -e "if (!requireNamespace('renv', quietly = TRUE)) install.packages('renv'); renv::scaffold()"
    fi

    echo "Restoring environment from lockfile..."
    # Restore実行
    Rscript -e "${R_REPO_SETUP}; if (!requireNamespace('renv', quietly = TRUE)) install.packages('renv'); renv::restore(prompt = FALSE)"
  
  else
    # 新規作成または強制再作成
    echo "Creating new R environment..."
    if [ -f ".Rprofile" ] && grep -q 'source("renv/activate.R")' .Rprofile; then
      sed -i '/source("renv\/activate.R")/d' .Rprofile
    fi
    
    # init -> install -> snapshot
    Rscript -e "${R_REPO_SETUP}; renv::init(bare = FALSE)"
    Rscript -e "${R_REPO_SETUP}; renv::install(c('${deps_vector}'))"
    Rscript -e 'renv::snapshot(type = "all", prompt = FALSE)'
  fi

  # --- CmdStan Setup (ここが追加箇所) ---
  echo "----------------------------------------------------------------"
  echo "Checking CmdStan setup..."
  
  # cmdstanrを使ってCmdStan本体(C++バックエンド)の状態を確認し、なければインストールする
  Rscript -e "
    ${R_REPO_SETUP}
    # renv環境内にcmdstanrがあるはずだが、念の為チェック
    if (!requireNamespace('cmdstanr', quietly = TRUE)) {
       message('cmdstanr not found in library, installing...');
       install.packages('cmdstanr');
    }
    
    library(cmdstanr)
    
    # CmdStanがインストールされているかチェック
    # (デフォルトでは ~/.cmdstan/ 以下を確認します)
    if (is.null(cmdstan_version(error_on_missing = FALSE))) {
      message('CmdStan binaries not found. Installing now (this may take a few minutes)...')
      check_cmdstan_toolchain(fix = TRUE)
      install_cmdstan(cores = 4)
    } else {
      message(paste('CmdStan is already installed at:', cmdstan_path()))
    }
  "
}

# -----------------------------------------------------------------------------
# Python Initialisation (uv)
# -----------------------------------------------------------------------------
initialise_uv() {
  local deps=$1
  deps_space=$(echo "${deps}" | sed 's/,/ /g')

  echo "----------------------------------------------------------------"
  echo "Initializing Python (uv) environment..."

  # uv コマンドがない場合はインストール
  if ! command -v uv &> /dev/null; then
    echo "uv not found. Installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.cargo/env
  fi

  if [ "${FORCE}" = false ] && [ -f "uv.lock" ]; then
    echo "Found uv.lock. Syncing environment..."
    uv sync
    # .venvをアクティベートできるか確認
    if [ -f ".venv/bin/activate" ]; then
      source .venv/bin/activate
    fi
  else
    echo "Creating new Python environment..."
    if [ "${FORCE}" = true ]; then
      rm -rf .venv uv.lock pyproject.toml
    fi
    
    # プロジェクト初期化
    uv init --no-package --vcs none --bare --no-readme --author-from none
    uv venv
    source .venv/bin/activate
    
    if [ -n "${deps_space}" ]; then
      echo "Adding packages: ${deps_space}"
      uv add ${deps_space}
    fi
    uv sync
  fi
}

# -----------------------------------------------------------------------------
# Julia Initialisation
# -----------------------------------------------------------------------------
initialise_julia() {
  local deps=$1
  deps_vector=$(echo "${deps}" | sed 's/,/","/g')

  echo "----------------------------------------------------------------"
  echo "Initializing Julia environment..."

  if [ "${FORCE}" = false ] && [ -f "Project.toml" ]; then
    echo "Found Project.toml. Instantiating environment..."
    julia --project=. -e 'using Pkg; Pkg.instantiate()'
  else
    echo "Creating new Julia environment..."
    if [ "${FORCE}" = true ]; then
       rm -f Project.toml Manifest.toml
    fi
    julia --project=. -e "using Pkg; Pkg.activate(\".\"); Pkg.add([\"${deps_vector}\"])"
  fi
}

# -----------------------------------------------------------------------------
# Main Execution Logic
# -----------------------------------------------------------------------------

WHAT="all"
FORCE=false

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --what|-w)
      WHAT="$2"
      shift
      ;;
    --force|-f)
      FORCE=true
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown parameter passed: $1"
      show_help
      exit 1
      ;;
  esac
  shift
done

# --- Package Lists ---
# R: cmdstanr, brms, posterior, bayesplot を追加
R_PKGS="cmdstanr,brms,posterior,bayesplot,tidyverse,easystats,marginaleffects,modelsummary,rms,Hmisc,rmsb,skimr,reticulate,survival,languageserver"

# Python: pymc, arviz, jupyter, ipykernel を追加 (Quarto連携に必須)
PY_PKGS="pymc,arviz,jupyter,ipykernel,radian,jedi,pandas,polars,tableone,marginaleffects,matplotlib,seaborn,plotnine,papermill"

# Julia: IJulia
JULIA_PKGS="IJulia,Turing,DataFrames,DataFramesMeta,Plots"

case ${WHAT} in
  all)
    initialise_r "${R_PKGS}"
    initialise_uv "${PY_PKGS}"
    initialise_julia "${JULIA_PKGS}"
    ;;
  r)
    initialise_r "${R_PKGS}"
    ;;
  python)
    initialise_uv "${PY_PKGS}"
    ;;
  julia)
    initialise_julia "${JULIA_PKGS}"
    ;;
  r_py)
    initialise_r "${R_PKGS}"
    initialise_uv "${PY_PKGS}"
    ;;
  *)
    echo "Unknown option for --what: ${WHAT}"
    show_help
    exit 1
    ;;
esac
