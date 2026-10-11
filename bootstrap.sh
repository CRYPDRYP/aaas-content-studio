#!/usr/bin/env bash
#
# bootstrap.sh — the ONE command a total novice needs to run to get their own
# working, branded Hermes agent. No CLI flags to memorize, no Hermes
# experience required.
#
# Usage (from inside this folder, after downloading/unzipping/cloning it):
#   ./bootstrap.sh
#
# What this does, in plain English:
#   1. Checks whether the `hermes` command is already on this computer.
#      If not, installs it automatically using the official Nous Research
#      installer (the same one-liner from hermes-agent.nousresearch.com).
#   2. Asks a handful of plain-English questions about your business
#      (name, phone, location, what kind of business) — no typing of
#      commands or flags required.
#   3. Runs the existing setup.sh in this folder with your answers (this
#      script is a friendly wrapper around setup.sh, it does not replace or
#      duplicate its logic).
#   4. Offers to walk you straight into adding your API key (the fastest
#      path is the free Nous Portal login — no separate account signup for
#      a model provider).
#   5. Tells you exactly what to type next to start talking to your agent.
#
# Requires: bash, curl. Everything else (git, hermes) is installed for you
# if missing.
#
# Safe to run more than once — it will refuse to overwrite an existing
# profile and tell you how to remove it first if you want a clean redo.

set -euo pipefail

# ---------------------------------------------------------------------------
# Pretty output helpers
# ---------------------------------------------------------------------------
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

say()      { echo -e "${CYAN}→${NC} $1"; }
ok()       { echo -e "${GREEN}✓${NC} $1"; }
warn()     { echo -e "${YELLOW}⚠${NC} $1"; }
fail()     { echo -e "${RED}✗${NC} $1" >&2; }
heading()  { echo ""; echo -e "${BOLD}$1${NC}"; echo ""; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

banner() {
  echo ""
  echo -e "${BOLD}┌─────────────────────────────────────────────────────────────┐${NC}"
  echo -e "${BOLD}│   Autonomous Anonymous — Agent-as-a-Service Bootstrap        │${NC}"
  echo -e "${BOLD}│   Set up your own branded Hermes AI agent in a few minutes   │${NC}"
  echo -e "${BOLD}└─────────────────────────────────────────────────────────────┘${NC}"
  echo ""
}

# ---------------------------------------------------------------------------
# Sanity check: are we actually inside the distribution folder?
# ---------------------------------------------------------------------------
require_sibling_files() {
  local missing=()
  for f in setup.sh distribution.yaml templates/client-soul.md.template; do
    [ -f "$SCRIPT_DIR/$f" ] || missing+=("$f")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    fail "This doesn't look like a complete download. Missing:"
    for f in "${missing[@]}"; do echo "    - $f" >&2; done
    fail "Re-download or re-clone the full autonomous-anonymous-aaas folder and try again."
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Step 1: make sure the `hermes` command exists
# ---------------------------------------------------------------------------
ensure_hermes_installed() {
  heading "Step 1 of 4 — Checking for Hermes Agent"

  if command -v hermes >/dev/null 2>&1; then
    ok "Hermes is already installed ($(hermes --version 2>&1 | head -1))."
    return
  fi

  warn "Hermes is not installed on this computer yet."
  say "Installing it now using the official Nous Research installer..."
  say "(This only downloads and sets up Hermes Agent itself — it will ask you"
  say " later, in Step 3, for the business details for YOUR agent.)"
  echo ""

  if ! command -v curl >/dev/null 2>&1; then
    fail "curl is required to install Hermes and isn't available. Please install curl first, then re-run this script."
    exit 1
  fi

  # The official one-liner from https://hermes-agent.nousresearch.com/install.sh
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash

  # Installer adds hermes to the user's shell rc files; also try the two most
  # common install locations directly so the rest of THIS script (running in
  # the current shell) can find it without asking the user to open a new tab.
  export PATH="$HOME/.local/bin:$PATH"

  if ! command -v hermes >/dev/null 2>&1; then
    fail "Hermes was installed but isn't on PATH in this terminal session yet."
    fail "Close this terminal, open a brand new one, and run ./bootstrap.sh again."
    exit 1
  fi

  ok "Hermes installed: $(hermes --version 2>&1 | head -1)"
}

# ---------------------------------------------------------------------------
# Step 2: ask plain-English questions
# ---------------------------------------------------------------------------
ask() {
  # $1 = prompt text, $2 = default (optional)
  local prompt="$1" default="${2:-}" answer
  if [ -n "$default" ]; then
    read -r -p "$prompt [$default]: " answer
    echo "${answer:-$default}"
  else
    read -r -p "$prompt: " answer
    echo "$answer"
  fi
}

slugify() {
  # lowercase, strip anything that isn't a-z 0-9 - _, collapse repeats
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_-]+/-/g; s/-+/-/g; s/^-|-$//g'
}

collect_business_details() {
  heading "Step 2 of 4 — Tell us about your business"
  say "These answers get baked directly into your agent's identity and"
  say "every piece of content it writes — so use your REAL details."
  echo ""

  BUSINESS_NAME="$(ask "Business name (e.g. Acme Plumbing)")"
  while [ -z "$BUSINESS_NAME" ]; do
    warn "Business name can't be empty."
    BUSINESS_NAME="$(ask "Business name (e.g. Acme Plumbing)")"
  done

  PHONE="$(ask "Business phone number (e.g. 555-123-4567)")"
  LOCATION="$(ask "City, State (e.g. Springfield, IL)")"
  INDUSTRY="$(ask "What kind of business is it? (e.g. plumbing)")"

  local suggested_slug
  suggested_slug="$(slugify "$BUSINESS_NAME")"
  [ -n "$suggested_slug" ] || suggested_slug="myagent"

  echo ""
  say "Your agent needs a short internal name (letters/numbers/hyphens only)."
  say "This is what you'll type to talk to it, e.g. '$suggested_slug chat'."
  PROFILE_NAME="$(ask "Agent short name" "$suggested_slug")"
  PROFILE_NAME="$(slugify "$PROFILE_NAME")"

  while ! [[ "$PROFILE_NAME" =~ ^[a-z0-9_-]+$ ]] || [ -z "$PROFILE_NAME" ]; do
    warn "That didn't turn into a valid name. Use only letters, numbers, hyphens, underscores."
    PROFILE_NAME="$(slugify "$(ask "Agent short name" "$suggested_slug")")"
  done

  HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
  local profile_dir="$HERMES_HOME/profiles/$PROFILE_NAME"
  if [ -d "$profile_dir" ]; then
    echo ""
    warn "An agent named '$PROFILE_NAME' already exists at $profile_dir."
    local choice
    choice="$(ask "Pick a different name, or type 'delete' to remove the old one first" "")"
    if [ "$choice" = "delete" ]; then
      say "Removing the existing '$PROFILE_NAME' profile..."
      hermes profile delete "$PROFILE_NAME" -y
      ok "Old profile removed."
    else
      PROFILE_NAME="$(slugify "$choice")"
      while [ -z "$PROFILE_NAME" ] || [ -d "$HERMES_HOME/profiles/$PROFILE_NAME" ]; do
        PROFILE_NAME="$(slugify "$(ask "Another agent short name")")"
      done
    fi
  fi

  echo ""
  echo "  Business name:  $BUSINESS_NAME"
  echo "  Phone:          $PHONE"
  echo "  Location:       $LOCATION"
  echo "  Industry:       $INDUSTRY"
  echo "  Agent name:     $PROFILE_NAME"
  echo ""
  local confirm
  confirm="$(ask "Look right? (y/n)" "y")"
  if [[ ! "$confirm" =~ ^[Yy] ]]; then
    say "No problem, let's try again."
    collect_business_details
  fi
}

# ---------------------------------------------------------------------------
# Step 3: run the real setup.sh with the collected answers
# ---------------------------------------------------------------------------
run_setup() {
  heading "Step 3 of 4 — Creating your agent"
  "$SCRIPT_DIR/setup.sh" "$PROFILE_NAME" "$BUSINESS_NAME" "$PHONE" "$LOCATION" "$INDUSTRY"
}

# ---------------------------------------------------------------------------
# Step 4: API keys
# ---------------------------------------------------------------------------
offer_api_key_setup() {
  heading "Step 4 of 4 — Connect your AI model (API key)"
  say "Your agent needs an API key so it can actually think — this is the"
  say "only step that costs money (usage-based, pay-as-you-go, no AA fee)."
  echo ""
  echo "  1) Nous Portal (recommended — fastest, one login, no separate"
  echo "     provider account needed)"
  echo "  2) I'll enter my own API key(s) by hand (Anthropic/OpenAI/etc.)"
  echo "  3) Skip for now — I'll run '$PROFILE_NAME setup' myself later"
  echo ""
  local choice
  choice="$(ask "Choose 1, 2, or 3" "1")"
  case "$choice" in
    1)
      say "Launching Nous Portal setup for '$PROFILE_NAME'..."
      hermes -p "$PROFILE_NAME" setup --portal || warn "Portal setup didn't finish — you can re-run '$PROFILE_NAME setup --portal' any time."
      ;;
    2)
      say "Launching the full setup wizard for '$PROFILE_NAME'..."
      hermes -p "$PROFILE_NAME" setup || warn "Setup wizard didn't finish — you can re-run '$PROFILE_NAME setup' any time."
      ;;
    *)
      warn "Skipping. Your agent won't respond until you run: $PROFILE_NAME setup"
      ;;
  esac
}

print_next_steps() {
  heading "You're set up!"
  echo -e "${BOLD}Business:${NC}  $BUSINESS_NAME"
  echo -e "${BOLD}Agent:${NC}     $PROFILE_NAME"
  echo ""
  echo "Talk to your agent:"
  echo -e "  ${GREEN}$PROFILE_NAME chat${NC}"
  echo ""
  echo "Put it on Telegram so your team/customers can message it:"
  echo -e "  ${GREEN}$PROFILE_NAME gateway start${NC}"
  echo ""
  echo "Change API keys or models later:"
  echo -e "  ${GREEN}$PROFILE_NAME setup${NC}"
  echo ""
  echo "Full written guide (troubleshooting, FAQ, support contact):"
  echo -e "  ${GREEN}GETTING_STARTED.md${NC} in this folder"
  echo ""
  echo "Remove this agent completely later:"
  echo -e "  ${GREEN}hermes profile delete $PROFILE_NAME${NC}"
  echo ""
}

main() {
  banner
  require_sibling_files
  ensure_hermes_installed
  collect_business_details
  run_setup
  offer_api_key_setup
  print_next_steps
}

main "$@"
