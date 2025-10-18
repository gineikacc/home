#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Python venv tech
# - If on new system, python -m venv ~/.venv
source ~/.venv/bin/activate

export BROWSER="google-chrome-stable"

# Set up fzf key bindings and fuzzy completion
# eval "$(fzf --bash)"
bind '"\C-t":"tms\n"'
export HOME="/home/blud" 
PATH="$PATH:$HOME/.local/bin" 
PATH="$PATH:/opt/nvim/" 
PATH=$(go env GOPATH)/bin:$PATH
export LD_LIBRARY_PATH=/path/to/directory:$LD_LIBRARY_PATH
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk

alias ls='ls --color=auto'
alias grep='grep --color=auto'
XDG_CONFIG_HOME="/home/blud/.config"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
export GTK_THEME=Adwaita:dark
CHROME=google-chrome-stable

PATH="$PATH:/opt/nvim-linux64/bin"
# PS1="\[\e[1;31m\]\u\[\e[1;32m\] \W \[\e[90m\]$ \[\e[m\]"
PS1="\[\e[1;32m\]\W \[\e[90m\]$ \[\e[m\]"
EDITOR="nvim"
alias awrc="cd ~/.config/awesome/ && vim ."
alias bat="watch -n1 cat /sys/class/power_supply/BAT0/capacity"
alias brc="vim ~/.bashrc"
alias brcs="source ~/.bashrc"
alias die="shutdown -h now"
alias lg='lazygit'
alias gs='git status'
alias lss='lsd -lahSr'
alias lt='lsd -lahtr'
alias ll="pwd && lsd -lah"
alias gh='history|grep'
alias n="nvim"
alias nn="sudo HOME=$HOME nvim"
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
alias raudio="systemctl --user restart pipewire"
alias wifion=" nmcli dev wifi connect 'Redmi 13C'"
alias wifilog="watch -n0 nmcli dev wifi list"
alias scr="ffmpeg -f x11grab -video_size 1920x1080 -i $DISPLAY -vframes 1 screen.png"
alias us="setxkbmap us"
alias cm="setxkbmap us -variant colemak_dh"
alias kkk="setxkbmap gincc"
alias cx="setxkbmap chromaxx"
alias ss="setxkbmap -option caps:swapescape"

alias night="redshift -l 55:24 &"

alias t="tmux new-window"

alias obsidian="flatpak run md.obsidian.Obsidian"
alias runescape="flatpak run com.jagex.Runescape"
alias heroic="flatpak run com.heroicgameslauncher.hgl"
alias g3="flatpak run org.gimp.GIMP"

source ~/.config/bash-scripts/main.sh

[[ -r "/usr/share/z/z.sh" ]] && source /usr/share/z/z.sh

alias viman='vim -c "h user-manual|only"'
. "/home/blud/.deno/env"
PATH="/home/blud/.config/herd-lite/bin:$PATH"
PATH="/home/blud/code/scripts/:$PATH"
PATH="$PATH:/home/blud/.dotnet/tools"
PATH="$PATH:/home/blud/opt/eclipse"
export PHP_INI_SCAN_DIR="/home/blud/.config/herd-lite/bin:$PHP_INI_SCAN_DIR"

# Expo cli be buggin fr
export ANDROID_HOME=/home/blud/Android/Sdk

# pnpm
export PNPM_HOME="/home/blud/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

function br() {
	brightnessctl set $1%
}
export -f br

function mkcd() {
  mkdir "$1" && cd "$1"
}
export -f mkcd

# Ytdl tech
alias ytdl='yt-dlp -f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" -o "$HOME/yt/%(uploader)s/%(title)s.%(ext)s" --embed-metadata --embed-thumbnail --embed-subs --sub-langs "en" --fragment-retries 10 --merge-output-format mp4'

# Colored yay
export YAY_USE_COLORS=1
export YAY_CONFIRM=0

export PATH
