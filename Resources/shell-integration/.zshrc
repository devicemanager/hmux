# vim:ft=zsh
#
# Compatibility shim: with the current integration model, hmux restores
# ZDOTDIR in .zshenv so this file should never be reached. If it is, restore
# ZDOTDIR and behave like vanilla zsh by sourcing the user's .zshrc.

if [[ -n "${GHOSTTY_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$GHOSTTY_ZSH_ZDOTDIR"
    builtin unset GHOSTTY_ZSH_ZDOTDIR
elif [[ -n "${HMUX_ZSH_ZDOTDIR+X}" \
   && "$HMUX_ZSH_ZDOTDIR" != "${HMUX_SHELL_INTEGRATION_DIR:-}" \
   && "$HMUX_ZSH_ZDOTDIR" != */Contents/Resources/shell-integration ]]; then
    builtin export ZDOTDIR="$HMUX_ZSH_ZDOTDIR"
    builtin unset HMUX_ZSH_ZDOTDIR
else
    builtin unset ZDOTDIR
    builtin unset HMUX_ZSH_ZDOTDIR
fi

builtin typeset _hmux_file="${ZDOTDIR-$HOME}/.zshrc"
[[ ! -r "$_hmux_file" ]] || builtin source -- "$_hmux_file"
builtin unset _hmux_file
