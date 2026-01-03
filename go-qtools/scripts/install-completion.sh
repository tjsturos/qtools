#!/bin/bash
# Install qtools shell completion

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
QTOOLS_BIN="${QTOOLS_BIN:-$PROJECT_ROOT/qtools}"

if [ ! -f "$QTOOLS_BIN" ]; then
    echo "Error: qtools binary not found at $QTOOLS_BIN"
    echo "Set QTOOLS_BIN environment variable to specify the binary path"
    exit 1
fi

detect_shell() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    elif [ -n "$BASH_VERSION" ]; then
        echo "bash"
    elif [ -n "$FISH_VERSION" ]; then
        echo "fish"
    else
        echo "unknown"
    fi
}

install_bash() {
    local completion_dir
    if [ -d "/etc/bash_completion.d" ] && [ -w "/etc/bash_completion.d" ]; then
        completion_dir="/etc/bash_completion.d"
    elif [ -d "$HOME/.local/share/bash-completion/completions" ]; then
        completion_dir="$HOME/.local/share/bash-completion/completions"
        mkdir -p "$completion_dir"
    else
        completion_dir="$HOME/.bash_completion.d"
        mkdir -p "$completion_dir"
    fi

    echo "Installing bash completion to $completion_dir/qtools"
    "$QTOOLS_BIN" completion bash > "$completion_dir/qtools"
    chmod +x "$completion_dir/qtools"
    echo "✓ Bash completion installed"
    echo "  Run 'source $completion_dir/qtools' or restart your shell"
}

install_zsh() {
    local completion_dir="${fpath[1]}"
    if [ -z "$completion_dir" ]; then
        completion_dir="$HOME/.zsh/completions"
        mkdir -p "$completion_dir"
    fi

    echo "Installing zsh completion to $completion_dir/_qtools"
    "$QTOOLS_BIN" completion zsh > "$completion_dir/_qtools"
    echo "✓ Zsh completion installed"
    echo "  Run 'source $completion_dir/_qtools' or restart your shell"
    echo "  Or add '$completion_dir' to your fpath in ~/.zshrc"
}

install_fish() {
    local completion_dir="$HOME/.config/fish/completions"
    mkdir -p "$completion_dir"

    echo "Installing fish completion to $completion_dir/qtools.fish"
    "$QTOOLS_BIN" completion fish > "$completion_dir/qtools.fish"
    echo "✓ Fish completion installed"
    echo "  Restart your shell or run 'source $completion_dir/qtools.fish'"
}

SHELL_TYPE="${1:-$(detect_shell)}"

case "$SHELL_TYPE" in
    bash)
        install_bash
        ;;
    zsh)
        install_zsh
        ;;
    fish)
        install_fish
        ;;
    *)
        echo "Usage: $0 [bash|zsh|fish]"
        echo ""
        echo "Detected shell: $(detect_shell)"
        echo ""
        echo "If auto-detection failed, specify your shell:"
        echo "  $0 bash"
        echo "  $0 zsh"
        echo "  $0 fish"
        exit 1
        ;;
esac
