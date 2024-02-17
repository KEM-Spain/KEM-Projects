set background=dark
hi clear          
if exists("syntax_on")
    syntax reset
endif
let g:colors_name="myscheme"

"MistyRose3=181  
hi Boolean         ctermfg=15  
"MistyRose3=181  
hi Character       ctermfg=15   cterm=bold
"DarkSeaGreen=108  
hi Comment         ctermfg=15
"NavajoWhite1=223  
hi Conditional     ctermfg=15   cterm=bold
"MistyRose3=181  
hi Constant        ctermfg=15   cterm=bold
"Grey7=233  LightSkyBlue3=109  
hi Cursor          ctermfg=15   ctermfg=0     cterm=bold
"MistyRose3=181  
hi Debug           ctermfg=15   cterm=bold
"NavajoWhite1=223  
hi Define          ctermfg=15   cterm=bold
"Grey54=245  
hi Delimiter       ctermfg=15  
"PaleTurquoise4=66   Grey23=237  
hi DiffAdd         ctermfg=66    ctermfg=0     cterm=bold
"Grey19=236  
hi DiffChange      ctermfg=0  
"Grey19=236  Grey27=238  
hi DiffDelete      ctermfg=15   ctermfg=0    
"LightPink1=217  Grey23=237  
hi DiffText        ctermfg=15   ctermfg=0     cterm=bold
"Grey84=188  
hi Directory       ctermfg=15   cterm=bold
"DarkSeaGreen3=115  Grey19=236
hi ErrorMsg        ctermfg=15   ctermfg=0     cterm=bold
"Grey70=249  
hi Exception       ctermfg=15   cterm=bold
"Grey78=251  
hi Float           ctermfg=15  
"LightSkyBlue3=109  Grey27=238  
hi FoldColumn      ctermfg=15   ctermfg=0    
"LightSkyBlue3=109  Grey27=238  
hi Folded          ctermfg=15   ctermfg=0    
"Khaki1=228  
hi Function        ctermfg=15  
"NavajoWhite1=223  
hi Identifier      ctermfg=15  
"Khaki1=228  Grey27=238  
hi IncSearch       ctermfg=0   ctermfg=15    
"NavajoWhite1=223  
hi Keyword         ctermfg=15   cterm=bold
"LightYellow3=187  
hi Label           ctermfg=15   cterm=underline
"Grey66=248  Grey15=235  
hi LineNr          ctermfg=248   ctermfg=235    
"NavajoWhite1=223  
hi Macro           ctermfg=15   cterm=bold
"NavajoWhite1=223  
hi ModeMsg         ctermfg=15   cterm=none
"White=15
hi MoreMsg         ctermfg=15    cterm=bold
"Grey27=238  
hi NonText         ctermfg=15  
"DarkSlateGray3=116  
hi Number          ctermfg=15  
"Cornsilk1=230  
hi Operator        ctermfg=15  
"Tan=180  
hi PreCondit       ctermfg=15   cterm=bold
"NavajoWhite1=223  
hi PreProc         ctermfg=15   cterm=bold
"White=15
hi Question        ctermfg=15    cterm=bold
"NavajoWhite1=223  
hi Repeat          ctermfg=15   cterm=bold
"Cornsilk1=230  Grey19=236  
hi Search          ctermfg=15   ctermfg=0    
"MistyRose3=181  
hi SpecialChar     ctermfg=15   cterm=bold
"DarkSeaGreen=108  
hi SpecialComment  ctermfg=15   cterm=bold
"MistyRose3=181  
hi Special         ctermfg=15  
"DarkSeaGreen2=151  
hi SpecialKey      ctermfg=15  
"LightYellow3=187  Grey11=234  
hi Statement       ctermfg=15   ctermfg=0     cterm=none
"Grey19=236  LightGoldenrod2=186  
hi StatusLine      ctermfg=236   ctermfg=108    
"Grey15=235  DarkSeaGreen=108  
hi StatusLineNC    ctermfg=15   ctermfg=0    
"Grey70=249  
hi StorageClass    ctermfg=15   cterm=bold
"LightPink3=174  
hi String          ctermfg=15  
"Wheat1=229  
hi Structure       ctermfg=15   cterm=bold
"MistyRose3=181  
hi Tag             ctermfg=15   cterm=bold
"LightGrey=7 Grey11=234  
hi Title           ctermfg=7     ctermfg=0     cterm=bold
"DarkSeaGreen=108  Grey11=234  
hi Todo            ctermfg=15   ctermfg=0     cterm=bold
"Grey85=253  
hi Typedef         ctermfg=15   cterm=bold
"LightYellow3=187  
hi Type            ctermfg=15   cterm=bold
"Grey84=188  Grey11=234  
hi Underlined      ctermfg=15   ctermfg=0     cterm=bold
"Grey19=236  DarkSeaGreen4=65   
hi VertSplit       ctermfg=15   ctermbg=65 
"Grey19=236  LightCoral=210  
hi VisualNOS       ctermfg=15   ctermfg=0     cterm=bold
"White=15 Grey19=236  
hi WarningMsg      ctermfg=15    ctermfg=0     cterm=bold
"Grey19=236  Honeydew2=194  
hi WildMenu        ctermfg=0   ctermfg=15     cterm=bold
"Grey19=236  
hi CursorLine      ctermfg=0   cterm=none

" spellchecking, always "bright" background
"Yellow=14 Grey23=237  
hi SpellLocal ctermfg=14  ctermfg=0
"Blue=9 Grey23=237  
hi SpellBad   ctermfg=9   ctermfg=0
"Red=12 Grey23=237  
hi SpellCap   ctermfg=12  ctermfg=0
"Magenta=13 Grey23=237  
hi SpellRare  ctermfg=13  ctermfg=0

" pmenu
"Grey66=248  
hi PMenu      ctermfg=15  ctermbg=0
"NavajoWhite1=223  Grey15=235  
hi PMenuSel   ctermfg=15 ctermfg=0
