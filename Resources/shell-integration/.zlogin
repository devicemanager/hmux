# vim:ft=zsh
#
# Compatibility shim: with the current integration model, hmux restores
# ZDOTDIR in .zshenv so this file should never be reached. If it is, restore
# ZDOTDIR and behave like vanilla zsh by sourcing the user's .zlogin.

if [[ -n "${GHOSTTY_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$GHOSTTY_ZSH_ZDOTDIR"
    builtin unset GHOSTTY_ZSH_ZDOTDIR
elif [[ -n "${HMUX_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$HMUX_ZSH_ZDOTDIR"
    builtin unset HMUX_ZSH_ZDOTDIR
else
    builtin unset ZDOTDIR
fi

builtin typeset _hmux_file="${ZDOTDIR-$HOME}/.zlogin"
[[ ! -r "$_hmux_file" ]] || builtin source -- "$_hmux_file"
builtin unset _hmux_file
