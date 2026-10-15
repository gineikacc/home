set termguicolors

syntax match Gender_m  ".*;m;.*" contains=Separator,IPA
syntax match Gender_f  ".*;f;.*" contains=Separator,IPA



syntax match ProMarker "\<PRO\>"
syntax match ConMarker "\<CON\>"
syntax match ProLine   ".*\<PRO\>.*" contains=ProMarker
syntax match ConLine   ".*\<CON\>.*" contains=ConMarker


highlight Normal    guifg=#d0d0d0
highlight ProMarker guifg=#444444 guibg=#55ff55
highlight ProLine   guifg=#88ee88
highlight ConMarker guifg=#444444 guibg=#ff5555
highlight ConLine   guifg=#ee8888 



