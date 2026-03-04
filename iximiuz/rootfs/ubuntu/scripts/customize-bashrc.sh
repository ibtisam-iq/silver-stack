#!/bin/bash
# Make all original lines with "bash_completion" in them to use
# a fake "bash_completion_orig" location to avoid double sourcing.
sed -i 's/bash_completion/bash_completion_orig/g' $HOME/.bashrc


cat <<'EOF' >> $HOME/.bashrc


export HISTSIZE=''
export HISTFILESIZE=''


export LANG="C.UTF-8"
export LC_COLLATE="C.UTF-8"
export LC_CTYPE="C.UTF-8"
export LC_MESSAGES="C.UTF-8"
export LC_MONETARY="C.UTF-8"
export LC_NUMERIC="C.UTF-8"
export LC_TIME="C.UTF-8"


export EDITOR=/usr/bin/vim
export VISUAL=/usr/bin/vim


export GPG_TTY=$(tty)


if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi


if type rg &> /dev/null; then
    export FZF_DEFAULT_COMMAND='rg --files'
    export FZF_DEFAULT_OPTS='-m --height 50% --border'
fi


if type arkade &> /dev/null; then
    export PATH="$PATH:$HOME/.arkade/bin"
fi


if [ -t 0 ] && [ -f $HOME/.welcome ]; then
  cat $HOME/.welcome
  echo
  rm -f $HOME/.welcome
fi
EOF


# Override PS1 with newline-prepended prompt (interactive non-login shells)
cat <<'EOF' >> $HOME/.bashrc

if [ "$(id -u)" -eq 0 ]; then
    _PROMPT_SYMBOL="#"
else
    _PROMPT_SYMBOL="$"
fi

if [ -z "${NO_COLOR:-}" ] && [ -t 1 ]; then
    PS1="\n\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\] ${_PROMPT_SYMBOL} "
else
    PS1="\n\u@\h:\w ${_PROMPT_SYMBOL} "
fi

export PS1
unset _PROMPT_SYMBOL
EOF
