set termguicolors

syntax match Key "^[^:]\+"
syntax match Value ":\s.*$" contains=Number
syntax match Number "\<\d\+\>" contained

highlight Key    guifg=#882288
highlight Value  guifg=#228888
highlight Number guifg=#bbbb00
