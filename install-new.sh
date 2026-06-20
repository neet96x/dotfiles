#!/usr/bin/env bash
# install-new.sh — Full bootstrap: dotfiles + tools
set -eo pipefail  # ไม่ใช้ -u เพราะ nvm.sh มี unbound vars

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
FORCE=false; SKIP_OHMYPOSH=false; SKIP_REPOS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)         FORCE=true ;;
        --skip-ohmyposh) SKIP_OHMYPOSH=true ;;
        --skip-repos)    SKIP_REPOS=true ;;
        -h|--help) echo "Usage: $0 [--force] [--skip-ohmyposh] [--skip-repos]"; exit 0 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac; shift
done

info() { echo "ℹ️  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
err()  { echo "❌ $*" >&2; }
skip() { echo "⏭️  $*"; }
version_ge() { printf '%s\n%s\n' "$2" "$1" | sort -V -C; }
backup() { [[ -e "$1" ]] && cp -r "$1" "${1}.bak.$(date +%Y%m%d_%H%M%S)"; }
link_file() {
    local src="$1" dest="$2"
    if [[ -e "$dest" || -L "$dest" ]]; then mv "$dest" "$BACKUP_DIR/"; info "Backed up: $dest"; fi
    ln -sf "$src" "$dest" && ok "Linked: $dest → $src"
}

install_packages() {
    info "System packages..."
    apt-get update -qq
    apt-get install -y -qq git curl wget tmux unzip python3-pip build-essential
    ok "System packages installed"
}

install_node() {
    export NVM_DIR="$HOME/.nvm"
    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        info "Installing NVM..."
        curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    fi
    # source nvm แบบ safe (nvm มี unbound vars ภายใน)
    set +u; [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"; set -u

    if command -v node &>/dev/null && [[ "$FORCE" != true ]]; then
        local ver; ver=$(node --version | sed 's/v//' | cut -d. -f1)
        version_ge "$ver" "18" && { skip "Node.js: $(node --version)"; return 0; }
    fi
    info "Installing Node.js LTS..."
    set +u; nvm install --lts && nvm use --lts; set -u
    ok "Node.js: $(node --version)"
}

install_ohmyposh() {
    [[ "$SKIP_OHMYPOSH" == true ]] && { skip "oh-my-posh"; return 0; }
    command -v oh-my-posh &>/dev/null && [[ "$FORCE" != true ]] && {
        skip "oh-my-posh: $(oh-my-posh --version 2>/dev/null | head -1)"; return 0; }
    info "Installing oh-my-posh..."
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d /usr/local/bin
    ok "oh-my-posh: $(oh-my-posh --version 2>/dev/null | head -1)"
}

install_claude() {
    command -v claude &>/dev/null && [[ "$FORCE" != true ]] && {
        skip "Claude Code: $(claude --version 2>/dev/null || echo unknown)"; return 0; }
    info "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
    ok "Claude Code installed"
}

install_headroom() {
    info "Installing headroom-ai..."
    pip3 install --break-system-packages "headroom-ai[all]" 2>/dev/null || \
        pip3 install "headroom-ai[all]"
    ok "headroom-ai installed"
}

install_ccstatusline() {
    info "Installing ccstatusline..."
    npx -y ccstatusline@latest 2>&1 | grep -v "npm WARN" || warn "ccstatusline: non-fatal"
    ok "ccstatusline done"
}

install_tpm() {
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    [[ -d "$tpm_dir" ]] && [[ "$FORCE" != true ]] && { skip "TPM already installed"; return 0; }
    info "Installing TPM..."
    [[ -d "$tpm_dir" ]] && rm -rf "$tpm_dir"
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir"
    ok "TPM installed"
}

clone_repos() {
    [[ "$SKIP_REPOS" == true ]] && { skip "Repos"; return 0; }
    info "Cloning repos..."
    mkdir -p ~/src && cd ~/src
    local repos=("https://github.com/thananon/9arm-skills.git:9arm-skills"
                  "https://github.com/neet96x/boyser-ai.git:boyser-ai"
                  "https://github.com/neet96x/dotfiles.git:dotfiles")
    for entry in "${repos[@]}"; do
        local url="${entry%%:*}" dir="${entry##*:}"
        if [[ -d "$dir" ]] && [[ "$FORCE" != true ]]; then skip "Repo: $dir"
        else [[ -d "$dir" ]] && rm -rf "$dir"; git clone "$url" "$dir" && ok "Cloned: $dir"; fi
    done
    # หลัง clone แล้วให้ใช้ ~/src/dotfiles เป็น source
    DOTFILES_DIR="$HOME/src/dotfiles"
}

install_skills() {
    [[ "$SKIP_REPOS" == true ]] && return 0
    info "Installing skills..."
    mkdir -p ~/.claude/skills
    find ~/src/9arm-skills -mindepth 1 -maxdepth 1 -type d -exec cp -r {} ~/.claude/skills/ \; || true
    if [[ -d ~/src/boyser-ai/skills ]]; then cp -r ~/src/boyser-ai/skills/* ~/.claude/skills/ || true
    else find ~/src/boyser-ai -mindepth 1 -maxdepth 1 -type d -exec cp -r {} ~/.claude/skills/ \; || true; fi
    ok "Skills installed"
}

link_dotfiles() {
    if [[ "$DOTFILES_DIR" == "$HOME" ]]; then
        warn "DOTFILES_DIR == HOME — run from dotfiles repo or without --skip-repos"; return 0
    fi
    info "Linking dotfiles from $DOTFILES_DIR..."
    mkdir -p "$BACKUP_DIR" "$HOME/.config"
    [[ -d "$DOTFILES_DIR/.claude" ]]  && link_file "$DOTFILES_DIR/.claude"  "$HOME/.claude"
    for dir in tmux oh-my-posh ccstatusline; do
        [[ -d "$DOTFILES_DIR/.config/$dir" ]] && \
            link_file "$DOTFILES_DIR/.config/$dir" "$HOME/.config/$dir"
    done
    [[ -d "$DOTFILES_DIR/.agents" ]] && link_file "$DOTFILES_DIR/.agents" "$HOME/.agents"
    ok "Dotfiles linked"
}

install_plugins() {
    command -v claude &>/dev/null || { warn "claude not found, skip plugins"; return 0; }
    info "Installing Claude plugins..."
    claude /plugin marketplace add DietrichGebert/ponytail || true
    claude /plugin install ponytail@ponytail || true
    ok "Plugins installed"
}

setup_bashrc() {
    local bashrc="$HOME/.bashrc"
    grep -q "auto-generated by install" "$bashrc" 2>/dev/null && [[ "$FORCE" != true ]] && {
        skip ".bashrc configured"; return 0; }
    backup "$bashrc"
    info "Writing ~/.bashrc..."
    cat > "$bashrc" <<'EOF'
# ~/.bashrc — auto-generated by install
export TERM='xterm-256color'
HISTSIZE=10000; HISTFILESIZE=20000; HISTCONTROL=ignoredups:erasedups
shopt -s histappend
PROMPT_COMMAND="history -a; history -c; history -r; ${PROMPT_COMMAND:-}"
export LS_OPTIONS='--color=auto'
eval "$(dircolors 2>/dev/null)" || true
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -lh'
alias la='ls $LS_OPTIONS -lAh'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias mkdir='mkdir -p'
alias py="python3"
alias claude='IS_SANDBOX=1 claude --dangerously-skip-permissions'
alias claude-9arm='claude --settings ~/.claude-9arm.json --model=qwen3.6-35b-a3b'
alias t='tmux'
alias ta='tmux attach -t'
alias tl='tmux ls'
alias tn='tmux new -s'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
export PATH="$HOME/.local/bin:$PATH"
command -v oh-my-posh >/dev/null 2>&1 && \
    eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/neet96x.omp.json)"
EOF
    ok ".bashrc written"
}

main() {
    local failed=0
    install_packages     || ((failed++))
    install_node         || ((failed++))
    install_ohmyposh     || ((failed++))
    install_claude       || ((failed++))
    install_headroom     || ((failed++))
    install_ccstatusline || ((failed++))
    install_tpm          || ((failed++))
    clone_repos          || ((failed++))
    install_skills       || ((failed++))
    link_dotfiles        || ((failed++))
    install_plugins      || ((failed++))
    setup_bashrc         || ((failed++))
    echo ""
    if [[ $failed -eq 0 ]]; then
        echo "════════════════════════════════════"
        echo "  ✅ Installation complete!"
        echo "════════════════════════════════════"
        echo "  Run: source ~/.bashrc"
    else
        err "Done with $failed error(s)"; exit 1
    fi
}

main "$@"
