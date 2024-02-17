# Options
setopt warncreateglobal # Police locals
setopt rematchpcre # Using perl regex

# Perl vars
MATCH=?
MBEGIN=?
MEND=?
match=''
mbegin=''
mend=''

# Constants
_CURSOR_STATE=''
_DEBUG_INIT=true
_GEO_KEY="key=uMibiyDeEGlYxeK3jx6J"
_GEO_PROVIDER="https://extreme-ip-lookup.com"
_MAX_COLS=$(tput cols)
_MAX_ROWS=$(tput lines)
_SCRIPT=${$(cut -d: -f1 <<<${funcfiletrace}):t}
_DEBUG_FILE=/tmp/${_SCRIPT}_debug.out
_XSET_DEFAULT_RATE="r rate 500 33" # Default rate
_XSET_LOW_RATE="r rate 500 8" # Menu rate
[[ -n ${LIB_TESTING} ]] && _LIB=/home/kmiller/Code/LOCAL/LIBS || _LIB=/usr/local/lib

# LIB Vars
_DEBUG=0
_EXIT_MSGS=''

# LIB Declarations
typeset -aU _DEPS_

source ${_LIB}/ANSI.zsh
source ${_LIB}/EXIT.zsh

# Initialize traps
unsetopt localtraps
for SIG in {1..9}; do
	trap 'exit_sigexit '${SIG}'' ${SIG}
done

[[ -e ${_DEBUG_FILE} ]] && /bin/rm ${_DEBUG_FILE}

