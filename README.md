# Autonomous Anonymous — Agent-as-a-Service

**Spin up a fully working, branded AI agent for any client in one command.**
Built on [Hermes Agent](https://hermes-agent.nousresearch.com) by Nous
Research.

This is Autonomous Anonymous's internal product for deploying client-facing
AI agents. Two product lines:

- **Business Agent** (this repo) — one agent grounded in a client
  *business* (name/phone/location/industry).
- **Personal Agent** — one agent grounded in a specific *individual's job/
  trade/employer/union*, Jarvis-style persona, delivered as a double-click
  install package for a non-technical recipient. Built per-order in its own
  project directory (never inside this repo). See the
  `personal-agent-builder` skill for the delivery workflow, and
  [PRICING.md](PRICING.md) for the tier.

Both are built so they can go from internal tool → licensed/resold product
without a rewrite. See [PRICING.md](PRICING.md) and [LICENSE.md](LICENSE.md)
for that path.

![Autonomous Anonymous](branding/logo.jpg)

## What you get

Run one script, and you have a new Hermes agent — installed, branded, and
ready to chat — in a few minutes of actual wall-clock time (plus however
long you spend on an API key).

```
autonomous-anonymous-aaas/
├── distribution.yaml    # Hermes profile-distribution manifest
├── start-here.sh         # ★★★ start here — installs Hermes + a generic
│                           branded agent, no business details required
├── bootstrap.sh          # ★★ interactive wrapper for clients who DO want
│                           business-specific grounding (name/phone/etc
│                           baked into the agent's persona)
├── GETTING_STARTED.md    # ★★ zero-assumed-knowledge onboarding guide
├── SOUL.md               # base agent identity (installer fallback)
├── config.yaml           # base agent config (installer fallback)
├── LICENSE.md            # current internal-use terms + reserved commercial terms
├── PRICING.md            # draft pricing tiers for future external clients
├── setup.sh              # scripted engine bootstrap.sh calls under the hood
├── MANAGED_HOSTING_RUNBOOK.md  # Path B — AA hosts/operates the agent instead
├── branding/             # logo + brand assets
├── templates/
│   ├── client-soul.md.template      # {{BUSINESS_NAME}} / {{PHONE}} / {{LOCATION}} / {{INDUSTRY}}
│   ├── client-config.yaml.template
│   └── .env.EXAMPLE
├── skills/                # bundled skills shipped with every client agent
└── cron/                  # bundled scheduled jobs (if any)
```

## Quick start — just want your own agent, no business grounding

**This is the fastest path if there's no specific client/business to bake
into the agent's identity yet — e.g. handing someone their own general-
purpose Hermes agent to start exploring with.**

```bash
./start-here.sh
```

It installs Hermes for you if it's missing, installs this distribution as
your own profile, and walks you through connecting an API key. You shape
the agent's persona yourself afterward by editing its `SOUL.md`.

## Quick start — total novice / non-technical client with business details

**Never used a terminal before, and you DO want the agent grounded in a
specific business's name/phone/location/industry from the start?** Read
[GETTING_STARTED.md](GETTING_STARTED.md) and run:

```bash
./bootstrap.sh
```

It installs Hermes for you if it's missing, asks for business details in
plain English (no flags to memorize), runs `setup.sh` under the hood, and
walks you through connecting an API key. See
[GETTING_STARTED.md](GETTING_STARTED.md) for the full walkthrough
(including Windows/WSL2 instructions) and a troubleshooting FAQ.

## Quick start — scripted / repeatable (for AA staff or technical clients)

**Prerequisite:** [Hermes Agent](https://hermes-agent.nousresearch.com/docs)
must already be installed (`hermes` on your PATH). This package is the
agent template, not Hermes itself.

```bash
git clone <this-repo> autonomous-anonymous-aaas
cd autonomous-anonymous-aaas
./setup.sh <client-profile-name> "<Business Name>" "<Phone>" "<Location>" "<Industry>"
```

`setup.sh`:
1. Runs `hermes profile create <name> --clone-from default`
2. Substitutes `{{BUSINESS_NAME}}`, `{{PHONE}}`, `{{LOCATION}}`,
   `{{INDUSTRY}}` from `templates/` into the new profile's `SOUL.md` /
   `config.yaml`
3. Merges in bundled `skills/` and `cron/`
4. Prints next steps

Then:

```bash
<client-profile-name> setup   # add API keys
<client-profile-name> chat    # start talking to it
```

To remove a client agent later: `hermes profile delete <client-profile-name>`.

## Alternative: install directly as a distribution

This directory is also a valid Hermes profile distribution — you can point
`hermes profile install <path-or-git-url>` at it directly instead of
running a wrapper script. This gets you a generic, working agent (correct
model, correct Hermes identity) out of the box. See `distribution.yaml` for
the manifest and required env vars, and the Hermes docs on Profile
Distributions for the full author/installer/update lifecycle:
https://hermes-agent.nousresearch.com/docs/user-guide/profile-distributions

## Tested, not just written

Every path above has been independently verified with a real live
conversation (not just file inspection): install → profile creation → API
key → a real `hermes -p <name> -z "..."` call confirming the agent
responds in-character with the correct Nous Research creator attribution.
Test profiles are always created and deleted during verification — none
are left behind in this repo or on the verifying machine.

## Env vars

See `distribution.yaml` → `env_requires`, and `templates/.env.EXAMPLE` for
the copy-and-fill template used by generated client profiles. No real
secrets are ever committed to this repo — `.gitignore` blocks `.env`,
`auth.json`, and all other credential/state files at the source.

## Managed hosting (Path B — we run it for the client)

For clients who don't want to touch Hermes internals at all: Autonomous
Anonymous can host and operate their agent ourselves, with the client just
talking to a dedicated bot (e.g. Telegram) for their business. See
[MANAGED_HOSTING_RUNBOOK.md](MANAGED_HOSTING_RUNBOOK.md) — covers per-client
credential isolation (each client needs its own BotFather-issued Telegram
bot token, never the operator's personal one), starting/stopping the
gateway as a background service, idle-cost controls, backup/restore
(`hermes profile export`/`import`, real-tested), monitoring, and
offboarding.

## Product roadmap (not yet built)

- [ ] Formal commercial license agreement template (needed before any paid
      external client)
- [ ] Cross-machine `hermes profile install <git-url>` test against a real
      remote repo (only local clone + wrapper-script paths tested so far)
- [ ] Decide and lock in final pricing tier(s) — see PRICING.md

## A note on client verticals

This template is intentionally industry-agnostic. Client-specific content
(e.g. a particular business's inventory data, ad scripts, or other working
files) belongs in that client's own project, not in this distribution
repo — keep the agent template and any one client's working files as
separate projects.
