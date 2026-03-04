#!/bin/sh
# /etc/profile.d/00-prompt.sh
# Login shells will use /etc/profile.d/00-prompt.sh, while non-login shells will use $HOME/.bashrc
# The 00- prefix ensures this loads first

if [ "$(id -u)" -eq 0 ]; then
    _PROMPT_SYMBOL="#"
else
    _PROMPT_SYMBOL="$"
fi

PS1="\n\u@\h:\w ${_PROMPT_SYMBOL} "

if [ -z "${NO_COLOR:-}" ] && [ -t 1 ] && [ -n "${BASH_VERSION:-}" ]; then
    PS1="\n\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\] ${_PROMPT_SYMBOL} "
fi

export PS1
unset _PROMPT_SYMBOL
