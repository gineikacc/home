%xrandr --auto
%xcompmgr -c -C -t-5 -l-5 -r4.2 -o.55 &
export GTK_THEME=Adwaita:dark
export QT_QPA_PLATFORMTHEME=qt5ct
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS="@im=fcitx"
fcitx5 &
exec awesome
