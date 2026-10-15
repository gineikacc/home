set termguicolors

syntax match Answer_BAD  "^x_ .*$" contains=Separator,IPA
syntax match Answer_WRN  "^?_ .*$" contains=Separator,IPA

syntax match Gender_m  ".*;m;.*" contains=Separator,IPA
syntax match Gender_f  ".*;f;.*" contains=Separator,IPA

syntax match Gender_m2 ".*\<un\>.*" contains=Separator,IPA
syntax match Gender_f2 ".*\<une\>.*" contains=Separator,IPA

syntax match Gender_m3 "^\<le\>.*" contains=Separator,IPA
syntax match Gender_f3 "^\<la\>.*" contains=Separator,IPA

syntax match Gender_both   ".*;b;.*" contains=Separator,IPA
syntax match Gender_plural ".*;p;.*" contains=Separator,IPA

syntax match KW_InfinitiveMarker "\<to\>"
syntax match KW_Singular         "\<SIN\>"
syntax match KW_Plural           "\<PLU\>"
syntax match KW_Present          "\<PRE\>"
syntax match KW_Imparfait        "\<IMP\>"
syntax match KW_Future           "\<FUT\>"
syntax match KW_Conditional      "\<CON\>"
syntax match KW_DoubleConj       "\<DBL\>"
syntax match KW_PastPart         "\<PAP\>"
syntax match KW_PresPart         "\<PRP\>"
syntax match KW_PluTwo           "\<P2"
syntax match KW_PluThree         "\<P3"
syntax match KW_1236             "1236"
syntax match KW_Hwite            "hwite"
syntax match KW_TODO            "TODO"
highlight KW_InfinitiveMarker guifg=#777777
highlight KW_Singular         guifg=#88eeee
highlight KW_Plural           guifg=#88eeee
highlight KW_Present          guifg=#ff9999
highlight KW_Imparfait        guifg=#99ff99
highlight KW_Future           guifg=#9999ff
highlight KW_Conditional      guifg=#ffff99
highlight KW_Hwite            guifg=#dd88dd
highlight KW_DoubleConj       guifg=#aa0011
highlight KW_PluTwo           guifg=#dd0033
highlight KW_PluThree         guifg=#0033dd
highlight KW_PastPart         guifg=#33dd33
highlight KW_PresPart         guifg=#dd3333
highlight KW_1236             guifg=#ffdd00
highlight KW_TODO             guifg=#000000 guibg=#33dd33

"syntax match IPA  "\</.+/\>" contains=Separator
syntax match IPA  "\W*\zs/[^/]\{-}/\ze\W*[^/]*$" contains=Separator
"syntax match IPA  "/.*/;@<=\([^/]*$\)" contains=Separator
"
syntax match HR_left  "^-\{26\}" 
syntax match HR_right  "-\{26\}$" 

syntax match Separator ";" 
syntax match Eyesore "?\{5,}" 

highlight Normal        guifg=#d0d0d0
highlight Gender_m      guifg=#8888ee
highlight Gender_m2     guifg=#8888ee
highlight Gender_m3     guifg=#8888ee
highlight Gender_f      guifg=#ee8888
highlight Gender_f2     guifg=#ee8888
highlight Gender_f3     guifg=#ee8888
highlight Gender_both   guifg=#ee88ee
highlight Gender_plural guifg=#ee8800
highlight Separator     guifg=#555555

highlight! Answer_BAD   guifg=#dd3333
highlight! Answer_WRN   guifg=#ffbb33

highlight IPA       guifg=#bbbb44
highlight HR_left   guifg=#ee8888
highlight HR_right  guifg=#8888ee
highlight Eyesore   guifg=#ff0000 guibg=#6666ff



