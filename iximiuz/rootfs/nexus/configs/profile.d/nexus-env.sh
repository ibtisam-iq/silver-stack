#!/bin/bash
# /etc/profile.d/nexus-env.sh
# Sourced for login shells (SSH, su -, bash -l)
# Sets prompt only — aliases and env are in ~/.bashrc

if [ "$(id -u)" -eq 0 ]; then
    _PROMPT_SYMBOL="#"
else
    _PROMPT_SYMBOL="\$"
fi

PS1="\u@\h:\w ${_PROMPT_SYMBOL} "

if [ -z "${NO_COLOR:-}" ] && [ -t 1 ] && [ -n "${BASH_VERSION:-}" ]; then
    PS1="\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\] ${_PROMPT_SYMBOL} "
fi

export PS1
unset _PROMPT_SYMBOL

