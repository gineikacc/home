#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return


# Set up fzf key bindings and fuzzy completion
eval "$(fzf --bash)"
export HOME="/home/blud" 
export PATH="$PATH:$HOME/.local/bin" 
export PATH="$PATH:/opt/nvim/" 
export LD_LIBRARY_PATH=/path/to/directory:$LD_LIBRARY_PATH

alias ls='ls --color=auto'
alias grep='grep --color=auto'
XDG_CONFIG_HOME="/home/blud/.config"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
CHROME=google-chrome-stable

export PATH="$PATH:/opt/nvim-linux64/bin"
# PS1="\[\e[1;31m\]\u\[\e[1;32m\] \W \[\e[90m\]$ \[\e[m\]"
PS1="\[\e[1;32m\]\W \[\e[90m\]$ \[\e[m\]"
EDITOR="nvim"
alias awrc="cd ~/.config/awesome/ && vim ."
alias bat="watch -n1 cat /sys/class/power_supply/BAT0/capacity"
alias brc="vim ~/.bashrc"
alias brcs="source ~/.bashrc"
alias die="shutdown -h now"
alias left='ls -t -1'
alias lt='ls --human-readable --size -1 -S --classify'
alias ll="pwd && lsd -lah"
alias gh='history|grep'
alias n="nvim"
alias vim="nvim"
alias vimrc="cd ~/.config/nvim/ && vim ."
alias lampp="sudo /opt/lampp/manager-linux-x64.run"
alias img="qimgv"



alias btr='bluetoothctl power off && rfkill unblock bluetooth && bluetoothctl power on \
            && bluetoothctl connect 20:15:82:F1:60:22 && clear'
alias btx='btr && exit'
alias btoff="bluetoothctl power off && clear"

alias bton='rfkill unblock bluetooth && bluetoothctl power on \
            && bluetoothctl connect 20:15:82:F1:60:22 && clear'
alias btoff="bluetoothctl power off && clear"
alias wifion=" nmcli dev wifi connect 'Redmi 13C'"
alias wifilog="watch -n0 nmcli dev wifi list"
alias scr="ffmpeg -f x11grab -video_size 1920x1080 -i $DISPLAY -vframes 1 screen.png"
alias us="setxkbmap us"
alias cm="setxkbmap us -variant colemak_dh"
alias kkk="setxkbmap gincc"
alias cx="setxkbmap chromaxx"
alias night="redshift -l 55:24 &"

alias t="tmux new-window"

alias obsidian="flatpak run md.obsidian.Obsidian"
alias runescape="flatpak run com.jagex.Runescape"
alias heroic="flatpak run com.heroicgameslauncher.hgl"

source ~/.config/bash-scripts/main.sh

[[ -r "/usr/share/z/z.sh" ]] && source /usr/share/z/z.sh

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

alias viman='vim -c "h user-manual|only"'
. "/home/blud/.deno/env"
export PATH="/home/blud/.config/herd-lite/bin:$PATH"
export PHP_INI_SCAN_DIR="/home/blud/.config/herd-lite/bin:$PHP_INI_SCAN_DIR"
