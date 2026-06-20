#!/usr/bin/env bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

echo "🚀 Installing dotfiles from $DOTFILES_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "📦 Backup directory: $BACKUP_DIR"

# Function to safely symlink
link_file() {
    local src="$1"
    local dest="$2"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        echo "  ⚠️  Backing up existing: $dest"
        mv "$dest" "$BACKUP_DIR/"
    fi

    echo "  🔗 Linking: $dest -> $src"
    ln -sf "$src" "$dest"
}

# Symlink .claude directory
echo ""
echo "📂 Linking Claude Code configs..."
link_file "$DOTFILES_DIR/.claude" "$HOME/.claude"

# Symlink .config contents
echo ""
echo "📂 Linking application configs..."
mkdir -p "$HOME/.config"

if [ -d "$DOTFILES_DIR/.config/tmux" ]; then
    link_file "$DOTFILES_DIR/.config/tmux" "$HOME/.config/tmux"
fi

if [ -d "$DOTFILES_DIR/.config/oh-my-posh" ]; then
    link_file "$DOTFILES_DIR/.config/oh-my-posh" "$HOME/.config/oh-my-posh"
fi

if [ -d "$DOTFILES_DIR/.config/ccstatusline" ]; then
    link_file "$DOTFILES_DIR/.config/ccstatusline" "$HOME/.config/ccstatusline"
fi

# Symlink .agents if exists
if [ -d "$DOTFILES_DIR/.agents" ]; then
    echo ""
    echo "📂 Linking agent configs..."
    link_file "$DOTFILES_DIR/.agents" "$HOME/.agents"
fi

echo ""
echo "✅ Dotfiles installation complete!"
echo ""
echo "📝 Notes:"
echo "  - Backups saved to: $BACKUP_DIR"
echo "  - RTK binary not included - install separately"
echo "  - Restart shell or run: source ~/.bashrc"
echo ""
