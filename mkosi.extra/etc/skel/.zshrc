NAME_COLOUR="magenta"
DIR_COLOUR="green"

# Pick the prompt colour then unset the variable for it
PS1="%B%F{$NAME_COLOUR}%n@%m %F{$DIR_COLOUR}%~%F{$DIR_COLOUR}$ %f%b"
unset NAME_COLOUR
unset DIR_COLOUR
