#!/usr/bin/env bash
# ============================================================
# Local AI Installer — Arch Linux + NVIDIA
# ============================================================
# Installs llama.cpp with CUDA, downloads Qwen models, sets up
# a server with systemd, and configures OpenCode.
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

# Model — repo id only (hf CLI doesn't accept ":QUANT")
MODEL_9B="Abiray/Qwen3.5-9B-abliterated-GGUF"

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
  -h, --help      this message
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
elif command -v lspci >/dev/null 2>&1; then
    if lspci | grep -qiE "nvidia|geforce|quadro|tesla"; then
        ok "NVIDIA GPU detected (via lspci)"
    else
        die "No NVIDIA GPU detected"
    fi
else
    die "Cannot detect GPU — install pciutils or nvidia-utils"
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

# ─── Step 5: Models ──────────────────────────────────────────
say "Step 5/6 — Checking models..."
mkdir -p "$MODELS_DIR"

have_file() {
    local pattern="$1"
    compgen -G "$MODELS_DIR/$pattern" >/dev/null 2>&1
}

if [[ $SKIP_MODELS -eq 1 ]]; then
    warn "Skipping model downloads (--skip-models)"
fi

# ── 9B abliterated (Q3_K_M — cabe na 1660 Ti) ────────────────
if have_file "Qwen3.5-9B-abliterated-Q3_K_M.gguf"; then
    ok "Qwen3.5-9B abliterated already present"
elif [[ $SKIP_MODELS -eq 0 ]]; then
    say "Downloading Qwen3.5-9B abliterated Q3_K_M (~4.6 GB)..."
    hf download "$MODEL_9B" \
        --include "*Q3_K_M*.gguf" \
        --local-dir "$MODELS_DIR" \
        --quiet
    ok "Qwen3.5-9B abliterated ready"
else
    warn "Qwen3.5-9B abliterated not found and --skip-models is on"
fi

# ─── Step 6: Server script + systemd ─────────────────────────
say "Step 6/6 — Setting up the server..."

mkdir -p "$BIN_DIR"

cat > "$BIN_DIR/ai-server" <<EOF
#!/bin/bash
cd $LLAMA_DIR
exec ./build/bin/llama-server \
  --models-dir $MODELS_DIR \
  --no-models-autoload \
  --host 127.0.0.1 \
  --port $PORT \
  --parallel 1 \
  -ngl 99 \
  -c 32768 \
  -b 512 \
  -ub 512 \
  --jinja \
  --chat-template-kwargs '{"enable_thinking": false}' \
  --flash-attn on \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --sleep-idle-seconds 30
EOF
chmod +x "$BIN_DIR/ai-server"
ok "ai-server created at $BIN_DIR/ai-server"

# Systemd service
mkdir -p "$SERVICE_DIR"
cat > "$SERVICE_DIR/$SERVICE_NAME" <<EOF
[Unit]
Description=llama.cpp server (Local AI)
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
    ok "Service running"
else
    warn "Service not up yet — check with: systemctl --user status $SERVICE_NAME"
fi

# ─── Step 7: OpenCode ────────────────────────────────────────
if [[ $WITH_OPENCODE -eq 1 ]]; then
    say "Step 7/7 — Setting up OpenCode..."

    if ! command -v opencode >/dev/null 2>&1; then
        if [[ -n "$AUR" ]]; then
            say "Installing opencode-bin via $AUR..."
            "$AUR" -S --needed --noconfirm opencode-bin || warn "Failed to install opencode-bin — install it manually"
        else
            warn "No AUR helper (paru/yay) found — cannot install opencode-bin"
            warn "Install it manually: yay -S opencode-bin"
        fi
    else
        ok "OpenCode already installed"
    fi

    if command -v opencode >/dev/null 2>&1; then
        mkdir -p "$(dirname "$OPENCODE_CONFIG")"

        if [[ -f "$OPENCODE_CONFIG" ]] && grep -q "llama.cpp" "$OPENCODE_CONFIG" 2>/dev/null; then
            ok "OpenCode already configured for llama.cpp (keeping existing config)"
        else
            if [[ -f "$OPENCODE_CONFIG" ]]; then
                cp "$OPENCODE_CONFIG" "$OPENCODE_CONFIG.backup-$(date +%Y%m%d-%H%M%S)"
                warn "Existing OpenCode config backed up"
            fi

            cat > "$OPENCODE_CONFIG" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "llama.cpp": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama-server (local)",
      "options": {
        "baseURL": "http://127.0.0.1:8080/v1"
      },
      "models": {
        "Qwen3.5-9B-abliterated-Q3_K_M": {
          "name": "Qwen3.5 9B abliterated (local)"
        }
      }
    }
  }
}
EOF
            ok "OpenCode configured at $OPENCODE_CONFIG"
        fi
    fi
else
    say "Skipping OpenCode (--no-opencode)"
fi

# ─── fish abbr ───────────────────────────────────────────────
if command -v fish >/dev/null; then
    if ! grep -q "abbr --add ia" "$FISH_CONFIG" 2>/dev/null; then
        cat >> "$FISH_CONFIG" <<'EOF'

# Local AI
abbr --add ia 'helium-browser http://localhost:8080'
EOF
        ok "fish abbr 'ia' added"
    fi
fi

# ─── Done ────────────────────────────────────────────────────
echo
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo
echo -e "  ${BLUE}Server:${NC}      systemctl --user status $SERVICE_NAME"
echo -e "  ${BLUE}Interface:${NC}   http://localhost:$PORT"
echo -e "  ${BLUE}Models:${NC}      $MODELS_DIR"
echo -e "  ${BLUE}Script:${NC}      $BIN_DIR/ai-server"
echo -e "  ${BLUE}OpenCode:${NC}    $(command -v opencode >/dev/null 2>&1 && echo "configured" || echo "not installed")"
echo
echo -e "  ${YELLOW}Useful commands:${NC}"
echo
echo "    systemctl --user restart $SERVICE_NAME   # restart"
echo "    systemctl --user stop $SERVICE_NAME      # stop"
echo "    journalctl --user -u $SERVICE_NAME -f    # follow logs"
echo "    pkill -f llama-server                    # kill everything"
echo "    opencode                                 # run OpenCode"
echo
echo -e "  ${YELLOW}Models in $MODELS_DIR:${NC}"
for f in "$MODELS_DIR"/*.gguf; do
    [[ -f "$f" ]] && echo "    • $(basename "$f")"
done
echo
echo -e "  ${YELLOW}To open:${NC} open Helium at http://localhost:$PORT"
echo -e "  or type ${GREEN}ia${NC} (opens in Terminal) if you use fish shell"
echo -e "  or type ${GREEN}opencode${NC} to run the AI agent in your terminal"
echo