# Interactive bash: zoxide ("z <dir>") and fzf key bindings (Ctrl-R
# history, Ctrl-T files, Alt-C cd).
if [ -n "${BASH_VERSION:-}" ] && [[ $- == *i* ]]; then
    command -v zoxide >/dev/null && eval "$(zoxide init bash)"
    command -v fzf >/dev/null && eval "$(fzf --bash)"
fi
