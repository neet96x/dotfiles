# Dotfiles

Personal development environment configuration files optimized for Claude Code workflows.

## Contents

- `.claude/` - Claude Code configuration and documentation
- `.config/` - Application configs (tmux, oh-my-posh, ccstatusline)
- `.agents/` - Custom agent configurations
- `install.sh` - Bootstrap script to deploy dotfiles

## Features

- **RTK Integration** - Token-optimized CLI proxy (60-90% savings)
- **Claude Code** - AI-powered development environment
- **Tmux** - Terminal multiplexer configuration
- **Oh My Posh** - Beautiful shell prompts

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

## RTK (Rust Token Killer)

Token-optimized CLI proxy for Claude Code operations.

**Note:** RTK binary not included. Install separately:
```bash
# Installation instructions TBD
# Binary should be placed in PATH
```

See `.claude/RTK.md` for usage documentation.

## Requirements

- Git
- Bash/Zsh
- Tmux (optional)
- Oh My Posh (optional)

## Structure

```
.
├── .claude/          # Claude Code configs
│   ├── CLAUDE.md     # Global instructions
│   └── RTK.md        # RTK documentation
├── .config/          # Application configs
│   ├── tmux/         # Tmux configuration
│   ├── oh-my-posh/   # Shell prompt theme
│   └── ccstatusline/ # Claude Code statusline
├── .agents/          # Custom agent configs
├── install.sh        # Bootstrap script
└── README.md         # This file
```

## Customization

Edit configs directly in this repo, then run `./install.sh` to update symlinks.

## License

MIT License - See LICENSE file for details
