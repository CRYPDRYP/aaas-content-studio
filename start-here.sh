#!/usr/bin/env bash
#
# start-here.sh — the ONLY thing you need to run.
#
# What this does:
#   1. Installs Hermes Agent if it isn't already on this computer.
#   2. Installs your own private copy of the Autonomous Anonymous agent
#      (branded, working out of the box — you shape its persona yourself,
#      nothing is pre-filled for a specific business).
#   3. Drops you straight into a chat with it.
#
# Usage: ./start-here.sh
#
set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
say()  { echo -e "${CYAN}→${NC} $1"; }
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${BOLD}┌─────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}│   Autonomous Anonymous — Your Hermes Agent                   │${NC}"
echo -e "${BOLD}└─────────────────────────────────────────────────────────────┘${NC}"
echo ""

# --- Step 1: install hermes if missing ---
if command -v hermes >/dev/null 2>&1; then
  ok "Hermes is already installed ($(hermes --version 2>&1 | head -1))."
else
  warn "Hermes isn't installed yet. Installing it now (official Nous Research installer)..."
  if ! command -v curl >/dev/null 2>&1; then
    fail "curl is required. Install curl first, then re-run this script."
    exit 1
  fi
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
  if ! command -v hermes >/dev/null 2>&1; then
    fail "Hermes installed, but this terminal doesn't see it yet."
    fail "Close this terminal, open a brand new one, and run ./start-here.sh again."
    exit 1
  fi
  ok "Hermes installed: $(hermes --version 2>&1 | head -1)"
fi

# --- Step 2: pick a short name for the agent ---
echo ""
read -r -p "Pick a short name for your agent (letters/numbers, e.g. 'myagent') [myagent]: " PROFILE_NAME
PROFILE_NAME="${PROFILE_NAME:-myagent}"
PROFILE_NAME="$(echo "$PROFILE_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_-]+/-/g; s/-+/-/g; s/^-|-$//g')"
[ -n "$PROFILE_NAME" ] || PROFILE_NAME="myagent"

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
if [ -d "$HERMES_HOME/profiles/$PROFILE_NAME" ]; then
  warn "An agent named '$PROFILE_NAME' already exists."
  read -r -p "Type 'delete' to replace it, or anything else to pick a new name: " choice
  if [ "$choice" = "delete" ]; then
    hermes profile delete "$PROFILE_NAME" -y
    ok "Old profile removed."
  else
    read -r -p "New agent short name: " PROFILE_NAME
    PROFILE_NAME="$(echo "$PROFILE_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_-]+/-/g')"
  fi
fi

# --- Step 3: install the distribution as a real profile ---
echo ""
say "Setting up your agent as '$PROFILE_NAME'..."
hermes profile install "$SCRIPT_DIR" --name "$PROFILE_NAME" --alias -y

# --- Step 4: connect an API key ---
echo ""
echo "Your agent needs an API key so it can actually think — this is the only"
echo "step that costs money (usage-based, pay-as-you-go)."
echo ""
echo "  1) Nous Portal (recommended — fastest, one login)"
echo "  2) Enter my own API key(s) by hand"
echo "  3) Skip for now — I'll run '$PROFILE_NAME setup' myself later"
echo ""
read -r -p "Choose 1, 2, or 3 [1]: " keychoice
keychoice="${keychoice:-1}"
case "$keychoice" in
  1) hermes -p "$PROFILE_NAME" setup --portal || warn "You can re-run: $PROFILE_NAME setup --portal" ;;
  2) hermes -p "$PROFILE_NAME" setup || warn "You can re-run: $PROFILE_NAME setup" ;;
  *) warn "Skipping — run '$PROFILE_NAME setup' before you expect it to respond." ;;
esac

echo ""
echo -e "${BOLD}You're set up!${NC}"
echo ""
echo "Talk to your agent right now:"
echo -e "  ${GREEN}$PROFILE_NAME chat${NC}"
echo ""
echo "Make it yours — edit its persona/instructions any time:"
echo -e "  ${GREEN}~/.hermes/profiles/$PROFILE_NAME/SOUL.md${NC}"
echo ""
echo "Put it on Telegram/WhatsApp so you can message it from your phone:"
echo -e "  ${GREEN}$PROFILE_NAME gateway start${NC}"
echo ""
echo "Remove it completely later:"
echo -e "  ${GREEN}hermes profile delete $PROFILE_NAME${NC}"
echo ""
