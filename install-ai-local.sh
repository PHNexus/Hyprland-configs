#!/usr/bin/env bash
# ============================================================
# Local AI Installer — Arch Linux + NVIDIA (Com Suporte a Visão)
# ============================================================
# Installs llama.cpp with CUDA, downloads Gemma-4-E4B Uncensored
# (HauhauCS Aggressive Q5_K_P) + mmproj, sets up systemd, etc.
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

# Models — Gemma 4 E4B Uncensored HauhauCS Aggressive
MODEL_FILE="Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q5_K_P.gguf"
MMPROJ_FILE="mmproj-Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-f16.gguf"
MODEL_REPO="HauhauCS/Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-GGUF"

# Model id exposto pelo llama-server em /v1/models
MODEL_ID="Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q5_K_P"
MODEL_LABEL="Gemma 4 E4B Uncensored (local + visão)"

# Contexto e geração otimizados para evitar estouro de VRAM na 1660 Ti
CTX_SIZE=16384
N_PREDICT=4096

# Chat template customizado
CHAT_TEMPLATE_FILE="$LLAMA_DIR/models/templates/google-gemma-4-31B-it.jinja"

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

# ─── Helpers ─────────────────────────────────────────────────
say()  { printf "${BLUE}==>${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}!${NC} %s\n" "$*"; }
die()  { printf "${RED}✗${NC} %s\n" "$*" >&2; exit 1; }

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
  -h, --help      dieses message
EOF
            exit 0
            ;;
        *) die "unknown option: $arg" ;;
    esac
done

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

# ─── Step 5: Models & Vision Projector ────────────────────────
say "Step 5/6 — Checking models and mmproj..."
mkdir -p "$MODELS_DIR"

if [[ $SKIP_MODELS -eq 1 ]]; then
    warn "Skipping model downloads (--skip-models)"
fi

if [[ $SKIP_MODELS -eq 0 && -n "${MODEL_REPO:-}" ]]; then
    if [[ ! -f "$MODELS_DIR/$MODEL_FILE" ]]; then
        say "Downloading main model $MODEL_FILE ..."
        hf download "$MODEL_REPO" "$MODEL_FILE" --local-dir "$MODELS_DIR" --quiet
        ok "Gemma-4-E4B Uncensored downloaded"
    else
        ok "Gemma-4-E4B Uncensored already present"
    fi

    if [[ ! -f "$MODELS_DIR/$MMPROJ_FILE" ]]; then
        say "Downloading vision projector $MMPROJ_FILE ..."
        hf download "$MODEL_REPO" "$MMPROJ_FILE" --local-dir "$MODELS_DIR" --quiet
        ok "mmproj projector downloaded"
    else
        ok "mmproj projector already present"
    fi
fi

# ─── Step 6: Server script + systemd ─────────────────────────
say "Step 6/6 — Setting up the server..."

mkdir -p "$BIN_DIR"

if [[ ! -f "$CHAT_TEMPLATE_FILE" ]]; then
    die "CHAT_TEMPLATE_FILE não existe: $CHAT_TEMPLATE_FILE"
fi
ok "Chat template encontrado: $CHAT_TEMPLATE_FILE"

cat > "$BIN_DIR/ai-server" <<EOF
#!/usr/bin/env fish

exec $LLAMA_DIR/build/bin/llama-server \\
  --model $MODELS_DIR/$MODEL_FILE \\
  --mmproj $MODELS_DIR/$MMPROJ_FILE \\
  --host 127.0.0.1 \\
  --port $PORT \\
  --parallel 1 \\
  -ngl 32 \\
  -c $CTX_SIZE \\
  -n $N_PREDICT \\
  -b 256 \\
  -ub 256 \\
  --jinja \\
  --tools all \\
  --chat-template-file $CHAT_TEMPLATE_FILE \\
  --agent \\
  --flash-attn on \\
  --sleep-idle-seconds 120
EOF
chmod +x "$BIN_DIR/ai-server"
ok "ai-server created at $BIN_DIR/ai-server"

# Systemd service
mkdir -p "$SERVICE_DIR"
cat > "$SERVICE_DIR/$SERVICE_NAME" <<EOF
[Unit]
Description=llama.cpp server (Local AI with Vision)
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
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation & Vision Support complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo
echo -e "  ${BLUE}Server status:${NC} systemctl --user status $SERVICE_NAME"
echo -e "  ${BLUE}Interface:${NC}   http://localhost:$PORT"
echo -e "  ${BLUE}Model File:${NC}  $MODEL_FILE"
echo -e "  ${BLUE}Vision Proj:${NC} $MMPROJ_FILE"
echo