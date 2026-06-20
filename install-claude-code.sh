#!/usr/bin/env bash
# install-claude-code.sh
# ติดตั้ง Claude Code CLI และตั้งค่า aliases
#
# Usage: ./install-claude-code.sh [--force] [--skip-ohmyposh]
#

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────
NODEJS_VERSION="20"
MIN_NODE_VERSION="18"
FORCE_INSTALL=false
SKIP_OHMYPOSH=false

# ── Parse arguments ───────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_INSTALL=true
            shift
            ;;
        --skip-ohmyposh)
            SKIP_OHMYPOSH=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--force] [--skip-ohmyposh]"
            echo "  --force         : Force reinstall even if already installed"
            echo "  --skip-ohmyposh : Skip oh-my-posh installation"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ── Helper functions ──────────────────────────────────────────────────
log_info() {
    echo "ℹ️  $*"
}

log_success() {
    echo "✅ $*"
}

log_warn() {
    echo "⚠️  $*"
}

log_error() {
    echo "❌ $*" >&2
}

log_skip() {
    echo "⏭️  $*"
}

check_root() {
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log_warn "This script may need sudo privileges for some operations"
    fi
}

version_ge() {
    # Compare versions: returns 0 if $1 >= $2
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up $file → $backup"
    fi
}

# ── 1. ติดตั้ง Node.js (ถ้ายังไม่มี) ──────────────────────────────────
install_nodejs() {
    if command -v node &>/dev/null; then
        local current_version
        current_version=$(node --version | sed 's/v//' | cut -d. -f1)

        if version_ge "$current_version" "$MIN_NODE_VERSION"; then
            log_success "Node.js already installed: $(node --version)"
            return 0
        else
            log_warn "Node.js $(node --version) is too old (need >= v${MIN_NODE_VERSION})"
            if [[ "$FORCE_INSTALL" != true ]]; then
                log_error "Use --force to upgrade"
                return 1
            fi
        fi
    fi

    log_info "Installing Node.js v${NODEJS_VERSION}..."

    if command -v apt-get &>/dev/null; then
        apt-get update -qq || log_warn "apt-get update failed"
        apt-get install -y -qq curl ca-certificates gnupg || {
            log_error "Failed to install prerequisites"
            return 1
        }

        # Remove old NodeSource repo if exists
        rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null || true

        curl -fsSL "https://deb.nodesource.com/setup_${NODEJS_VERSION}.x" | bash - || {
            log_error "Failed to setup NodeSource repository"
            return 1
        }

        apt-get install -y -qq nodejs || {
            log_error "Failed to install Node.js"
            return 1
        }
    else
        log_error "Unsupported package manager (only apt-get supported)"
        return 1
    fi

    log_success "Node.js installed: $(node --version)"
    log_success "npm installed: $(npm --version)"
}

install_nodejs

# ── 2. ติดตั้ง oh-my-posh ─────────────────────────────────────────────
install_ohmyposh() {
    if [[ "$SKIP_OHMYPOSH" == true ]]; then
        log_skip "Skipping oh-my-posh installation (--skip-ohmyposh)"
        return 0
    fi

    if command -v oh-my-posh &>/dev/null; then
        local version
        version=$(oh-my-posh --version 2>/dev/null | head -1 || echo "unknown")
        log_skip "oh-my-posh already installed: $version"
        if [[ "$FORCE_INSTALL" != true ]]; then
            return 0
        fi
        log_info "Force reinstalling oh-my-posh..."
    fi

    log_info "Installing oh-my-posh..."

    # Install prerequisites
    local missing_deps=()
    for dep in curl unzip; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_info "Installing prerequisites: ${missing_deps[*]}"
        if command -v apt-get &>/dev/null; then
            apt-get update -qq || log_warn "apt-get update failed"
            apt-get install -y -qq "${missing_deps[@]}" || {
                log_error "Failed to install prerequisites: ${missing_deps[*]}"
                return 1
            }
        else
            log_error "Cannot install prerequisites (apt-get not found)"
            return 1
        fi
    fi

    # Use official installation script
    log_info "Running oh-my-posh installation script..."
    if curl -s https://ohmyposh.dev/install.sh | bash -s -- -d /usr/local/bin; then
        local installed_version
        installed_version=$(oh-my-posh --version 2>/dev/null | head -1 || echo "unknown")
        log_success "oh-my-posh installed: $installed_version"

        # Copy oh-my-posh config from dotfiles
        local dotfiles_config="/root/dotfiles/.config/oh-my-posh"
        local target_dir="$HOME/.config/oh-my-posh"

        if [[ -d "$dotfiles_config" ]]; then
            log_info "Copying oh-my-posh themes from dotfiles..."
            mkdir -p "$target_dir"

            # Backup existing config if not forcing
            if [[ -d "$target_dir" ]] && [[ "$FORCE_INSTALL" != true ]]; then
                # Copy only if files don't exist
                for file in "$dotfiles_config"/*; do
                    local filename=$(basename "$file")
                    local target="$target_dir/$filename"
                    if [[ ! -f "$target" ]]; then
                        cp "$file" "$target"
                        log_info "  ✓ $filename"
                    else
                        log_skip "  ⏭  $filename (already exists)"
                    fi
                done
            else
                # Force copy all files
                cp -r "$dotfiles_config"/* "$target_dir/"
                log_success "Themes copied to $target_dir"
                log_info "  Files: $(ls -1 "$target_dir" | wc -l) theme(s)"
            fi
        else
            log_warn "oh-my-posh config not found in dotfiles: $dotfiles_config"
            log_info "Downloading default themes..."
            mkdir -p "$target_dir"

            # Download a few popular themes as fallback
            local themes=("sonicboom" "atomic" "1_shell" "agnoster" "paradox")
            for theme in "${themes[@]}"; do
                if curl -sL "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/${theme}.omp.json" \
                    -o "$target_dir/${theme}.omp.json" 2>/dev/null; then
                    log_info "  ✓ ${theme}.omp.json"
                fi
            done
            log_warn "neet96x.omp.json not found - you may need to add it manually"
        fi
    else
        log_error "Failed to install oh-my-posh"
        log_info "You can install manually with: curl -s https://ohmyposh.dev/install.sh | bash -s"
        return 1
    fi
}

install_ohmyposh

# ── 3. ติดตั้ง Claude Code ───────────────────────────────────────────
install_claude_code() {
    if command -v claude &>/dev/null && [[ "$FORCE_INSTALL" != true ]]; then
        local version
        version=$(claude --version 2>/dev/null || echo "unknown")
        log_skip "Claude Code already installed: $version"
        return 0
    fi

    log_info "Installing Claude Code..."

    # Check npm is available
    if ! command -v npm &>/dev/null; then
        log_error "npm not found. Please install Node.js first."
        return 1
    fi

    # Install globally
    if npm install -g @anthropic-ai/claude-code 2>&1 | grep -v "npm WARN"; then
        local version
        version=$(claude --version 2>/dev/null || echo "installed")
        log_success "Claude Code installed: $version"
    else
        log_error "Failed to install Claude Code"
        return 1
    fi
}

install_claude_code

# ── 4. ติดตั้ง ccstatusline ───────────────────────────────────────────
install_ccstatusline() {
    log_info "Installing ccstatusline..."

    if ! command -v npx &>/dev/null; then
        log_error "npx not found. Please install Node.js first."
        return 1
    fi

    # Run ccstatusline setup
    if npx -y ccstatusline@latest 2>&1 | grep -v "npm WARN"; then
        log_success "ccstatusline installed"
    else
        log_warn "ccstatusline installation may have had issues (non-fatal)"
    fi
}

install_ccstatusline

# ── 5. ติดตั้ง tmux และ plugins ───────────────────────────────────────
install_tmux() {
    if command -v tmux &>/dev/null && [[ "$FORCE_INSTALL" != true ]]; then
        local version
        version=$(tmux -V)
        log_skip "tmux already installed: $version"
    else
        log_info "Installing tmux..."

        if command -v apt-get &>/dev/null; then
            apt-get install -y -qq tmux || {
                log_error "Failed to install tmux"
                return 1
            }
            log_success "tmux installed: $(tmux -V)"
        else
            log_error "Unsupported package manager"
            return 1
        fi
    fi

    # Install TPM (Tmux Plugin Manager)
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    if [[ -d "$tpm_dir" ]] && [[ "$FORCE_INSTALL" != true ]]; then
        log_skip "TPM already installed: $tpm_dir"
    else
        log_info "Installing TPM (Tmux Plugin Manager)..."

        if [[ -d "$tpm_dir" ]]; then
            log_warn "Removing existing TPM directory"
            rm -rf "$tpm_dir"
        fi

        if ! command -v git &>/dev/null; then
            log_info "Installing git..."
            apt-get install -y -qq git || {
                log_error "Failed to install git"
                return 1
            }
        fi

        if git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir" 2>&1 | grep -v "Cloning into"; then
            log_success "TPM installed: $tpm_dir"
        else
            log_error "Failed to clone TPM"
            return 1
        fi
    fi

    # Create tmux config
    setup_tmux_config
}

setup_tmux_config() {
    local tmux_conf="$HOME/.tmux.conf"

    if [[ -f "$tmux_conf" ]]; then
        if [[ "$FORCE_INSTALL" != true ]]; then
            log_skip "tmux.conf already exists: $tmux_conf"
            log_info "Use --force to overwrite or edit manually"
            return 0
        fi
        backup_file "$tmux_conf"
    fi

    log_info "Creating tmux configuration: $tmux_conf"

    cat > "$tmux_conf" <<'EOF'
# ══════════════════════════════════════════════════════════════════════
# tmux Configuration
# Auto-generated by install-claude-code.sh
# ══════════════════════════════════════════════════════════════════════

# ── General Settings ──────────────────────────────────────────────────
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
set -g history-limit 50000
set -g display-time 4000
set -g status-interval 5
set -g focus-events on
set -sg escape-time 10

# Start windows and panes at 1, not 0
set -g base-index 1
setw -g pane-base-index 1

# Renumber windows when a window is closed
set -g renumber-windows on

# Enable mouse support
set -g mouse on

# ── Key Bindings ──────────────────────────────────────────────────────
# Change prefix to Ctrl-a (easier to reach than Ctrl-b)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Reload config
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Split panes using | and -
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# Switch panes using Alt-arrow without prefix
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Switch panes using vim keys
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Resize panes using vim keys
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Vi mode for copy mode
setw -g mode-keys vi
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-selection-and-cancel
bind -T copy-mode-vi C-v send -X rectangle-toggle

# ── Status Bar ────────────────────────────────────────────────────────
set -g status-position bottom
set -g status-justify left
set -g status-style 'bg=colour234 fg=colour137'

set -g status-left ''
set -g status-right '#[fg=colour233,bg=colour241,bold] %d/%m #[fg=colour233,bg=colour245,bold] %H:%M:%S '
set -g status-right-length 50
set -g status-left-length 20

setw -g window-status-current-style 'fg=colour1 bg=colour238 bold'
setw -g window-status-current-format ' #I#[fg=colour249]:#[fg=colour255]#W#[fg=colour249]#F '

setw -g window-status-style 'fg=colour9 bg=colour236'
setw -g window-status-format ' #I#[fg=colour237]:#[fg=colour250]#W#[fg=colour244]#F '

# ── Tmux Plugin Manager (TPM) ─────────────────────────────────────────
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-pain-control'
set -g @plugin 'tmux-plugins/tmux-copycat'
set -g @plugin 'tmux-plugins/tmux-open'

# ── Plugin Settings ───────────────────────────────────────────────────
# tmux-resurrect: restore nvim/vim sessions
set -g @resurrect-strategy-nvim 'session'
set -g @resurrect-strategy-vim 'session'
set -g @resurrect-capture-pane-contents 'on'

# tmux-continuum: automatic restore
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'

# ── Initialize TPM (keep this at the very bottom) ─────────────────────
run '~/.tmux/plugins/tpm/tpm'
EOF

    if [[ -f "$tmux_conf" ]]; then
        log_success "tmux configuration created: $tmux_conf"
        log_info "Press 'prefix + I' (Ctrl-a + I) in tmux to install plugins"
        return 0
    else
        log_error "Failed to create tmux configuration"
        return 1
    fi
}

install_tmux

# ── 6. สร้าง config สำหรับ qwen3.6-35b-a3b ──────────────────────────
setup_claude_config() {
    local settings_file="$HOME/.claude-9arm.json"

    if [[ -f "$settings_file" ]] && [[ "$FORCE_INSTALL" != true ]]; then
        log_skip "Settings file already exists: $settings_file"
        return 0
    fi

    log_info "Creating settings file: $settings_file"

    # Backup existing file
    if [[ -f "$settings_file" ]]; then
        backup_file "$settings_file"
    fi

    cat > "$settings_file" <<'EOF'
{
    "model": "qwen3.6-35b-a3b",
    "env": {
        "ANTHROPIC_MODEL": "qwen3.6-35b-a3b"
    }
}
EOF

    if [[ -f "$settings_file" ]]; then
        chmod 600 "$settings_file"  # Secure the config file
        log_success "Settings file created: $settings_file"
    else
        log_error "Failed to create settings file"
        return 1
    fi
}

setup_claude_config

# ── 7. เพิ่ม aliases และ oh-my-posh ลง .bashrc ──────────────────────
setup_bashrc() {
    local bashrc="$HOME/.bashrc"

    if [[ ! -f "$bashrc" ]]; then
        log_warn ".bashrc not found, creating new one"
        touch "$bashrc"
    fi

    # Backup .bashrc
    backup_file "$bashrc"

    # Define aliases
    local -a aliases=(
        "alias claude='IS_SANDBOX=1 claude'"
        "alias claude-9arm='claude --settings ~/.claude-9arm.json --model=qwen3.6-35b-a3b'"
        'alias py="python3"'
    )

    # Check if aliases need to be added
    local need_aliases=false
    for alias_line in "${aliases[@]}"; do
        local alias_name="${alias_line%%=*}"
        if ! grep -qF "$alias_name" "$bashrc" 2>/dev/null; then
            need_aliases=true
            break
        fi
    done

    # Add aliases if needed
    if [[ "$need_aliases" == true ]] || [[ "$FORCE_INSTALL" == true ]]; then
        log_info "Adding aliases to $bashrc"
        echo "" >> "$bashrc"
        echo "# ── Claude Code aliases (auto-added by install-claude-code.sh) ──" >> "$bashrc"
        for alias_line in "${aliases[@]}"; do
            echo "$alias_line" >> "$bashrc"
        done
        log_success "Aliases added to $bashrc"
    else
        log_skip "Aliases already in $bashrc"
    fi

    # Setup oh-my-posh init
    if [[ "$SKIP_OHMYPOSH" != true ]]; then
        if ! grep -qF "oh-my-posh init" "$bashrc" 2>/dev/null || [[ "$FORCE_INSTALL" == true ]]; then
            log_info "Adding oh-my-posh init to $bashrc"
            echo "" >> "$bashrc"
            echo "# ── oh-my-posh init (auto-added by install-claude-code.sh) ──" >> "$bashrc"
            echo 'eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/neet96x.omp.json)"' >> "$bashrc"
            log_success "oh-my-posh init added to $bashrc"
        else
            log_skip "oh-my-posh init already in $bashrc"
        fi
    fi
}

setup_bashrc

# ── 8. สรุป ──────────────────────────────────────────────────────────
print_summary() {
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  ✅ Claude Code installation complete!"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  Run the following to activate changes:"
    echo "    source ~/.bashrc"
    echo ""
    echo "  Available commands:"
    echo "    claude          — Claude Code (IS_SANDBOX=1)"
    echo "    claude-9arm     — Claude Code with qwen3.6-35b-a3b"
    echo "    py              — python3 shorthand"
    echo "    tmux            — Terminal multiplexer"
    echo ""

    if command -v oh-my-posh &>/dev/null; then
        echo "  oh-my-posh: $(oh-my-posh --version 2>/dev/null | head -1)"
    fi

    if command -v claude &>/dev/null; then
        echo "  Claude Code: $(claude --version 2>/dev/null || echo 'installed')"
    fi

    if command -v node &>/dev/null; then
        echo "  Node.js: $(node --version)"
    fi

    if command -v tmux &>/dev/null; then
        echo "  tmux: $(tmux -V)"
    fi

    if [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
        echo "  TPM: installed"
        echo ""
        echo "  To install tmux plugins:"
        echo "    1. Start tmux: tmux"
        echo "    2. Press: Ctrl-a + I (capital I)"
    fi

    echo ""
}

# ── Main execution ────────────────────────────────────────────────────
main() {
    log_info "Starting Claude Code installation..."
    echo ""

    check_root

    # Track failures
    local failed=0

    install_nodejs || ((failed++))
    install_ohmyposh || ((failed++))
    install_claude_code || ((failed++))
    install_ccstatusline || ((failed++))
    install_tmux || ((failed++))
    setup_claude_config || ((failed++))
    setup_bashrc || ((failed++))

    echo ""

    if [[ $failed -eq 0 ]]; then
        print_summary
        return 0
    else
        log_error "Installation completed with $failed error(s)"
        return 1
    fi
}

main "$@"
