# Default Options
setopt warncreateglobal # Police locals
setopt rematchpcre # Use perl regex

# Perl vars
MATCH=?
MBEGIN=?
MEND=?
match=''
mbegin=''
mend=''

# Shared Functions
list_set_type () {
	_LIST_TYPE=${1}
}

# Constants
_GEO_KEY="key=uMibiyDeEGlYxeK3jx6J"
_GEO_PROVIDER="https://extreme-ip-lookup.com"
_MAX_COLS=$(tput cols)
_MAX_ROWS=$(tput lines)
_SCRIPT=${$(cut -d: -f1 <<<${funcfiletrace}):t}
_DEBUG_FILE=/tmp/${_SCRIPT}_debug.out
_XSET_DEFAULT_RATE="r rate 500 33" # Default rate
_XSET_LOW_RATE="r rate 500 8" # Menu rate

# LIB declarations
typeset -aU _DEPS_
typeset -A _BOX_COORDS=()

# LIB var inits
_CURSOR_STATE=on
_DEBUG_INIT=true
_DEBUG=0
_EXIT_MSGS=''
_LIST_TYPE=''

# Import default LIBS
if [[ -e ./LIB_INIT.zsh && ${LIB_TESTING} == 'true' ]];then
	clear;tput cup 0 0;echo "LIB TESTING is active - press any key";read
	_LIB_DIR=${PWD}
	for D in ${=_DEPS_};do
		if [[ -e ${_LIB_DIR}/${D} ]];then
			source ${_LIB_DIR}/${D}
		else
			echo "Cannot source:${_LIB_DIR}/${D} - not found"
			exit 1
		fi
	done
else
	_LIB_DIR=/usr/local/lib
fi

source ${_LIB_DIR}/ANSI.zsh
source ${_LIB_DIR}/EXIT.zsh
source ${_LIB_DIR}/LIB_DEPS.zsh

# Initialize traps
unsetopt localtraps
for SIG in {1..9}; do
	trap 'exit_sigexit '${SIG}'' ${SIG}
done
_FUNC_TRAP=true

# Initialize debugging
[[ -e ${_DEBUG_FILE} ]] && /bin/rm ${_DEBUG_FILE}

