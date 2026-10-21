#!/usr/bin/env bash
# ============================================================
# Local AI Installer — Arch Linux + NVIDIA (1660 Ti+)
# ============================================================
# Installs llama.cpp with CUDA, downloads LFM2.5-8B-A1B-Uncensored,
# sets up systemd, and configures OpenCode.
#
# Usage: ./install-ai-local.sh [--skip-models] [--no-opencode]
# ============================================================

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────
MODELS_DIR="$HOME/models"
BIN_DIR="$HOME/bin"
LLAMA_DIR="$HOME/llama.cpp"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="llama-server.service"
PORT=8080
OPENCODE_CONFIG="$HOME/.config/opencode/opencode.json"

# Model — LFM2.5-8B-A1B-Uncensored
MODEL_FILE="LFM2.5-8B-A1B-Uncensored-Q3_K_M.gguf"
MODEL_REPO="zaakirio/LFM2.5-8B-A1B-Uncensored-GGUF"

# Model id exposed by llama-server at /v1/models
MODEL_ID="LFM2.5-8B-A1B-Uncensored-Q3_K_M"
MODEL_LABEL="LFM2.5 8B A1B Uncensored Q3_K_M (local)"

# Context and generation
CTX_SIZE=32768
N_PREDICT=32768
BATCH_SIZE=4096
UBATCH_SIZE=4096

# Colors
AI_BORDER='\033[38;5;130m'
AI_ACCENT='\033[38;5;166m'
AI_PRIMARY='\033[38;5;172m'
AI_TEXT='\033[38;5;255m'
AI_MUTED='\033[38;5;245m'
AI_WARNING='\033[38;5;202m'
AI_ERROR='\033[38;5;196m'
AI_RESET='\033[0m'
BANNER_WIDTH=70

# ─── Helpers ─────────────────────────────────────────────────
say()  { printf '%b %s\n' "${AI_ACCENT}==>${AI_RESET}" "$*"; }
ok()   { printf '%b %s\n' "${AI_PRIMARY}✓${AI_RESET}" "$*"; }
warn() { printf '%b %s\n' "${AI_WARNING}!${AI_RESET}" "$*"; }
die()  { printf '%b %s\n' "${AI_ERROR}✗${AI_RESET}" "$*" >&2; exit 1; }

banner_rule() {
    local left="$1" right="$2" fill="$3" line="" column
    for ((column = 0; column < BANNER_WIDTH; column++)); do
        line+="$fill"
    done
    printf '%b\n' "${AI_BORDER}${left}${line}${right}${AI_RESET}"
}

banner_row() {
    local plain_text="$1" styled_text="$2"
    local padding=$((BANNER_WIDTH - ${#plain_text}))
    ((padding < 0)) && padding=0
    printf '%b' "${AI_BORDER}│${AI_RESET}"
    printf '%b' "$styled_text"
    printf '%*s' "$padding" ''
    printf '%b\n' "${AI_BORDER}│${AI_RESET}"
}

draw_setup_banner() {
    local title='  ◈  LOCAL AI  ·  INSTALLER'

    banner_rule '╭' '╮' '─'
    banner_row "$title" "${AI_ACCENT}${title}${AI_RESET}"
    banner_rule '├' '┤' '─'
    banner_row '  ◈  Requires Arch Linux and NVIDIA drivers' "${AI_PRIMARY}  ◈${AI_RESET}  ${AI_TEXT}Requires Arch Linux and NVIDIA drivers${AI_RESET}"
    banner_row '  ▣  Builds llama.cpp with CUDA support' "${AI_PRIMARY}  ▣${AI_RESET}  ${AI_TEXT}Builds ${AI_ACCENT}llama.cpp${AI_TEXT} with CUDA support${AI_RESET}"
    banner_row '  ◉  Downloads the model unless --skip-models is used' "${AI_PRIMARY}  ◉${AI_RESET}  ${AI_TEXT}Downloads the model unless ${AI_ACCENT}--skip-models${AI_TEXT} is used${AI_RESET}"
    banner_row '  ⌁  Creates and enables a user systemd service' "${AI_PRIMARY}  ⌁${AI_RESET}  ${AI_TEXT}Creates and enables a user systemd service${AI_RESET}"
    banner_row '  ◇  Updates CUDA PATH and vm.max_map_count' "${AI_PRIMARY}  ◇${AI_RESET}  ${AI_TEXT}Updates CUDA PATH and ${AI_ACCENT}vm.max_map_count${AI_RESET}"
    banner_row '  ▦  OpenCode setup is enabled unless --no-opencode is used' "${AI_PRIMARY}  ▦${AI_RESET}  ${AI_TEXT}OpenCode setup is enabled unless ${AI_ACCENT}--no-opencode${AI_TEXT} is used${AI_RESET}"
    banner_rule '├' '┤' '─'
    banner_row '  !  Review first; uses sudo and requires disk space' "${AI_WARNING}  !${AI_RESET}  ${AI_WARNING}Review first; uses sudo and requires disk space${AI_RESET}"
    banner_rule '╰' '╯' '─'
}

# ─── Parse args ──────────────────────────────────────────────
SKIP_MODELS=0
WITH_OPENCODE=1
for arg in "$@"; do
    case "$arg" in
        --skip-models)  SKIP_MODELS=1 ;;
        --no-opencode)  WITH_OPENCODE=0 ;;
        -h|--help)
            cat <<EOF
Local AI Installer — Arch Linux + NVIDIA

  ./install-ai-local.sh [options]

  --skip-models   don't download any model — just check what exists
  --no-opencode   don't install or configure OpenCode
  -h, --help      show this message
EOF
            exit 0
        ;;
        *) die "unknown option: $arg" ;;
    esac
done

echo
draw_setup_banner
echo

# ─── Preflight ───────────────────────────────────────────────
say "Checking the system..."

[[ -f /etc/arch-release ]] || die "This script is for Arch Linux only"
[[ $EUID -ne 0 ]] || die "Do not run as root"

AUR=""
for helper in paru yay; do
    command -v "$helper" >/dev/null 2>&1 && { AUR="$helper"; break; }
done

if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    if [[ -n "$GPU_NAME" ]]; then
        ok "NVIDIA GPU detected: $GPU_NAME"
    else
        die "nvidia-smi found no GPU"
    fi
else
    die "No NVIDIA GPU detected — install nvidia-utils"
fi

if ! sudo -v; then
    die "sudo is required"
fi

# ─── Step 1: Dependencies ────────────────────────────────────
say "Step 1/6 — Installing dependencies..."

PKGS=(
    base-devel cmake git cuda python-pip
    python-huggingface-hub curl jq pciutils less
)

sudo pacman -S --needed --noconfirm "${PKGS[@]}"
ok "Packages installed"

# ─── Step 2: CUDA PATH ───────────────────────────────────────
say "Step 2/6 — Setting up CUDA PATH..."

FISH_CONFIG="$HOME/.config/fish/config.fish"
mkdir -p "$(dirname "$FISH_CONFIG")"
touch "$FISH_CONFIG"

if ! grep -q "opt/cuda/bin" "$FISH_CONFIG"; then
    cat >> "$FISH_CONFIG" <<'EOF'

# CUDA
fish_add_path /opt/cuda/bin
set -gx CUDACXX /opt/cuda/bin/nvcc
EOF
    ok "CUDA PATH added to config.fish"
else
    ok "CUDA PATH already configured"
fi

export PATH="/opt/cuda/bin:$PATH"
export CUDACXX="/opt/cuda/bin/nvcc"

# ─── Step 3: llama.cpp ───────────────────────────────────────
say "Step 3/6 — Building llama.cpp..."

if [[ -d "$LLAMA_DIR" ]]; then
    warn "$LLAMA_DIR already exists, updating..."
    cd "$LLAMA_DIR"
    git pull --quiet || warn "git pull failed, keeping current version"
else
    git clone https://github.com/ggerganov/llama.cpp "$LLAMA_DIR"
    cd "$LLAMA_DIR"
fi

if [[ ! -f "$LLAMA_DIR/build/bin/llama-server" ]]; then
    say "Building with CUDA (this takes 5-15 min)..."
    cmake -B build -DGGML_CUDA=ON -DGGML_NATIVE=ON -DCMAKE_BUILD_TYPE=Release
    cmake --build build --config Release -j"$(nproc)"
    ok "llama.cpp built"
else
    ok "llama.cpp already built"
fi

# ─── Step 4: sysctl ──────────────────────────────────────────
say "Step 4/6 — Tuning vm.max_map_count..."

SYSCTL_CONF="/etc/sysctl.d/99-llama.conf"
if [[ ! -f "$SYSCTL_CONF" ]] || ! grep -q "vm.max_map_count" "$SYSCTL_CONF" 2>/dev/null; then
    echo 'vm.max_map_count=262144' | sudo tee "$SYSCTL_CONF" > /dev/null
    sudo sysctl --system > /dev/null
    ok "vm.max_map_count = 262144"
else
    ok "vm.max_map_count already configured"
fi

# ─── Step 5: Model download ──────────────────────────────────
say "Step 5/6 — Checking model..."
mkdir -p "$MODELS_DIR"

if [[ $SKIP_MODELS -eq 1 ]]; then
    warn "Skipping model download (--skip-models)"
elif [[ ! -f "$MODELS_DIR/$MODEL_FILE" ]]; then
    say "Downloading $MODEL_FILE ..."
    if hf download "$MODEL_REPO" --include "$MODEL_FILE" --local-dir "$MODELS_DIR" --quiet; then
        ok "LFM2.5-8B-A1B-Uncensored downloaded"
    else
        die "Failed to download $MODEL_FILE"
    fi
else
    ok "LFM2.5-8B-A1B-Uncensored already present"
fi

# ─── Step 6: Server script + systemd ─────────────────────────
say "Step 6/6 — Setting up the server..."

mkdir -p "$BIN_DIR"

cat > "$BIN_DIR/ai-server" <<EOF
#!/usr/bin/env fish

exec $LLAMA_DIR/build/bin/llama-server \\
  --model $MODELS_DIR/$MODEL_FILE \\
  --host 127.0.0.1 \\
  --port $PORT \\
  --parallel 1 \\
  -ngl 100 \\
  -c $CTX_SIZE \\
  -n $N_PREDICT \\
  -b $BATCH_SIZE \\
  -ub $UBATCH_SIZE \\
  --cache-type-k q4_0 --cache-type-v q4_0 \\
  --jinja \\
  --tools all \\
  --agent \\
  --flash-attn on \\
  --sleep-idle-seconds 30
EOF
chmod +x "$BIN_DIR/ai-server"
ok "ai-server created at $BIN_DIR/ai-server"

# Systemd service
mkdir -p "$SERVICE_DIR"
cat > "$SERVICE_DIR/$SERVICE_NAME" <<EOF
[Unit]
Description=llama.cpp server (Local AI — LFM2.5-8B-A1B-Uncensored)
After=network.target

[Service]
Type=simple
ExecStart=$BIN_DIR/ai-server
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now "$SERVICE_NAME" || true

sleep 3
if systemctl --user is-active --quiet "$SERVICE_NAME"; then
    ok "Service running successfully"
else
    warn "Service not up yet — check with: systemctl --user status $SERVICE_NAME"
fi

# ─── Step 7: OpenCode ────────────────────────────────────────
if [[ $WITH_OPENCODE -eq 1 ]]; then
    say "Step 7/7 — Setting up OpenCode..."
    
    if ! command -v opencode >/dev/null 2>&1; then
        if [[ -n "$AUR" ]]; then
            say "Installing opencode-bin via $AUR..."
            "$AUR" -S --needed --noconfirm opencode-bin || warn "Failed to install opencode-bin"
        else
            warn "No AUR helper found — install opencode-bin manually"
        fi
    else
        ok "OpenCode already installed"
    fi
    
    if command -v opencode >/dev/null 2>&1; then
        mkdir -p "$(dirname "$OPENCODE_CONFIG")"
        if [[ -f "$OPENCODE_CONFIG" ]]; then
            cp "$OPENCODE_CONFIG" "$OPENCODE_CONFIG.backup-$(date +%Y%m%d-%H%M%S)"
        fi
        
        cat > "$OPENCODE_CONFIG" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "llama.cpp": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama-server (local)",
      "options": {
        "baseURL": "http://127.0.0.1:$PORT/v1"
      },
      "models": {
        "$MODEL_ID": {
          "name": "$MODEL_LABEL"
        }
      }
    }
  }
}
EOF
        ok "OpenCode configured at $OPENCODE_CONFIG"
    fi
fi

# ─── Done ────────────────────────────────────────────────────
echo
printf '%b\n' "${AI_PRIMARY}═══════════════════════════════════════════════════════════${AI_RESET}"
printf '%b\n' "${AI_ACCENT}  Installation complete!${AI_RESET}"
printf '%b\n' "${AI_PRIMARY}═══════════════════════════════════════════════════════════${AI_RESET}"
echo
printf '%b\n' "  ${AI_ACCENT}Server status:${AI_RESET} systemctl --user status $SERVICE_NAME"
printf '%b\n' "  ${AI_ACCENT}Interface:${AI_RESET}   http://localhost:$PORT"
printf '%b\n' "  ${AI_ACCENT}Model File:${AI_RESET}  $MODEL_FILE"
echo
