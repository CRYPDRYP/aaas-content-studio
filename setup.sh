#!/usr/bin/env bash
#
# setup.sh — spin up a new client Hermes agent from this distribution.
#
# Usage:
#   ./setup.sh <client-profile-name> "<Business Name>" "<Phone>" "<Location>" "<Industry>"
#
# Example:
#   ./setup.sh acmeplumbing "Acme Plumbing" "555-123-4567" \
#     "Springfield, IL" "plumbing"
#
# What this does:
#   1. Runs `hermes profile create <client-profile-name> --clone-from default`
#      (clones config.yaml, .env, SOUL.md, and skills from your `default`
#      profile so the new client agent starts from your working setup).
#   2. Substitutes {{BUSINESS_NAME}}, {{PHONE}}, {{LOCATION}}, {{INDUSTRY}}
#      placeholders from templates/*.template and overlays the results onto
#      the new profile's SOUL.md and config.yaml.
#   3. Copies templates/.env.EXAMPLE next to the profile's real .env as a
#      reference (never overwrites the real .env — that already has your
#      cloned API keys).
#   4. Copies skills/ and cron/ from this distribution into the new profile
#      (merge, does not delete anything already cloned from default).
#   5. Prints next steps.
#
# Requires: hermes CLI on PATH, bash, sed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0 <client-profile-name> "<Business Name>" "<Phone>" "<Location>" "<Industry>"

Example:
  $0 acmeplumbing "Acme Plumbing" "555-123-4567" "Springfield, IL" "plumbing"
EOF
  exit 1
}

if [ "$#" -ne 5 ]; then
  usage
fi

PROFILE_NAME="$1"
BUSINESS_NAME="$2"
PHONE="$3"
LOCATION="$4"
INDUSTRY="$5"

# --- validate profile name (Hermes requires lowercase alphanumeric, hyphens/underscores ok) ---
if ! [[ "$PROFILE_NAME" =~ ^[a-z0-9_-]+$ ]]; then
  echo "error: profile name must be lowercase alphanumeric (hyphens/underscores ok): '$PROFILE_NAME'" >&2
  exit 1
fi

if ! command -v hermes >/dev/null 2>&1; then
  echo "error: 'hermes' CLI not found on PATH." >&2
  exit 1
fi

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
PROFILE_DIR="$HERMES_HOME/profiles/$PROFILE_NAME"

echo "==> Creating Hermes profile '$PROFILE_NAME' (cloned from default)..."
if [ -d "$PROFILE_DIR" ]; then
  echo "error: profile directory already exists at $PROFILE_DIR — pick a different name or delete it first with:" >&2
  echo "  hermes profile delete $PROFILE_NAME" >&2
  exit 1
fi

hermes profile create "$PROFILE_NAME" --clone-from default

if [ ! -d "$PROFILE_DIR" ]; then
  echo "error: expected profile directory not found at $PROFILE_DIR after 'hermes profile create' — aborting before touching anything." >&2
  exit 1
fi

# --- placeholder substitution helper (sed with a safe delimiter) ---
substitute() {
  # $1 = input template path, $2 = output path
  sed \
    -e "s|{{BUSINESS_NAME}}|$BUSINESS_NAME|g" \
    -e "s|{{PHONE}}|$PHONE|g" \
    -e "s|{{LOCATION}}|$LOCATION|g" \
    -e "s|{{INDUSTRY}}|$INDUSTRY|g" \
    "$1" > "$2"
}

echo "==> Substituting placeholders into SOUL.md..."
SOUL_TEMPLATE="$SCRIPT_DIR/templates/client-soul.md.template"
if [ -f "$SOUL_TEMPLATE" ]; then
  substitute "$SOUL_TEMPLATE" "$PROFILE_DIR/SOUL.md"
else
  echo "warning: $SOUL_TEMPLATE not found, skipping SOUL.md customization" >&2
fi

echo "==> Substituting placeholders into config.yaml overlay..."
CONFIG_TEMPLATE="$SCRIPT_DIR/templates/client-config.yaml.template"
if [ -f "$CONFIG_TEMPLATE" ]; then
  RENDERED_CONFIG="$PROFILE_DIR/.client-config.rendered.yaml"
  substitute "$CONFIG_TEMPLATE" "$RENDERED_CONFIG"
  # The client-config template is a small, curated overlay (model, toolsets,
  # environment_hint, memory limits, etc.) — not a full config.yaml. We keep
  # it alongside config.yaml as a rendered reference and merge the one field
  # that matters most on every run (agent.environment_hint) directly into
  # the cloned config.yaml, since that's the field every downstream skill
  # and cron job depends on to know which business it's serving.
  python3 - "$PROFILE_DIR/config.yaml" "$RENDERED_CONFIG" <<'PYEOF' || echo "warning: could not auto-merge environment_hint into config.yaml — merge $RENDERED_CONFIG by hand" >&2
import sys, re

config_path, rendered_path = sys.argv[1], sys.argv[2]

with open(rendered_path) as f:
    rendered = f.read()

m = re.search(r"^  environment_hint: \|\n((?:^    .*\n?)*)", rendered, re.MULTILINE)
if not m:
    sys.exit(1)

hint_block = m.group(0)  # "  environment_hint: |\n    ...\n"

with open(config_path) as f:
    config = f.read()

if "environment_hint:" in config:
    # Replace the existing environment_hint block (key + its indented literal-block lines)
    config = re.sub(
        r"^  environment_hint:.*\n(^    .*\n)*",
        hint_block,
        config,
        count=1,
        flags=re.MULTILINE,
    )
else:
    # No agent.environment_hint present at all — append under the agent: section if found,
    # otherwise append a new agent: section at the end.
    if re.search(r"^agent:\s*$", config, re.MULTILINE):
        config = re.sub(r"^(agent:\s*\n)", r"\1" + hint_block, config, count=1, flags=re.MULTILINE)
    else:
        config = config.rstrip("\n") + "\n\nagent:\n" + hint_block

with open(config_path, "w") as f:
    f.write(config)

print("environment_hint merged into config.yaml")
PYEOF
else
  echo "warning: $CONFIG_TEMPLATE not found, skipping config.yaml customization" >&2
fi

echo "==> Copying .env.EXAMPLE reference (does not touch the cloned .env with your real keys)..."
ENV_EXAMPLE="$SCRIPT_DIR/templates/.env.EXAMPLE"
if [ -f "$ENV_EXAMPLE" ]; then
  substitute "$ENV_EXAMPLE" "$PROFILE_DIR/.env.EXAMPLE"
fi

echo "==> Merging distribution skills/ into the new profile (does not remove cloned skills)..."
if [ -d "$SCRIPT_DIR/skills" ]; then
  find "$SCRIPT_DIR/skills" -mindepth 1 -maxdepth 1 -type d | while read -r skill_dir; do
    skill_name="$(basename "$skill_dir")"
    cp -R "$skill_dir" "$PROFILE_DIR/skills/$skill_name"
    echo "   + skill: $skill_name"
  done
fi

echo "==> Merging distribution cron/ jobs into the new profile..."
if [ -d "$SCRIPT_DIR/cron" ]; then
  find "$SCRIPT_DIR/cron" -mindepth 1 -maxdepth 1 -name '*.json' | while read -r job_file; do
    cp "$job_file" "$PROFILE_DIR/cron/$(basename "$job_file")"
    echo "   + cron job: $(basename "$job_file")"
  done
fi

echo ""
echo "=================================================================="
echo " Client agent '$PROFILE_NAME' is ready."
echo "=================================================================="
echo ""
echo "Business:  $BUSINESS_NAME"
echo "Industry:  $INDUSTRY"
echo "Location:  $LOCATION"
echo "Phone:     $PHONE"
echo "Profile:   $PROFILE_DIR"
echo ""
echo "Next steps:"
echo "  1. Review/edit the customized files:"
echo "       $PROFILE_DIR/SOUL.md"
echo "       $PROFILE_DIR/config.yaml   (agent.environment_hint was merged in)"
echo "  2. Fill in real API keys (cloned .env already has your default keys;"
echo "     add client-specific ones per templates/.env.EXAMPLE if needed):"
echo "       $PROFILE_NAME setup"
echo "  3. Start chatting as the new client agent:"
echo "       $PROFILE_NAME chat"
echo "  4. Or start its messaging gateway:"
echo "       $PROFILE_NAME gateway start"
echo ""
echo "To remove this client agent later:"
echo "  hermes profile delete $PROFILE_NAME"
echo ""
