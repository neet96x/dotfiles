# Dotfiles — Claude Context Guide

This repo is a personal development environment for Claude Code workflows. When loaded, it configures Claude with skills, hooks, and tools optimized for token efficiency.

## What Gets Installed

Running `install.sh` or `install-new.sh` symlinks this repo into `~`:

| Source | Target | Purpose |
|--------|--------|---------|
| `.claude/` | `~/.claude/` | Claude Code config, skills, hooks |
| `.config/tmux/` | `~/.config/tmux/` | Tmux config |
| `.config/oh-my-posh/` | `~/.config/oh-my-posh/` | Shell prompt theme |
| `.config/ccstatusline/` | `~/.config/ccstatusline/` | Claude status bar |
| `.agents/` | `~/.agents/` | Agent skill definitions |

**`install.sh`** — symlinks only (machine already has tools)  
**`install-new.sh`** — full bootstrap: installs Node/NVM, oh-my-posh, Claude Code, headroom-ai, TPM, clones repos, installs skills, writes `~/.bashrc`

## RTK (Rust Token Killer)

RTK is a CLI proxy that rewrites commands to filter verbose output before it reaches Claude — saving 60–90% of tokens on dev operations.

**How it works**: A `PreToolUse` hook at `.claude/hooks/rtk-rewrite.sh` intercepts every Bash call and transparently rewrites it through `rtk rewrite`. You don't call `rtk` manually; it's automatic.

**When to use rtk directly**:
```bash
rtk gain              # Token savings analytics
rtk gain --history    # Per-command history
rtk discover          # Find missed optimization opportunities
rtk proxy <cmd>       # Run command without filtering (debug)
```

⚠️ **RTK binary is not in this repo** — must be installed separately. If absent, the hook exits cleanly and commands run normally.

## Skills

Skills are slash commands loaded by Claude Code from `~/.claude/skills/` and `~/.agents/skills/`.

Notable skills in this repo:

| Category | Skills |
|----------|--------|
| Debugging | `/debug` `/diagnose` `/error-explain` |
| Code quality | `/code-review` `/refactor` `/security-review` |
| Testing | `/tdd` `/write-tests` |
| Git | `/git-commit` `/git-workflow` |
| Architecture | `/improve-codebase-architecture` `/zoom-out` |
| Review | `/grill-me` `/grill-with-docs` `/scrutinize` |
| Context mgmt | `/handoff` `/summarize` |
| Communication | `/post-mortem` `/management-talk` |
| Meta | `/write-a-skill` |

## Claude Code Settings

`.claude/settings.json` configures:
- **API**: Proxied through `api.maxplus-ai.cc`
- **Model**: `claude-opus-4-8`
- **Hook**: RTK rewrite on all Bash calls (PreToolUse)
- **Status bar**: `ccstatusline` via npx
- **Plugin**: `ponytail` (DietrichGebert/ponytail)
- **Dangerous mode**: `skipDangerousModePermissionPrompt: true` — permissions pre-approved

## Key Things to Know

1. **Symlinks, not copies** — edits in `~/dotfiles/` take effect immediately; no re-install needed.
2. **`.claude/` is symlinked** — `~/.claude` points here, so history/sessions/backups live in this repo (but `sessions/` and `cache/` are gitignored).
3. **RTK missing = degraded but functional** — without RTK, hooks exit safely, commands still work with more verbose output.
4. **`install-new.sh` rewrites `~/.bashrc`** — generates a fresh bashrc with NVM, aliases (`claude`, `t`, `ll`, etc.), and oh-my-posh. Back up existing before running.
5. **`settings.json` contains API credentials** — verify gitignore before pushing.
