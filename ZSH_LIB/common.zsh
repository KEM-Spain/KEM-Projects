#Ansi
RESET="\033[m"
BOLD="\033[1m"
ITALIC="\033[3m"
UNDER="\033[4m"
REVERSE="\033[7m"
STRIKE="\033[9m"
OVERUND="\033[53m\033[4m"

BLACK_FG="\033[30m"
RED_FG="\033[31;1m"
GREEN_FG="\033[32m"
YELLOW_FG="\033[33m"
BLUE_FG="\033[34m"
MAGENTA_FG="\033[35m"
CYAN_FG="\033[36m"
WHITE_FG="\033[37m"

BLACK_BG="\033[40m"
RED_BG="\033[41m"
GREEN_BG="\033[42m"
YELLOW_BG="\033[43m"
BLUE_BG="\033[44m"
MAGENTA_BG="\033[45m"
CYAN_BG="\033[46m"
WHITE_BG="\033[47m"

E_BOLD=$(echo -n "\033[1m")
E_ITALIC=$(echo -n "\033[3m")
E_RESET=$(echo -n "\033[m")
E_REVERSE=$(echo -n "\033[7m")
E_STRIKE=$(echo -n "\033[9m")
E_UNDER=$(echo -n "\033[4m")

E_BLACK_FG=$(echo -n "\033[30m")
E_BLUE_FG=$(echo -n "\033[34m")
E_CYAN_FG=$(echo -n "\033[36m")
E_GREEN_FG=$(echo -n "\033[32m")
E_MAGENTA_FG=$(echo -n "\033[35m")
E_RED_FG=$(echo -n "\033[31m")
E_WHITE_FG=$(echo -n "\033[37m")
E_YELLOW_FG=$(echo -n "\033[33m")

E_BLACK_BG=$(echo -n "\033[40m")
E_BLUE_BG=$(echo -n "\033[44m")
E_CYAN_BG=$(echo -n "\033[46m")
E_GREEN_BG=$(echo -n "\033[42m")
E_MAGENTA_BG=$(echo -n "\033[45m")
E_RED_BG=$(echo -n "\033[41m")
E_WHITE_BG=$(echo -n "\033[47m")
E_YELLOW_BG=$(echo -n "\033[43m")

E_BLK_CSR=$(echo -n "\033[1 q")
E_DSH_CSR=$(echo -n "\033[3 q")

#Utils
tp () {
	tput -T${TERM:=xterm} ${@}
}

#Options
setopt warncreateglobal
setopt rematchpcre #using perl regex

#Perl vars
MATCH=?
MBEGIN=?
MEND=?
match=''
mbegin=''
mend=''

#Constants
_GHOST_ROW=2 #item appears in list but is no longer selectable; any value above 1 is considered a ghost
_XSET_DEFAULT_RATE="r rate 500 33" #default rate
_XSET_LOW_RATE="r rate 500 8" #default rate
_MAX_COLS=$(tp cols)
_MAX_ROWS=$(tp lines)
_SCRIPT=${$(cut -d: -f1 <<<${funcfiletrace}):t}
_DEBUG_FILE=/tmp/debug.out

#Globals
_BAREWORD_IS_FILE=false
_BARLINES=false
_CB_KEY=''
_CLEAR_GHOSTS=false
_CLIENT_WARN=true
_CURRENT_ARRAY=1
_CURRENT_CURSOR=0
_CURRENT_PAGE=1
_CURSOR=on
_CURSOR_COL=${CURSOR_COL:=0}
_CURSOR_ROW=${CURSOR_ROW:=0}
_DEBUG=0
_EXIT_MSGS=''
_EXIT_VALUE=0
_FIRST_PASS=true
_GEO_KEY="key=uMibiyDeEGlYxeK3jx6J"
_GEO_PROVIDER="https://extreme-ip-lookup.com"
_HEADER_CALLBACK_FUNC=?
_HOLD_CURSOR=false
_HOLD_PAGE=false
_KEY_CALLBACK_FUNC=''
_KEY_MSG=?
_LIST_ALL_SCOPE=page
_LIST_DELIM='|'
_LIST_HEADER_BREAK=false
_LIST_HEADER_BREAK_COLOR=${WHITE_FG}
_LIST_HEADER_BREAK_LEN=0
_LIST_HEADER_BREAK_OFFSET=0
_LIST_IS_SORTABLE=false
_LIST_LINE_ITEM=?
_LIST_PROMPT=?
_LIST_PROMPT=?
_LIST_SELECT_NDX=0
_LIST_SELECT_ROW=0
_LIST_SORT_COLS=0
_LIST_SORT_ENGINE=default
_LIST_SORT_TYPE=regular
_LIST_TOGGLE_STATE=off
_LIST_USER_PROMPT_STYLE=none
_MSG_KEY=n
_NO_TOP_OFFSET=false
_PAGE_OVERRIDE=false
_RAW_CMD_LINE=false #for testing
_ROW_OVERRIDE=false
_SELECTABLE=true
_SELECTION_LIMIT=0
_SELECTION_VALUE=?
_SELECT_ALL=false
_SELECT_CALLBACK_FUNC=?
_SMCUP=false
_SOURCED_APP_EXIT=false
_TRAPS=false

#Declarations
typeset -a _LIST #holds the list values to be managed by the list menu
typeset -A _LIST_SELECTED #status of selected list items; can contain 0,1,2, etc.; 0,1 can toggle; -gt 2 cannot toggle - ex: a deleted file
typeset -A _LIST_SORT_DIR #status of list sort direction
typeset -A _MSG_BOX_COORDS=(X 0 Y 0 H 0 W 0) #holds the coordinates (X,Y,H,W) of the last displayed msg_box
typeset -a _LIST_HEADER=() #holds header lines
typeset -a _LIST_INDEX_RANGE=() #holds the top and bottom screen row indicies
typeset -a _LIST_ACTION_MSGS #holds text for contextual prompts
typeset -a _MARKED #holds indexes of selected rows
typeset -a _DELIMS=('#' '|' ':' ',' '\t') #recognized field delimiters
typeset -a _DEBUG_LINES #holds debugging info 
typeset -A _ARGS #holds command line arguments for raw path parsing
typeset -A _DURABLE #holds variable values that can survive a subshell
typeset -a _SELECTION_LIST #holds indices of selected items in a list
typeset -a _TRAP_BLACKLIST=(.fm .tc)

[[ -e ${_DEBUG_FILE} ]] && /bin/rm -f ${_DEBUG_FILE} # clear any old debug msgs

#Functions
arr_get_nonzero_count () {
	local -a A=(${@})
	local CNT=0
	local E

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	for E in ${A};do
		[[ ${E} -ne 0 ]] && ((CNT++))
	done

	echo ${CNT}
}

arr_get_populated_count () {
	local -a A=(${@})
	local CNT=0
	local E

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	for E in ${A};do
		[[ -n ${E} ]] && ((CNT++))
	done

	echo ${CNT}
}

arr_in_array () {
	local ELEMENT=${1};shift
	local -a ALIST=(${@})
	local L

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	for L in ${ALIST};do
		[[ ${L} == ${ELEMENT} ]] && return 0
	done

	return 1
}

arr_is_populated () {
	local -a ARR=(${@})
	
	[[ ${#} -eq 0 ]] && echo "${0}: ${RED_FG}requires an argument${RESET} of type <ARRAY> ${#}" >&2
	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ${ARR[@]} =~ "^ *$" ]] && return 1 || return 0
}

arr_sort () {
	local DELIM=${1}

	local SORT_COL=${2}
	local SORT_DIRECTION=${3}
	local ARR_NAME=${4}
	local -a SORTED
	local SORT_DATA
	local S L

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	for L in ${(P)ARR_NAME};do
		SORT_DATA=$(cut -d"${DELIM}" -f${SORT_COL}<<<${L})
		[[ ${SORT_DATA} =~ ':' ]] && SORT_DATA="B999${SORT_DATA}"
		[[ ${SORT_DATA} =~ '-' ]] && SORT_DATA="A888${SORT_DATA}"
		[[ ${SORT_DATA} =~ '\d{4}$' ]] && SORT_DATA=$(echo ${SORT_DATA} | perl -pe 's/(.*)(\d{4})$/\2\1\2/g')
		[[ ${SORT_DATA} =~ '\d[.]\d\D' ]] && SORT_DATA=$(echo ${SORT_DATA} | perl -pe 's/([.]\d)(.*)((G|M).*)$/${1}0 ${3}/g')
		[[ ${SORT_DATA} =~ 'Mi?B' ]] && SORT_DATA="A888${SORT_DATA}"
		[[ ${SORT_DATA} =~ 'Gi?B' ]] && SORT_DATA="B999${SORT_DATA}"
		SORTED+="${SORT_DATA}|${L}"
	done

	if [[ ${SORT_DIRECTION} == 'd' ]];then #descending
		for S in ${(On)SORTED};do
			echo ${S} | perl -pe "s/^[^${DELIM}]+[${DELIM}](.*)$/\1/"
		done
	else
		for S in ${(on)SORTED};do #ascending
			echo ${S} | perl -pe "s/^[^${DELIM}]+[${DELIM}](.*)$/\1/"
		done
	fi
}

boolean_color () {
	local STATE=${1}

	case ${STATE} in
		0) echo ${GREEN_FG};;
		active) echo -n ${GREEN_FG};;
		connected) echo -n ${GREEN_FG};;
		on) echo -n ${GREEN_FG};;
		true) echo -n ${GREEN_FG};;
		valid) echo -n ${GREEN_FG};;
		running) echo -n ${GREEN_FG};;
		*) echo -n ${RED_FG};;
	esac
}

boolean_color_word () {
	local STATE=${1}
	local ANSI_ECHO=false

	[[ ${#} -eq 2 ]] && ANSI_ECHO=true
	
	case ${STATE} in
		0) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${GREEN_FG}true${RESET}" || echo -n "${E_GREEN_FG}true${E_RESET}";;
		1) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${RED_FG}false${RESET}" || echo -n "${E_RED_FG}false${E_RESET}";;
		true) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${GREEN_FG}${STATE}${RESET}" || echo -n "${E_GREEN_FG}${STATE}${E_RESET}";;
		valid) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${GREEN_FG}${STATE}${RESET}" || echo -n "${E_GREEN_FG}${STATE}${E_RESET}";;
		active) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${GREEN_FG}${STATE}${RESET}" || echo -n "${E_GREEN_FG}${STATE}${E_RESET}";;
		*) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${RED_FG}${STATE}${RESET}" || echo -n "${E_RED_FG}${STATE}${E_RESET}";;
	esac
}

cmd_get_raw () {
	local CMD_LINE

	fc -R
	CMD_LINE=("${(f)$(fc -lnr | head -1)}") #parse raw cmdline
	echo ${CMD_LINE}
}

coord_center () {
	local AREA=${1}
	local OBJ=${2}
	local CTR
	local REM
	local AC
	local OC
	local C

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	CTR=$((AREA / 2))
	REM=$((CTR % 2))
	[[ ${REM} -ne 0 ]] && AC=$((CTR+1)) || AC=${CTR}

	CTR=$((OBJ / 2))
	REM=$((CTR % 2))
	[[ ${REM} -ne 0 ]] && OC=$((CTR+1)) || OC=${CTR}

	C=$((AC-OC))

	echo ${C}
}

cursor_off () {
	tp civis #Hide cursor
	_CURSOR=off
}

cursor_on () {
	tp cnorm #Normal cursor
	_CURSOR=on
}

cursor_row () {
  echo -ne "\033[6n" > /dev/tty
  read -t 1 -s -d 'R' line < /dev/tty
  line="${line##*\[}"
  line="${line%;*}"
  echo $((line - 2))
}

cursor_save () {
	tp sc #Save cursor
}

date_diff () {
	local D1=$(date -d "$1" +%s)
	local D2=$(date -d "$2" +%s)
	local DIFF=$(( (D1 - D2) / 86400 ))

	#Expects: date +'%Y-%m-%d'
	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	echo ${DIFF} #return the difference in days
}

date_text () {
	local DATE_ARG=$1
	local TODAY YESTERDAY TEXT

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	TODAY=$(date +'%m/%d/%y')
	YESTERDAY=$(date --date="${TODAY} -1 day" +'%m/%d/%y')

	if [[ ${DATE_ARG} == ${TODAY} ]];then
		TEXT='Today' 
	elif [[ ${DATE_ARG} == ${YESTERDAY} ]];then
		TEXT='Yesterday' 
	else
		TEXT=${DATE_ARG}

	fi

	echo ${TEXT}
}

dbg () {
	local -a ARGS=(${@})
	local LINE
	local A

	[[ ${_DEBUG} -gt 5 ]] && echo "Entered ${0} with args:${WHITE_FG}${@}${RESET}" >&2

	if [[ ${#} -ne 0 ]];then
		dbg_to_file ${ARGS} #with arguments
	else
		while read LINE;do
			ARGS+="${LINE}\n"
		done
		echo ${ARGS} | dbg_record #piped to array
	fi
}

dbg_msg () {
	local D
	local LINE

	echo 

	for D in ${_DEBUG_LINES};do
		echo ${D}
	done

	if [[ -f ${_DEBUG_FILE} ]];then
		while read LINE;do
			echo ${LINE}
		done <${_DEBUG_FILE}
		sudo /bin/rm -f ${_DEBUG_FILE}
	fi

	dbg_trace
}

dbg_parse () {
	local FN=$(cut -d: -f1 <<<${@})
	local LN=$(cut -d: -f2 <<<${@})

	(
	sed -n ${LN}p ${FN} | tr -d '[(){}]' | tr -s '[:space:]' | str_trim
	) 2>/dev/null
}

dbg_record () {
	local LINE

	_DEBUG_LINES+="-- msgs --"

	while read LINE;do
		_DEBUG_LINES+=${LINE}
	done

	_DEBUG_LINES+=$(dbg_trace)
}

dbg_set_level () {
	((_DEBUG++))
}

dbg_to_file () {
	local -a ARGS=(${@})
	local A

	[[ -n ${ARGS} ]] && echo "-- msgs --" >>${_DEBUG_FILE}
	for A in ${ARGS};do
		echo ${A} >>${_DEBUG_FILE}
	done
}

dbg_trace () {
	local CALLER
	local CALLER_SOURCE
	local CALLER_LINE
	local L
	local FIRST=true
	local DD=false

	for L in ${(on)funcfiletrace};do
		[[ ${L} =~ "dbg" ]] && continue #omit calls to any dbg func
		CALLER=$(realpath $(cut -d: -f1 <<<${L}))
		CALLER_LINE=$(cut -d: -f2 <<<${L})
		CALLER_SOURCE=$(dbg_parse ${L})
		[[ ${CALLER_SOURCE} =~ "dbg" ]] && continue #omit calls to all dbg_* funcs
		[[ ${DD} == 'true' ]] && echo "Debugging DEBUG: L:${L} CALLER:${CALLER}"
		[[ ${FIRST} == 'true' ]] && echo "\nFunc File\n---------" && FIRST=false
		printf "%30s called: %s on line %d\n" ${CALLER} ${CALLER_SOURCE} ${CALLER_LINE}
	done

	FIRST=true
	for L in ${(Oa)funcstack};do
		[[ ${L} =~ "dbg" ]] && continue #omit calls to any dbg func
		[[ ${FIRST} == 'true' ]] && echo "\nFunc Stack\n----------" && FIRST=false
		echo ${L}
	done

	FIRST=true
	for L in ${(Oa)functrace};do
		[[ ${L} =~ "dbg" ]] && continue #omit calls to any dbg func
		[[ ${FIRST} == 'true' ]] && echo "\nFunc Trace\n----------" && FIRST=false
		echo ${L}
	done
}

do_rmcup () {
	[[ ${_SMCUP} == 'false' ]] && return
	tp rmcup
	#echo "called rmcup"
	_SMCUP=false
}

do_smcup () {
	[[ ${_SMCUP} == 'true' ]] && return
	#echo "calling smcup"
	tp smcup
	_SMCUP=true
}

durable_array () {
	local NAME=${1}
	local LINE
	local KEY
	local VAL

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	if [[ -e /tmp/${NAME} ]];then
		while read LINE;do
			KEY=$(cut -d: -f1 <<<${LINE})
			VAL=$(cut -d: -f2 <<<${LINE})
			_DURABLE[${KEY}]=${VAL}
		done < /tmp/${NAME}
	else
		echo "${0}: durable name:${NAME} not found" >&2
		return 1
	fi
}

durable_get () {
	local NAME=${1}
	local KEY=${2}
	local VAL

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	if [[ -e /tmp/${NAME} ]];then
		VAL=$(grep --color=never "${KEY}:" < /tmp/${NAME} | cut -d: -f2)
	else
		echo "${0}: durable name:${NAME} not found" >&2
		return 1
	fi

	echo -n ${VAL}
}

durable_set () {
	local NAME=${1}
	local KEY=${2}
	local VAL="${3}"

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	#remove old value
	if [[ -e /tmp/${NAME} ]];then
		sed -i "/${KEY}:/d" /tmp/${NAME}
	fi

	#add new value
	echo "${KEY}:${VAL}" >> /tmp/${NAME}
}

exit_leave () {
	local MSGS=(${@})

	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}: CALLER:${functrace[1]}, #_MSGS:${#_MSGS}, _SOURCED_APP_EXIT:${_SOURCED_APP_EXIT}, _SMCUP:${_SMCUP}, _TRAPS:${_TRAPS}"

	[[ -n ${MSGS} ]] && _EXIT_MSGS=${MSGS}
	[[ ${_TRAPS} == 'false' ]] && exit_pre_exit #traps not activated; call pre_exit manually
	[[ ${_DEBUG} -gt 0 ]] && dbg_msg | mypager && /bin/rm -f ${_DEBUG_FILE}
	
	if [[ ${_APP_IS_SOURCED} == 'true' ]];then
		[[ ${CURSOR} == 'off' ]] && cursor_on
		_SOURCED_APP_EXIT=true
		echo ${MSGS}
		return 9
	fi

	[[ ! ${functrace[1]} =~ 'usage' && ${_SMCUP} == 'true' ]] && do_rmcup

	kill -SIGINT $$ #fire the traps
}

exit_pre_exit () {
	[[ ${_DEBUG} -gt 0 ]] && echo "${0}: CALLER:${functrace[1]}, #_EXIT_MSGS:${#_EXIT_MSGS}"

	if [[ ${XDG_SESSION_TYPE:l} == 'x11' ]];then
		xset r on #reset key repeat
		eval "xset ${_XSET_DEFAULT_RATE}" #reset key rate
		[[ ${_DEBUG} -gt 0 ]] && echo "${0}: reset key rate:${_XSET_DEFAULT_RATE}"
	fi

	[[ ${_CURSOR} == 'off' ]] && cursor_on
	[[ ${_DEBUG} -gt 0 && ${_CURSOR} == 'off' ]] && echo "${0}: restored cursor"

	kbd_activate
	[[ ${_DEBUG} -gt 0 ]] && echo "${0}: activated keyboard"

	[[ -n ${_EXIT_MSGS} ]] && echo ${_EXIT_MSGS}

	[[ ${$(tabs -d | grep --color=never -o "tabs 8")} != 'tabs 8' ]] && tabs 8
	[[ ${_DEBUG} -gt 0 ]] && echo "${0}: reset tabstops"

	if typeset -f _cleanup > /dev/null; then
		[[ ${_DEBUG} -gt 0 ]] && echo "${0}: cleaning up"
		_cleanup
	fi

	[[ ${_DEBUG} -gt 0 ]] && echo "${0}: _EXIT_VALUE:${_EXIT_VALUE}"
}

exit_request () {
	msg_box -p "Quit application (y/n)"
	[[ ${_MSG_KEY} == 'y' ]] && exit_leave
	msg_box_clear
}

exit_sigexit () {
	local SIG=${1}
	local SIGNAME
	local -A SIGNAMES=(\
		1 "Terminal vanished" 2 "Control-C" 3 "Core Dump" 4 "Illegal Instruction" 5 "Conditional Exit (DEBUG)" 6 "Emergency Abort"\
		7 "Memory Error" 8 "FLoating Point Exception" 9 "Termination Called fom kill"
	)

	#traps arrive here
	SIGNAME=$(kill -l ${SIG})
	[[ ${_DEBUG} -gt 0 ]] && dbg "Exited via interrupt: ${SIG} (${SIGNAME}) ${SIGNAMES[${SIG}]}" #announce the interrupt

	exit_pre_exit #pre-exit housekeeping

	exit ${_EXIT_VALUE} #leave the app
}

file_date_diff () {
	local F1=${1}
	local F2=${2}
	local F1_EPOCH
	local F2_EPOCH
	
	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ! -e ${F1} ]] && exit_leave "${0}: Argument:${F1} not found"
	[[ ! -e ${F2} ]] && exit_leave "${0}: Argument:${F2} not found"

	F1_EPOCH=$(stat -c"%Y" ${F1})
	F2_EPOCH=$(stat -c"%Y" ${F2})

	[[ ${F1_EPOCH} -gt ${F2_EPOCH} ]] && echo ${F1} || echo ${F2} #return the newest file
}

format_pct () {
	local ARG=${1}
	local -F1 P1
	local -F2 P2
	local -F3 P3
	local -F4 P4
	local -F5 P5
	local -F6 P6
	local -F7 P7
	local -F8 P8
	local PCT

	#Decrease decimal places based on intensity
	P8=${ARG}
	PCT=${P8}

	if [[ ${P8} -ge .1 ]];then
		P1=${P8} && PCT=${P1}
	elif [[ ${P8} -ge .01 ]];then
		P2=${P8} && PCT=${P2}
	elif [[ ${P8} -ge .001 ]];then
		P3=${P8} && PCT=${P3}
	elif [[ ${P8} -ge .0001 ]];then
		P4=${P8} && PCT=${P4}
	elif [[ ${P8} -ge .00001 ]];then
		P5=${P8} && PCT=${P5}
	elif [[ ${P8} -ge .000001 ]];then
		P6=${P8} && PCT=${P6}
	elif [[ ${P8} -ge .0000001 ]];then
		P7=${P8} && PCT=${P7}
	else
		PCT=0
	fi

	echo ${PCT}
}

get_exit_value () {
	echo ${_EXIT_VALUE}
}

is_bare_word () {
	local TEXT="${@}"

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ${TEXT} =~ '\*' || ${TEXT} =~ '\~' || ${TEXT} =~ '^/.*' ]] && return 1

	if [[ ${_BAREWORD_IS_FILE} == 'false' ]];then #bare words should be tested as possible file and dir names
		[[ -f ${TEXT:Q} || -d ${TEXT:Q} ]] && return 1 || return 0
	fi
}

is_dir () {
	local TEXT="${@}"

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	TEXT=$(eval "echo ${TEXT}")
	[[ -d ${TEXT} ]] && return 0 || return 1
}

is_file () {
	local TEXT="${@}"

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ -f ${TEXT:Q} ]] && return 0 || return 1
}

is_glob () {
	local TEXT="${@}"

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ${TEXT:Q} =~ '\*' ]] && return 0 || return 1
}

is_singleton () {
	local EXEC_NAME=${1}
	local INSTANCES=$(pgrep -fc ${EXEC_NAME})

	[[ ${INSTANCES} -eq 0 ]] && return 0 || return 1
}

is_sym_dir () {
	local ARG=${1}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ${ARG} =~ '^[\.~]$' ]] && return 0 || return 1
}

kbd_activate () {
	[[ ${XDG_SESSION_TYPE:l} != 'x11' ]] && return 0

	local KEYBOARD_DEV=$(kbd_get_keyboard_id)

	xinput reattach ${KEYBOARD_DEV} 3
}

kbd_get_keyboard_id () {
	[[ ${XDG_SESSION_TYPE:l} != 'x11' ]] && return 0

	local KEYBOARD_DEV=$(xinput list | grep  "AT Translated" | cut -f2 | cut -d= -f2)

	echo ${KEYBOARD_DEV}
}

kbd_suspend () {
	[[ ${XDG_SESSION_TYPE:l} != 'x11' ]] && return 0

	local KEYBOARD_DEV=$(kbd_get_keyboard_id)

	xinput float ${KEYBOARD_DEV}
}

list_add_header_break () {
	_LIST_HEADER_BREAK=true
}

list_call_sort () {
	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	case ${_LIST_SORT_ENGINE} in
		assoc) list_sort_assoc;;
		default) list_sort;;
	esac
}

list_do_header () {
	local PAGE=${1}
	local MAX_PAGES=${2}
	local CLEAN_HDR
	local CLEAN_TAG
	local HDR_COPY
	local HDR_LINE
	local HDR_PG=false
	local L
	local LONGEST_HDR=0
	local PAD_LEN
	local PAD_TAG
	local PG_TAG
	local SCRIPT_TAG
	local SELECTED_COUNT=$(list_get_selected_count); 

	[[ ${_DEBUG} -gt 3 ]] && dbg "${0}:HEADER COUNT:${#_LIST_HEADER}"

	for ((L=1; L<=${#_LIST_HEADER}; L++))do
		HDR_LINE=$(eval ${_LIST_HEADER[${L}]})
		CLEAN_HDR=$(str_strip_ansi <<<${HDR_LINE})
		[[ ${#CLEAN_HDR} > ${LONGEST_HDR} ]] && LONGEST_HDR=${#CLEAN_HDR}
	done

	tp cup 0 0
	tp el
	for ((L=1; L<=${#_LIST_HEADER}; L++))do
		if [[ -n ${_LIST_HEADER[${L}]} ]];then
			HDR_LINE=$(eval ${_LIST_HEADER[${L}]})

			if [[ ${L} -eq 1 ]];then
				SCRIPT_TAG='printf "${_LIST_HEADER_BREAK_COLOR}[${RESET}${_SCRIPT}${_LIST_HEADER_BREAK_COLOR}]${RESET}"'
				SCRIPT_TAG=$(eval ${SCRIPT_TAG})
				HDR_LINE="${SCRIPT_TAG} ${HDR_LINE}"
			fi

			[[ ${_LIST_HEADER[${L}]} =~ '_PG' ]] && HDR_PG=true

			if [[ ${HDR_PG} == 'true' ]];then
				CLEAN_HDR=$(str_strip_ansi <<<${HDR_LINE})
				PG_TAG=$(eval "printf 'Page:${WHITE_FG}%d${RESET} of ${WHITE_FG}%d${RESET}' ${PAGE} ${MAX_PAGES}")
				PAD_LEN=$(( LONGEST_HDR - ${#CLEAN_HDR} ))
				CLEAN_TAG=$(str_strip_ansi <<<${PG_TAG})
				PAD_LEN=$(( PAD_LEN - (${#CLEAN_TAG}+1) ))
				PG_TAG="$(str_rep_char ' ' ${PAD_LEN})${PG_TAG}"
				HDR_LINE="${HDR_LINE}${PG_TAG}"
				HDR_PG=false
			fi
			
			tp el
			echo ${HDR_LINE}

		fi

		CLEAN_HDR=$(str_strip_ansi <<<${HDR_LINE})
		[[ ${#CLEAN_HDR} -gt ${LONGEST_HDR} ]] && LONGEST_HDR=${#CLEAN_HDR}

		tp cup ${L} 0
	done

	_LIST_HEADER_BREAK_LEN=$(( LONGEST_HDR + _LIST_HEADER_BREAK_OFFSET ))

	if [[ ${_LIST_HEADER_BREAK} == 'true' ]];then
		tp el
		echo -n ${_LIST_HEADER_BREAK_COLOR}
		str_unicode_line ${_LIST_HEADER_BREAK_LEN}
		echo -n ${RESET}
	fi
}

list_get_index_range () {
	echo "${_LIST_INDEX_RANGE}"
}

list_get_keys () {
	local PROMPT
	local RESP=?;
	local -a NUM
	local K1 K2 K3 KEY
		
	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	PROMPT=${@}

	(tp cup $((_MAX_ROWS-2)) 0;printf "${PROMPT}")>&2 #position cursor and display prompt to STDERR

	[[ ${XDG_SESSION_TYPE:l} == 'x11' ]] && eval "xset ${_XSET_LOW_RATE}"

	while read -sk1 KEY;do
		[[ -z ${KEY} ]] && break
		# slurp input buffer
		read -sk1 -t 0.0001 K1
		read -sk1 -t 0.0001 K2
		read -sk1 -t 0.0001 K3
		KEY+=${K1}${K2}${K3}

		case "${KEY}" in 
			$'\x0A') RESP=0;; #Return
			$'\e[A') RESP=1;; #Up
			$'\e[B') RESP=2;; #Down
			$'\e[D') RESP=3;; #Left
			$'\e[C') RESP=4;; #Right
			$'\e[5~') RESP=5;; #PgUp
			$'\e[6~') RESP=6;; #PgDn
			$'\e[H') RESP=7;; #Home
			$'\e[F') RESP=8;; #End
			$'\x7F') if [[ ${#NUM} -gt 0 ]];then #BackSpace
							NUM[${#NUM}]=()
							echo -n " ">&2
						fi;;
			      *) RESP=$(printf '%d' "'${KEY}");; #ascii letter value
		esac

		if [[ ${RESP} != "?" ]];then
			if [[ -z ${NUM} ]];then
				[[ ${RESP} -lt 65 ]] && echo ${RESP} || echo $(list_key_trans ${RESP})
			else
				echo "K${(j::)NUM}"
			fi
			break
		fi
	done

	[[ ${XDG_SESSION_TYPE:l} == 'x11' ]] && eval "xset ${_XSET_DEFAULT_RATE}"
}

list_get_selected () {
	local S

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	for S in ${(k)_LIST_SELECTED};do
		[[ ${_LIST_SELECTED[${S}]} -ne 1 ]] && continue
		echo ${S}
	done
}

list_get_selected_count () {
	local COUNT=0
	local S

	for S in ${(k)_LIST_SELECTED};do
		[[ ${_LIST_SELECTED[${S}]} -ne 1 ]] && continue
		((COUNT++))
	done

	echo ${COUNT}
}

list_get_selection_limit () {
	echo ${_SELECTION_LIMIT}
}

list_is_valid_selection () {
	local -a SELECTED
	local MAX
	local MIN
	local N

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	MIN=${1};shift
	MAX=${1};shift
	SELECTED=(${@})

	for N in ${SELECTED};do
		if ! validate_is_integer ${N};then
			return 1
		elif ! list_is_within_range ${N} ${MIN} ${MAX};then
			return 1
		elif [[ ${_CLEAR_GHOSTS} == 'false' && ${_LIST_SELECTED[${N}]} -ge ${_GHOST_ROW} && ${_SELECT_ALL} == 'false' ]];then #cannot select deleted row; select 'all' is exception
			return 1
		fi
	done

	return 0
}

list_is_within_range () {
	local NDX=${1}
	local MIN=${2}
	local MAX=${3}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	if [[ ${NDX} -ge ${MIN} && ${NDX} -le ${MAX} ]];then
		return 0
	else
		echo "Selection:${NDX} not in page range ${MIN}-${MAX}"
		return 1
	fi
}

list_item_highlight () {
	local LINE_ITEM=${1}
	local X_POS=${2}
	local Y_POS=${3}
	local SHADE=${4}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:LINE_ITEM:${LINE_ITEM}"

	tp cup ${X_POS} ${Y_POS}
	[[ ${_SELECTABLE} == 'true' ]] && tp smso

	if [[ $_BARLINES == 'true' ]];then
		BARLINE=$((ARRAY_NDX % 2)) #barlining 
		[[ ${BARLINE} -ne 0 ]] && BAR=${BLACK_BG} || BAR="" #barlining
	fi

	eval ${LINE_ITEM} #output line

	tp rmso
}

list_item_normal () {
	local LINE_ITEM=${1}
	local X_POS=${2}
	local Y_POS=${3}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:LINE_ITEM:${LINE_ITEM}"

	tp rmso
	tp cup ${X_POS} ${Y_POS}

	if [[ $_BARLINES == 'true' ]];then
		BARLINE=$((ARRAY_NDX % 2)) #barlining 
		[[ ${BARLINE} -ne 0 ]] && BAR=${BLACK_BG} || BAR="" #barlining
	fi

	eval ${LINE_ITEM} #output line
}

list_key_trans () {
	local KEY_IN=${1}
	local KEY_OUT

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	case ${KEY_IN} in
		32) KEY_OUT=32;; #Space
		65) KEY_OUT=65;; #A
		68) KEY_OUT=68;; #D
		69) KEY_OUT=69;; #E
		97) KEY_OUT=97;; #a
		98) KEY_OUT=98;; #b
		99) KEY_OUT=99;; #c
		100) KEY_OUT=100;; #d
		101) KEY_OUT=101;; #e
		102) KEY_OUT=102;; #f
		103) KEY_OUT=103;; #g
		104) KEY_OUT=104;; #h
		105) KEY_OUT=105;; #i
		106) KEY_OUT=106;; #j
		107) KEY_OUT=107;; #k
		108) KEY_OUT=108;; #l
		109) KEY_OUT=109;; #m
		110) KEY_OUT=110;; #n
		111) KEY_OUT=111;; #o
		112) KEY_OUT=112;; #p
		113) KEY_OUT=113;; #q
		114) KEY_OUT=114;; #r
		115) KEY_OUT=115;; #s
		116) KEY_OUT=116;; #t
		117) KEY_OUT=117;; #u
		118) KEY_OUT=118;; #v
		119) KEY_OUT=119;; #w
		120) KEY_OUT=120;; #x
		121) KEY_OUT=121;; #y
		122) KEY_OUT=122;; #z
		*) KEY_OUT=${KEY_IN};;
	esac
	echo ${KEY_OUT}
}

list_mark_all () {
	local -a RANGE=($@)
	local -a SELECTED
	local NDX=0

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	for (( NDX=${RANGE[1]}; NDX <= ${RANGE[2]}; NDX++ ));do
		[[ ${_CLEAR_GHOSTS} == 'false' && ${_LIST_SELECTED[${NDX}]} -ge ${_GHOST_ROW} ]] && continue
		SELECTED[${NDX}]=${NDX}
	done

	echo ${SELECTED}
}

list_parse_series () {
	local PATTERN=(${@})
	local -a FROM=()
	local -a TO=()
	local -a R1=()
	local -a R2=()
	local -a SELECTED=()
	local -a KEYLIST=()
	local RANGE=false
	local BEG
	local END
	local P K

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	PATTERN+="#" #force extra parse cycle

	for P in ${PATTERN};do
		[[ ${P} == '-' ]] && RANGE=true && continue

		if [[ ${P} =~ "[,# ]" ]];then #hit separator
			if [[ ${RANGE} == 'true' ]];then
				BEG=$(str_array_to_num ${FROM})
				KEYLIST+="B${BEG}"
				FROM=()
				END=$(str_array_to_num ${TO})
				KEYLIST+="E${END}"
				TO=()
			else
				ITEM=$(str_array_to_num ${FROM})
				KEYLIST+=${ITEM}

				FROM=()
			fi
			RANGE=false
			continue
		fi

		if [[ ${RANGE} == 'true' ]];then
			TO+=${P}
		else
			FROM+=${P}
		fi
	done


	for K in ${KEYLIST};do
		if [[ ${K[1,1]} =~ "[BE]" ]];then
			case ${K[1,1]} in
				B) R1+=${K[2,${#K}]};continue;;
				E) R2+=${K[2,${#K}]};continue;;
			esac
		fi
		SELECTED+=${K} #non range element
	done


	#handle range elements
	if [[ -n ${R1} ]];then
		for ((X=1;X<=${#R1};X++));do
			SELECTED+=$(echo {${R1[${X}]}..${R2[${X}]}})
		done
	fi

	echo ${SELECTED}
}

list_quote_marked_elements () {
	local MARKED=(${@})
	local M
	local -a STR

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	for M in ${MARKED};do
		STR+=${(qqq)_LIST[${M}]}
	done

	echo ${STR}
}

list_remove_selected () {
	local NDX=${1}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	_LIST_SELECTED[${NDX}]=0
}

list_repaint () {
	local ARRAY_NDX=${1}
	local TOP_OFFSET=${2}
	local MAX_DISPLAY_ROWS=${3}
	local MAX_ITEM=${4}
	local PAGE=${5}
	local FIRST_ITEM=$((((PAGE*MAX_DISPLAY_ROWS)-MAX_DISPLAY_ROWS)+1))
	local LAST_ITEM=$((PAGE*MAX_DISPLAY_ROWS))
	local CURSOR_NDX=1
	local S R
	local OUT

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ${LAST_ITEM} -gt ${MAX_ITEM} ]] && LAST_ITEM=${MAX_ITEM} #partial page

	tp cup ${TOP_OFFSET} 0
	for ((R=0; R<${MAX_DISPLAY_ROWS}; R++));do
		tp cup $((TOP_OFFSET+CURSOR_NDX-1)) 0
		if [[ ${ARRAY_NDX} -le ${MAX_ITEM} ]];then
			OUT=${ARRAY_NDX}

			BARLINE=$((NDX % 2)) #barlining 
			[[ ${BARLINE} -ne 0 ]] && BAR=${BLACK_BG} || BAR="" #barlining

			[[ ${_LIST_SELECTED[${OUT}]} -eq 1 ]] && SHADE=${REVERSE} || SHADE=''
			eval ${_LIST_LINE_ITEM} #Output the line
		else
			printf "\n" #Output filler
		fi
		((ARRAY_NDX++))
		((CURSOR_NDX++))
	done

	list_do_header ${PAGE} ${MAX_PAGES}
}

list_select () {
	local -a ACTION_MSGS
	local -a LIST_RANGE
	local -a LIST_SELECTION=()
	local ARRAY_NDX=0
	local BARLINE BAR SHADE
	local BOT_OFFSET=3
	local COLS=$(tp cols)
	local CURSOR_NDX=0
	local DIR_KEY
	local HDR_NDX
	local ITEM
	local KEY
	local KEY_MSG
	local L R S 
	local LAST_ARRAY_NDX=0
	local LINE_ITEM
	local LIST_DATA
	local MAX_CURSOR
	local MAX_DISPLAY_ROWS
	local MAX_ITEM
	local MAX_LINE_WIDTH=$(((COLS - ${#${#_LIST}}) - 10)) #display-cols minus width-of-line-number plus a 10 space margin
	local MAX_PAGES
	local OUT
	local PAGE=1
	local PAGE_BREAK
	local PAGE_RANGE_BOT
	local PAGE_RANGE_TOP
	local PARTIAL
	local RANGE_CHECK_OPTION
	local REM
	local ROWS=$(tp lines)
	local SELECTED_COUNT=0
	local SELECTION
	local SELECTION_LIMIT=$(list_get_selection_limit)
	local TOP_OFFSET
	local USER_PROMPT

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	#Initialization
	_LIST=(${@})
	MAX_ITEM=${#_LIST}
	_SELECT_ALL=false
	[[ ${_CURSOR} == 'on' ]] && cursor_off
	
	#Calculate display rows based on number of header lines
	[[ -z ${_LIST_HEADER} ]] && _LIST_HEADER+='printf "List of %-d items\tPage %-d of %-d \tSelected:%-d" ${MAX_ITEM} ${PAGE} ${MAX_PAGES} ${SELECTED_COUNT}' # default header
	TOP_OFFSET=${#_LIST_HEADER}
	[[ ${_LIST_HEADER_BREAK} == 'true' ]] && ((TOP_OFFSET++))

	#Boundaries
	MAX_DISPLAY_ROWS=$(( ROWS-(TOP_OFFSET+BOT_OFFSET) ))
	MAX_PAGES=$((MAX_ITEM / MAX_DISPLAY_ROWS))
	REM=$((MAX_ITEM % MAX_DISPLAY_ROWS))
	[[ ${REM} -ne 0 ]] && ((MAX_PAGES++))

	#Defaults for Header, Prompt, and Line_Item formatting
	[[ ${_LIST_LINE_ITEM} == '?' ]] && _LIST_LINE_ITEM='printf "${BOLD}${WHITE_FG}%*d${RESET}) ${SHADE}%s${RESET}\n" ${#MAX_ITEM} ${ARRAY_NDX} ${${_LIST[${ARRAY_NDX}]}[1,${MAX_LINE_WIDTH}]}'
	[[ ${_LIST_PROMPT} != '?' ]] && USER_PROMPT=${_LIST_PROMPT} || USER_PROMPT="Enter to toggle selection"
	[[ -n ${_LIST_ACTION_MSGS[1]} ]] && ACTION_MSGS[1]=${_LIST_ACTION_MSGS[1]} || ACTION_MSGS[1]="process"
	[[ -n ${_LIST_ACTION_MSGS[2]} ]] && ACTION_MSGS[2]=${_LIST_ACTION_MSGS[2]} || ACTION_MSGS[2]="item"
	[[ ${_KEY_MSG} != '?' ]] && KEY_MSG=$(eval ${_KEY_MSG}) || KEY_MSG=$(printf "Press ${WHITE_FG}%s%s%s%s${RESET} Home End PgUp PgDn <${WHITE_FG}n${RESET}>ext, <${WHITE_FG}p${RESET}>rev, <${WHITE_FG}b${RESET}>ottom, <${WHITE_FG}t${RESET}>op, <${WHITE_FG}c${RESET}>lear, vi[${WHITE_FG}j,k${RESET}], <${WHITE_FG}a${RESET}>ll${RESET}, <${GREEN_FG}Enter${RESET}>${RESET}, <${WHITE_FG}q${RESET}>uit${RESET}" $'\u2190' $'\u2191' $'\u2193' $'\u2192')
	USER_PROMPT="${KEY_MSG}\n${USER_PROMPT}"

	#Navigation init
	PAGE_BREAK=false
	PAGE_RANGE_TOP=1
	PAGE_RANGE_BOT=${MAX_DISPLAY_ROWS}
	list_set_index_range ${PAGE_RANGE_TOP} ${PAGE_RANGE_BOT}
	#End of Initialization

	#Display current page of list items
	while true;do
		tp clear

		#Prepare page display
		#Navigation; maintain 2 indexes; 1 for array access (ARRAY_NDX), 1 for cursor position (CURSOR_NDX)
		if [[ ${PAGE_BREAK} == 'true' ]];then
			PAGE=$(list_set_page ${DIR_KEY} ${PAGE} ${MAX_PAGES}) #next page
			PAGE_RANGE_TOP=$(( (PAGE-1) * MAX_DISPLAY_ROWS +1 ))
			PAGE_RANGE_BOT=$(( (PAGE_RANGE_TOP-1) + MAX_DISPLAY_ROWS ))
			list_set_index_range ${PAGE_RANGE_TOP} ${PAGE_RANGE_BOT}
			PAGE_BREAK=false
		elif [[ ${_HOLD_PAGE} == 'true' ]];then
			PAGE=${_CURRENT_PAGE} #current page
			PAGE_RANGE_TOP=$(( (_CURRENT_PAGE-1) * MAX_DISPLAY_ROWS +1 ))
			PAGE_RANGE_BOT=$(( (PAGE_RANGE_TOP-1) + MAX_DISPLAY_ROWS ))
			list_set_index_range ${PAGE_RANGE_TOP} ${PAGE_RANGE_BOT}
			_HOLD_PAGE=false #reset
		fi

		_CURRENT_PAGE=${PAGE} #store current page position

		LIST_RANGE=($(list_get_index_range))
		PAGE_RANGE_TOP=${LIST_RANGE[1]}
		PAGE_RANGE_BOT=${LIST_RANGE[2]}

		[[ ${PAGE_RANGE_BOT} -gt ${MAX_ITEM} ]] && PAGE_RANGE_BOT=${MAX_ITEM} #page boundary check

		list_do_header ${PAGE} ${MAX_PAGES}

		[[ ${_NO_TOP_OFFSET} == 'false' ]] && tp cup ${TOP_OFFSET} 0 #place cursor
		 
		#Initialize page display
		ARRAY_NDX=$((PAGE_RANGE_TOP-1)) #prime page top

		for ((R=0; R<${MAX_DISPLAY_ROWS}; R++));do
			((ARRAY_NDX++)) #Increment array index
			if [[ $_BARLINES == 'true' ]];then #barlining 
				[[ ${PAGE_BREAK} == 'false' ]] && BARLINE=$((ARRAY_NDX % 2))
				[[ ${BARLINE} -ne 0 ]] && BAR=${BLACK_BG} || BAR=""
			fi
			if [[ ${ARRAY_NDX} -le ${MAX_ITEM} ]];then
				OUT=${ARRAY_NDX}
				[[ ${_LIST_SELECTED[${OUT}]} -eq 1 ]] && SHADE=${REVERSE} || SHADE=''
				eval ${_LIST_LINE_ITEM} #Output line item
			else
				printf "\n" #Output filler
			fi
		done

		#Page is displayed; initialize navigation
		if [[ ${_HOLD_CURSOR} == 'true' ]];then
			ARRAY_NDX=${_CURRENT_ARRAY} #hold array position
			CURSOR_NDX=${_CURRENT_CURSOR} #hold cursor position
			[[ ${_LIST_SELECTED[${ARRAY_NDX}]} -eq 1 ]] && SHADE=${REVERSE} || SHADE='' 
			list_item_highlight ${_LIST_LINE_ITEM} $(( (CURSOR_NDX+TOP_OFFSET) -1)) 0 ${SHADE} #highlight current item
			_HOLD_CURSOR=false #reset
		else
			ARRAY_NDX=${PAGE_RANGE_TOP} #page top
			CURSOR_NDX=1 #page top
			[[ ${_LIST_SELECTED[${ARRAY_NDX}]} -eq 1 ]] && SHADE=${REVERSE} || SHADE='' 
			list_item_highlight ${_LIST_LINE_ITEM} ${TOP_OFFSET} 0 ${SHADE} #highlight first item
		fi

		while true;do
			LAST_ARRAY_NDX=${ARRAY_NDX} #store current index
			_CURRENT_CURSOR=${CURSOR_NDX} #store current cursor position

			#Partial page boundary
			[[ ${PAGE} -eq ${MAX_PAGES} ]] && MAX_CURSOR=$(( (MAX_ITEM-PAGE_RANGE_TOP) +1 )) || MAX_CURSOR=${MAX_DISPLAY_ROWS}
	
			#WAIT FOR INPUT - get list selection(s)  - if only 1 item in list, skip selection and process item
			 
			if [[ ${#_LIST} -gt 1 ]];then
				KEY=$(list_get_keys ${USER_PROMPT})
			else 
				if [[ ${_FIRST_PASS} == 'true' ]];then
					_FIRST_PASS=false
					list_set_selected 1 1
					KEY=0
				else
					KEY=$(list_get_keys ${USER_PROMPT})
				fi
			fi

			case ${KEY} in
				1) DIR_KEY=u;((CURSOR_NDX--));ARRAY_NDX=$(list_set_index ${DIR_KEY} ${ARRAY_NDX} ${PAGE_RANGE_TOP} ${PAGE_RANGE_BOT} ${MAX_ITEM});; # Up Arrow
				2) DIR_KEY=d;((CURSOR_NDX++));ARRAY_NDX=$(list_set_index ${DIR_KEY} ${ARRAY_NDX} ${PAGE_RANGE_TOP} ${PAGE_RANGE_BOT} ${MAX_ITEM});; # Down Arrow
				3) DIR_KEY=t;CURSOR_NDX=1;ARRAY_NDX=${PAGE_RANGE_TOP};; # Left Arrow
				4) DIR_KEY=b;CURSOR_NDX=${MAX_CURSOR};ARRAY_NDX=${PAGE_RANGE_BOT};; # Right Arrow
				5) DIR_KEY=p;PAGE_BREAK=true;break;; # PgUp
				6) DIR_KEY=n;PAGE_BREAK=true;break;; # PgDn
				7) DIR_KEY=fp;PAGE_BREAK=true;break;; # Home
				8) DIR_KEY=lp;PAGE_BREAK=true;break;; # End
				32) [[ ${_SELECTABLE} == 'true' ]] && list_toggle_selected ${ARRAY_NDX} ${_SELECTION_LIMIT};; # Space
				97) [[ ${_SELECTABLE} == 'true' ]] && list_toggle_all ${PAGE_RANGE_TOP} ${TOP_OFFSET} ${MAX_DISPLAY_ROWS} ${MAX_ITEM} ${PAGE} auto;; # 'a' Toggle all
				98) DIR_KEY=lp;PAGE_BREAK=true;break;; # 'b' Top row last page
				99) [[ ${_SELECTABLE} == 'true' ]] && list_toggle_all ${PAGE_RANGE_TOP} ${TOP_OFFSET} ${MAX_DISPLAY_ROWS} ${MAX_ITEM} ${PAGE} off;; # 'c' Clear
				104) DIR_KEY=t;CURSOR_NDX=1;ARRAY_NDX=${PAGE_RANGE_TOP};; # 'h' Top Row current page
				106) DIR_KEY=d;((CURSOR_NDX++));ARRAY_NDX=$(list_set_index ${DIR_KEY} ${ARRAY_NDX} ${PAGE_RANGE_TOP} ${PAGE_RANGE_BOT} ${MAX_ITEM});; # 'j' Next row
				107) DIR_KEY=u;((CURSOR_NDX--));ARRAY_NDX=$(list_set_index ${DIR_KEY} ${ARRAY_NDX} ${PAGE_RANGE_TOP} ${PAGE_RANGE_BOT} ${MAX_ITEM});; # 'k' Prev row
				108) DIR_KEY=b;CURSOR_NDX=${MAX_CURSOR};ARRAY_NDX=${PAGE_RANGE_BOT};; # 'l' Bottom Row current page
				110) DIR_KEY=n;PAGE_BREAK=true;break;; # 'n' Next page
				112) DIR_KEY=p;PAGE_BREAK=true;break;; # 'p' Prev page
				113) exit_request;; # 'q' Quit app request
				115) list_call_sort;_HOLD_PAGE=true;break;; # 's' Sort
				116) DIR_KEY=fp;PAGE_BREAK=true;break;; # 't' Top row first page
				122) return -1;; # 'z' Quit loop
				${_CB_KEY}) ${_KEY_CALLBACK_FUNC};return -2;; # Custom runtime key
				0) SELECTED_COUNT=$(list_get_selected_count); # Enter
					_HOLD_PAGE=true;
					_HOLD_CURSOR=true;
					if [[ ${SELECTED_COUNT} -eq 0 ]];then
						break 2
					else
						if [[ ${_CLIENT_WARN} == 'true' ]];then
							list_warn_invisible_rows ${MAX_DISPLAY_ROWS} ${PAGE}
							break 2
						else
							if [[ ${_SELECTION_LIMIT} -ne 0 ]];then
								msg_box -p "${(C)ACTION_MSGS[1]} $(str_pluralize ${ACTION_MSGS[2]} ${SELECTED_COUNT})?|(y/n)"
							else
								msg_box -p "${(C)ACTION_MSGS[1]} ${SELECTED_COUNT} $(str_pluralize ${ACTION_MSGS[2]} ${SELECTED_COUNT})?|(y/n)"
							fi
							if [[ ${_MSG_KEY} == 'y' ]];then
								return ${SELECTED_COUNT}
							else
								continue
							fi
						fi
					fi
					;;
			esac

			#Cursor index boundary
			[[ ${CURSOR_NDX} -gt ${MAX_CURSOR} ]] && CURSOR_NDX=1
			[[ ${CURSOR_NDX} -lt 1 ]] && CURSOR_NDX=${MAX_CURSOR}

			#Clear highlight of last line output
			ITEM=${ARRAY_NDX}; ARRAY_NDX=${LAST_ARRAY_NDX} #save value of ARRAY_NDX
			[[ ${_LIST_SELECTED[${ARRAY_NDX}]} -eq 1 ]] && SHADE=${REVERSE} || SHADE='' 
			list_item_normal ${_LIST_LINE_ITEM} $(( TOP_OFFSET + (_CURRENT_CURSOR-1) )) 0 #_CURRENT_CURSOR is value before nav key

			#Highlight current line output
			ARRAY_NDX=${ITEM} #restore value of ARRAY_NDX
			[[ ${_LIST_SELECTED[${ARRAY_NDX}]} -eq 1 ]] && SHADE=${REVERSE} || SHADE='' 
			list_item_highlight ${_LIST_LINE_ITEM} $(( TOP_OFFSET + (CURSOR_NDX-1) )) 0 ${SHADE} #CURSOR_NDX is value after nav key

			_CURRENT_ARRAY=${ITEM} #store current array position
		done
	done

	return $(list_get_selected_count)
}

list_set_action_msgs () {
	_LIST_ACTION_MSGS=(${@})
}

list_set_all_scope () {
	_LIST_ALL_SCOPE=${1}
}

list_set_barlines () {
	_BARLINES=${1}
}

list_set_clear_ghosts () {
	_CLEAR_GHOSTS=${1}
}

list_set_client_warn () {
	_CLIENT_WARN=${1}
}

list_set_header () {
	_LIST_HEADER+=${@}
}

list_set_header_break_color () {
	_LIST_HEADER_BREAK_COLOR=${1}
}

list_set_header_break_offset () {
	_LIST_HEADER_BREAK_OFFSET=${1}
}

list_set_header_callback () {
	_HEADER_CALLBACK_FUNC=${1}
}

list_set_header_init () {
	_LIST_HEADER=()
}

list_set_index () {
	local KEY=${1}
	local ROW_NDX=${2}
	local PAGE_RANGE_TOP=${3}
	local PAGE_RANGE_BOT=${4}
	local MAX_ITEM=${5}
	local NDX

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ${PAGE_RANGE_BOT} -gt ${MAX_ITEM} ]] && PAGE_RANGE_BOT=${MAX_ITEM}

	case ${KEY} in
		u)	((ROW_NDX--));NDX=${ROW_NDX};;
		d)	((ROW_NDX++));NDX=${ROW_NDX};;
	esac

	[[ ${NDX} -lt ${PAGE_RANGE_TOP} ]] && NDX=${PAGE_RANGE_BOT}
	[[ ${NDX} -gt ${PAGE_RANGE_BOT} ]] && NDX=${PAGE_RANGE_TOP}

	echo ${NDX}
}

list_set_index_range () {
	local TOP_NDX=${1}
	local BOT_NDX=${2}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ${TOP_NDX} -lt 0 ]] && exit_leave "${0}: TOP_NDX (${TOP_NDX})must be >= 0"
	[[ ${BOT_NDX} -lt 0 ]] && exit_leave "${0}: BOT_NDX (${BOT_NDX})must be >= 0"

	_LIST_INDEX_RANGE=()
	_LIST_INDEX_RANGE+=${TOP_NDX}
	_LIST_INDEX_RANGE+=${BOT_NDX}
}

list_set_key_callback () {
	_CB_KEY=${1}
	_KEY_CALLBACK_FUNC=${2}
}

list_set_key_msg () {
	_KEY_MSG=${@}
}

list_set_line_item () {
	_LIST_LINE_ITEM=${@}
}

list_set_no_top_offset () {
	_NO_TOP_OFFSET=true
}

list_set_page () {
	local KEY=${1}
	local PAGE=${2}
	local MAX_PAGES=${3}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	case ${KEY} in
		n) ((PAGE++));;
		p) ((PAGE--));;
		fp) PAGE=1;;
		lp) PAGE=${MAX_PAGES};;
	esac

	[[ ${PAGE} -lt 1 ]] && PAGE=${MAX_PAGES}
	[[ ${PAGE} -gt ${MAX_PAGES} ]] && PAGE=1

	echo ${PAGE}
}

list_set_page_hold () {
	_HOLD_PAGE=true
}

list_set_prompt () {
	[[ -n ${1} ]] && _LIST_PROMPT=${@}
}

list_set_selectable () {
	_SELECTABLE=${1}
}

list_set_select_callback () {
	_SELECT_CALLBACK_FUNC=${1}
}

list_set_selected () {
	local -i ROW=${1}
	local -i VAL=${2}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	_LIST_SELECTED[${ROW}]=${VAL}
}

list_set_selection_limit () {
	_SELECTION_LIMIT=${1}
}

list_set_sortable () {
	_LIST_IS_SORTABLE=${1}
}

list_set_sort_cols () {
	_LIST_SORT_COLS=${1}
}

list_set_sort_engine () {
	_LIST_SORT_ENGINE=${1}
}

list_show_key () {
	local KEY=${@}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ${KEY} == '-' ]] && echo -n - '-' >&2 && return #show dash and return
	echo -n ${KEY} >&2 #show key value
}

list_sort () {
	local COLS
	local FIELDS
	local SORT_COL
	
	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ${_LIST_IS_SORTABLE} == 'false' ]] && return 1

	COLS=$(echo ${_LIST[1]} | grep -o "${_LIST_DELIM}" | wc -l)
	FIELDS=$((++COLS))

	msg_box -p "Enter column to sort:|(1 through ${FIELDS})"
	SORT_COL=${_MSG_KEY}

	[[ -z ${_LIST_SORT_DIR[${SORT_COL}]} ]] && _LIST_SORT_DIR[${SORT_COL}]="a" #first time
	[[ ${_LIST_SORT_DIR[${SORT_COL}]} == "a" ]] && _LIST_SORT_DIR[${SORT_COL}]="d" || _LIST_SORT_DIR[${SORT_COL}]="a" #a=asc,d=desc

	if validate_is_integer ${SORT_COL};then
		if [[ ${SORT_COL} -ge 1 && ${SORT_COL} -le ${FIELDS} ]];then
			_LIST=("${(f)$(arr_sort ${_LIST_DELIM} ${SORT_COL} ${_LIST_SORT_DIR[${SORT_COL}]} _LIST)}") #reverse sort default
		fi
	fi
}

list_sort_assoc () {
	local ARRAY
	local -a SLIST
	local SORT_COL
	local S

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	msg_box -p "Enter column to sort:|(1 through ${_LIST_SORT_COLS})"
	SORT_COL=${_MSG_KEY}

	validate_is_integer ${SORT_COL}
	if [[ ${?} -ne 0 || ${SORT_COL} -lt 1 || ${SORT_COL} -gt ${_LIST_SORT_COLS} ]];then
		msg_box -p -PK "Enter only integer: 1 through ${_LIST_SORT_COLS}"
		return 1 #bounce
	fi

	ARRAY=${_SORT_TABLE[${SORT_COL}]}
	[[ -z ${ARRAY} ]] && msg_box -p -PP "_SORT_TABLE did not return a valid array name" && return 1 #bounce

	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:ARRAY from _SORT_TABLE:${ARRAY}"

	[[ -z ${_LIST_SORT_DIR[${SORT_COL}]} ]] && _LIST_SORT_DIR[${SORT_COL}]="d" #first time
	[[ ${_LIST_SORT_DIR[${SORT_COL}]} == "a" ]] && _LIST_SORT_DIR[${SORT_COL}]="d" || _LIST_SORT_DIR[${SORT_COL}]="a" #a=asc,d=desc

	if [[ ${_LIST_SORT_DIR[${SORT_COL}]} == "a" ]];then
		_LIST=("${(f)$(
			for S in ${(k)${(P)ARRAY}};do
				echo "${S}|${${(P)ARRAY}[${S}]}"
			done | sort -t'|' -k2n | cut -d'|' -f1
		)}")
	else
		_LIST=("${(f)$(
			for S in ${(k)${(P)ARRAY}};do
				echo "${S}|${${(P)ARRAY}[${S}]}"
			done | sort -r -t'|' -k2n | cut -d'|' -f1
		)}")
	fi
}

list_toggle_all () {
	local ARRAY_NDX=${1}
	local TOP_OFFSET=${2}
	local MAX_DISPLAY_ROWS=${3}
	local MAX_ITEM=${4}
	local PAGE=${5}
	local CLEAR=${6} 
	local FIRST_ITEM=$((((PAGE*MAX_DISPLAY_ROWS)-MAX_DISPLAY_ROWS)+1))
	local LAST_ITEM=$((PAGE*MAX_DISPLAY_ROWS))
	local -a SELECTED
	local CURSOR_NDX=1
	local S R
	local OUT
	local HIGHLIGHTING=false
	local SCOPE

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ${LAST_ITEM} -gt ${MAX_ITEM} ]] && LAST_ITEM=${MAX_ITEM} #partial page

	[[ ${_LIST_ALL_SCOPE} == 'page' ]] && SCOPE=${LAST_ITEM} || SCOPE=${MAX_ITEM}

	SELECTED=($(list_mark_all ${FIRST_ITEM} ${SCOPE})) #all on page or list depending on scope set by caller

	if [[ ${CLEAR} == 'auto' ]];then
		[[ ${_LIST_TOGGLE_STATE} == 'on' ]] && _LIST_TOGGLE_STATE=off || _LIST_TOGGLE_STATE=on
	else
		_LIST_TOGGLE_STATE=off
	fi

	for S in ${SELECTED};do
		[[ ${_LIST_TOGGLE_STATE} == 'on' ]] && _LIST_SELECTED[${S}]=1 || _LIST_SELECTED[${S}]=0
	done

	[[ ${_HEADER_CALLBACK_FUNC} != '?' ]] && ${_HEADER_CALLBACK_FUNC} 0 all${_LIST_TOGGLE_STATE}


	tp cup ${TOP_OFFSET} 0
	for ((R=0; R<${MAX_DISPLAY_ROWS}; R++));do
		tp cup $((TOP_OFFSET+CURSOR_NDX-1)) 0
		if [[ ${ARRAY_NDX} -le ${MAX_ITEM} ]];then
			OUT=${ARRAY_NDX}

			BARLINE=$((ARRAY_NDX % 2)) #barlining 
			[[ ${BARLINE} -ne 0 ]] && BAR=${BLACK_BG} || BAR="" #barlining

			if [[ ${_LIST_SELECTED[${OUT}]} -eq 1 ]];then
				_SELECT_ALL=true
				SHADE=${REVERSE}
			else
				_SELECT_ALL=false
				SHADE=''
			fi

			eval ${_LIST_LINE_ITEM} #Output the line
		else
			printf "\n" #Output filler
		fi
		((ARRAY_NDX++))
		((CURSOR_NDX++))
	done

	list_do_header ${PAGE} ${MAX_PAGES}
}

list_toggle_selected () {
	local ROW_NDX=${1}
	local LIMIT=${2}
	local COUNT=$(list_get_selected_count)

	if [[ ${_SELECT_CALLBACK_FUNC} != '?' ]];then
		${_SELECT_CALLBACK_FUNC} ${ROW_NDX}
		[[ ${?} -ne 0 ]] && return
	fi

	[[ ${_DEBUG} -gt 1 ]] && dbg "${0}:ROW_NDX:${ROW_NDX} LIMIT:${LIMIT} _CLEAR_GHOSTS:${_CLEAR_GHOSTS} _SELECTION_LIMIT:${_SELECTION_LIMIT}"

	[[ ${_CLEAR_GHOSTS} == 'false' && ${_LIST_SELECTED[${ROW_NDX}]} -ge ${_GHOST_ROW} ]] && return #ignore ghosts

	if [[ ${_LIST_SELECTED[${ROW_NDX}]} -ne 1 ]];then
		if [[ ${_SELECTION_LIMIT} -ne 0 && ${COUNT} -gt ${LIMIT} ]];then
			msg_box -p -PK "Selection is limited to ${_SELECTION_LIMIT}"
			msg_box_clear
			return #ignore over limit
		fi
		list_set_selected ${ROW_NDX} 1 
		[[ ${_HEADER_CALLBACK_FUNC} != '?' ]] && ${_HEADER_CALLBACK_FUNC} ${ROW_NDX} on
	else
		list_set_selected ${ROW_NDX} 0
		[[ ${_HEADER_CALLBACK_FUNC} != '?' ]] && ${_HEADER_CALLBACK_FUNC} ${ROW_NDX} off
	fi

	list_do_header ${PAGE} ${MAX_PAGES}
}

list_validate_selection () {
	local -a KEYLIST
	local -A OPTION
	local -a R1
	local -a R2
	local -a SELECTED
	local -a NDX_RANGE
	local K X MSG
	local RC

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ${1} == '-r' ]] && OPTION[no_range_check]=1 && shift

	KEYLIST=(${@})
	KEYLIST=("${(f)$(echo ${KEYLIST} | grep -o .)}")
	KEYLIST=$(list_parse_series ${KEYLIST})

	R1=()
	R2=()
	SELECTED=()
	for K in ${=KEYLIST};do
		if [[ ${K[1,1]} =~ "[BE]" ]];then
			case ${K[1,1]} in
				B) R1+=${K[2,${#K}]};continue;;
				E) R2+=${K[2,${#K}]};continue;;
			esac
		fi
		SELECTED+=${K} #non range element
	done

	#handle range elements
	if [[ -n ${R1} ]];then
		for ((X=1;X<=${#R1};X++));do
			SELECTED+=$(echo {${R1[${X}]}..${R2[${X}]}})
		done
	fi

	RC=0
	if [[ ${OPTION[no_range_check]} -ne 1 ]];then
		NDX_RANGE=($(list_get_index_range))
		MSG=$(list_is_valid_selection ${NDX_RANGE[1]} ${NDX_RANGE[-1]} ${SELECTED})
		RC=$?
	fi

	if [[ ${RC} -eq 0 ]];then
		echo ${(on)SELECTED}

		return 0
	else
		echo "Invalid Selection"

		return 1
	fi
}

list_warn_invisible_rows () {
	local MAX_DISPLAY_ROWS=${1}
	local PAGE=${2}
	local FIRST_ITEM=$((((PAGE*MAX_DISPLAY_ROWS)-MAX_DISPLAY_ROWS)+1))
	local LAST_ITEM=$((PAGE*MAX_DISPLAY_ROWS))
	local S

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ${LAST_ITEM} -gt ${MAX_ITEM} ]] && LAST_ITEM=${MAX_ITEM} #partial page

	#Warn user of marked rows not on current page
	for S in ${(k)_LIST_SELECTED};do
		if [[ ${S} -ge ${FIRST_ITEM} && ${S} -le ${LAST_ITEM}  ]];then
			continue 
		else
			[[ ${_LIST_SELECTED[${S}]} -eq 0 || ${_LIST_SELECTED[${S}]} -ge ${_GHOST_ROW} ]] && continue 
			msg_box -t1 "<B><I>Warning<N>: there are marked rows on other pages"
			break
		fi
	done
}

list_write_to_file () {
	local ALIST=(${@})
	local L

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	if [[ -n ${ALIST[1]} ]];then
		[[ -e ${_SCRIPT}.out ]] && rm -f ${_SCRIPT}.out
		msg_box -c -p "Writing ${#ALIST} list $(str_pluralize item) to file: ${_SCRIPT}.out|Press any key"
		for L in ${ALIST};do
			echo ${L} >> ${_SCRIPT}.out
		done
	else
		msg_box -c -p "List is empty - nothing to write|Press any key"
	fi
}

msg_box () {
	#Function internal VARS
	local -a MSGS=()
	local -a HDR=()
	local -a MTST
	local BOX_HEIGHT=0
	local BOX_WIDTH=0
	local BOX_X_COORD=0
	local BOX_Y_COORD=0
	local BREAK_POINT=0
	local MAX_X_COORD=$((_MAX_ROWS-5)) #not including frame 5 up from bottom, 4 with frame
	local MAX_Y_COORD=$((_MAX_COLS-10)) #not including frame 10 from sides, 9 with frame
	local MIN_X_COORD=$(( (_MAX_ROWS-MAX_X_COORD)-1 )) #=3 with frame
	local MIN_Y_COORD=$((_MAX_COLS-MAX_Y_COORD)) #=9 with frame
	local USABLE_COLS=$((MAX_Y_COORD-MIN_Y_COORD)) #horizontal space boundary
	local USABLE_ROWS=$((MAX_X_COORD-MIN_X_COORD)) #vertical space boundary
	local DELIM='|'
	local DELIM_ARG=?
	local DTL_NDX=0
	local FRAME
	local GAP=0
	local GAP_NDX=0
	local HAVE_TOKEN=false
	local IN_TOKEN=false
	local KEY
	local LAST_LINE
	local MAX_LINE_WIDTH=$((USABLE_COLS-20))
	local MSG_CLEAN
	local MSG_COLS=0
	local MSG_DELIMS=0
	local MSG_LEN=0
	local MSG_NDX=0
	local MSG_OUT
	local MSG_PAD_L=0
	local MSG_PAD_R=0
	local DISPLAY_ROWS=0
	local MSG_X_COORD=0
	local MSG_Y_COORD=0
	local NAV_BAR
	local OPTION
	local PADDED
	local PAGING=false
	local SCR_NDX=0
	local STYLE
	local TOKEN
	local X M K T

	#Function OPTIONS
	local -a MSG
	local CLEAR_MSG=false
	local DELIM_ARG=false
	local HEADER_LINES
	local IGNORE_MARKUP=false
	local INLINE_LIST=false
	local MSG_DEBUG=false
	local MSG_X_COORD_ARG=-1
	local MSG_Y_COORD_ARG=-1
	local PROMPT_USER=false
	local PROMPT_TEXT=''
	local SO=false
	local TEXT_STYLE=c
	local TIMEOUT=0

	local OPTSTR=":DH:P:cinprj:s:t:x:y:"
	OPTIND=0

	while getopts ${OPTSTR} OPTION;do
		case ${OPTION} in
			D) MSG_DEBUG=true;;
			H) HEADER_LINES=${OPTARG};;
			c) CLEAR_MSG=true;;
			i) IGNORE_MARKUP=true;;
			j) TEXT_STYLE=${OPTARG};;
			p) PROMPT_USER=true;;
			P) PROMPT_TEXT=${OPTARG};;
			r) SO=true;;
			s) DELIM_ARG="${OPTARG}";;
			t) TIMEOUT="${OPTARG}";;
			x) MSG_X_COORD_ARG=${OPTARG};;
			y) MSG_Y_COORD_ARG=${OPTARG};;
			:) print -u2 " ${_SCRIPT}: option: -${OPTARG} requires an argument" >&2;read ;;
			\?) print -u2 " ${_SCRIPT}: unknown option -${OPTARG}" >&2; read;;
		esac
	done
	shift $((OPTIND -1))

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	MSG=(${@}) #MSG ARGS
	[[ -z ${MSG} ]] && return #abort if no msg

	MSG_LEN=${*}
	if [[ ${#MSG_LEN} -gt 250 ]];then
		local -a PROC_MSG_BOX=(18 80 20 3)
		msg_unicode_box ${PROC_MSG_BOX}
		tp cup $((PROC_MSG_BOX[1]+1)) $((PROC_MSG_BOX[2]+3))
		echo "${GREEN_FG}${ITALIC}${BOLD}Processing...${RESET}"
	fi

	MSG=$(echo ${MSG} | str_strip_ansi) #Clean any ansi

	if [[ -n ${PROMPT_TEXT} ]];then
		case ${PROMPT_TEXT} in
			A) MSG+="| |<w>Proceed or All (a=bypass prompts)? (a/y/n)<N>";;
			C) MSG+="| |<w>Continue? (y/n)<N>";;
			D) MSG+="| |<w>Download? (y/n)<N>";;
			E) MSG+="| |<w>Edit? (y/n)<N>";;
			P) MSG+="| |<w>Proceed? (y/n)<N>";;
			I) MSG+="| |<w>Install? (y/n)<N>";;
			O) MSG+="| |<w>Open? (y/n)<N>";;
			K) MSG+="| |<w>Press any key...<N>";;
			Q) MSG+="| |<w>Queue? (y/n)<N>";;
			R) MSG+="| |<w>Press any key or Esc to exit<N>";;
			V) MSG+="| |<w>View? (y/n)<N>";;
			W) MSG+="| |<w>Overwrite? (y/n)<N>";;
			X) MSG+="| |<w>Cancel? (y/n)<N>";;
			Y) MSG+="| |<w>Correct? (y/n)<N>";;
			*) MSG+="| |<w>${PROMPT_TEXT}<N>";;
		esac
		[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:ADDED 2 LINES FOR PROMPT:${MSG[-$((${#PROMPT_TEXT}+9)),-1]}"
	fi

	#Assignments
	[[ ${DELIM_ARG} != 'false' ]] && DELIM=${DELIM_ARG}
	MSG_DELIMS=$(echo ${MSG} | grep --color=never -o "[${DELIM}]" | wc -l) #Msg content sections by ${DELIM}

	[[ ${CLEAR_MSG} == 'true' ]] && msg_box_clear #clear last msg ?

	#Parse MSG delimiters
	DISPLAY_ROWS=0
	for (( X=1; X <= $((${MSG_DELIMS}+1)); X++ ));do
		MTST=$(cut -d"${DELIM}" -f${X} <<<${MSG})
		if [[ ${#MTST} -gt ${MAX_LINE_WIDTH} ]];then
			MTST=("${(f)$(fold -s -w${MAX_LINE_WIDTH} <<<${MTST})}")
			for T in ${MTST};do
				MSGS+=${T}
				((DISPLAY_ROWS++))
			done
		else
			MSGS+=${MTST}
			((DISPLAY_ROWS++))
		fi
		[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:ADDING MSG:${DISPLAY_ROWS} ${MSGS[${DISPLAY_ROWS}]}"
	done

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:TOTAL MSG ROWS:${#MSGS}"

	[[ ${DISPLAY_ROWS} -gt ${USABLE_ROWS} ]] && DISPLAY_ROWS=${USABLE_ROWS} #Maximum displayable lines

	MSG_COLS=$(str_longest_len ${MSGS})
	((MSG_COLS+=2))

	if [[ ${_DEBUG} -gt 2 ]];then
		dbg "${0}:TEXT_STYLE:${WHITE_FG}${TEXT_STYLE}${RESET}"
		dbg "${0}:MAX ROWS:${WHITE_FG}${_MAX_ROWS}${RESET} MAX COLS:${WHITE_FG}${_MAX_COLS}${RESET}"
		dbg "${0}:USABLE_ROWS:${WHITE_FG}${USABLE_ROWS}${RESET} USABLE_COLS:${WHITE_FG}${USABLE_COLS}${RESET}"
		dbg "${0}:MIN_X_COORD:${WHITE_FG}${MIN_X_COORD}${RESET} MAX_X_COORD:${WHITE_FG}${MAX_X_COORD}${RESET}"
		dbg "${0}:MIN_Y_COORD:${WHITE_FG}${MIN_Y_COORD}${RESET} MAX_Y_COORD:${WHITE_FG}${MAX_Y_COORD}${RESET}"
		dbg "${0}:DISPLAY_ROWS:${WHITE_FG}${DISPLAY_ROWS}${RESET} MSG_COLS:${WHITE_FG}${MSG_COLS}${RESET}"
	fi

	#Center msg unless coords were passed
	[[ ${MSG_X_COORD_ARG} -eq -1 ]] && MSG_X_COORD=$(( ( _MAX_ROWS-(DISPLAY_ROWS+2) )/2 )) || MSG_X_COORD=${MSG_X_COORD_ARG}
	[[ ${MSG_Y_COORD_ARG} -eq -1 ]] && MSG_Y_COORD=$(( (_MAX_COLS/2)-(MSG_COLS/2) )) || MSG_Y_COORD=${MSG_Y_COORD_ARG}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:CENTER: MSG_X_COORD:${WHITE_FG}${MSG_X_COORD}${RESET} MSG_Y_COORD:${WHITE_FG}${MSG_Y_COORD}${RESET}"

	#Sane coords - catch overruns
	[[ ${MSG_X_COORD} -lt ${MIN_X_COORD} ]] && MSG_X_COORD=${MIN_X_COORD}
	[[ ${MSG_X_COORD} -gt ${USABLE_ROWS} ]] && MSG_X_COORD=${USABLE_ROWS}
	[[ ${MSG_Y_COORD} -lt ${MIN_Y_COORD} ]] && MSG_Y_COORD=${MIN_Y_COORD}
	[[ ${MSG_Y_COORD} -gt ${USABLE_COLS} ]] && MSG_Y_COORD=${USABLE_COLS}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:SANE: MSG_X_COORD:${WHITE_FG}${MSG_X_COORD}${RESET} MSG_Y_COORD:${WHITE_FG}${MSG_Y_COORD}${RESET}"

	#Set box coords
	BOX_X_COORD=$((MSG_X_COORD-1))
	BOX_Y_COORD=$((MSG_Y_COORD-1))
	BOX_WIDTH=$((MSG_COLS+4)) # 1 char gutter per side
	BOX_HEIGHT=$((DISPLAY_ROWS+2))

	if [[ ${_DEBUG} -gt 2 ]];then
		dbg "${0}: BOX_X_COORD:${WHITE_FG}${BOX_X_COORD}${RESET} BOX_Y_COORD:${WHITE_FG}${BOX_Y_COORD}${RESET}"
		dbg "${0}: BOX_HEIGHT:${WHITE_FG}${BOX_HEIGHT}${RESET} BOX_WIDTH:${WHITE_FG}${BOX_WIDTH}${RESET}"
	fi

	#Save box coordinates
	_MSG_BOX_COORDS=(X ${BOX_X_COORD} Y ${BOX_Y_COORD} H ${BOX_HEIGHT} W ${BOX_WIDTH})

	#Prepare
	tp cup ${_MAX_ROWS} ${_MAX_COLS} #Place cursor at bottom right of display
	tp civis #Hide cursor

	[[ ${SO} == 'true' ]] && tp smso #Standout mode

	#Clear processing msg box
	if [[ ${#MSG_LEN} -gt 250 ]];then
		tp cup $((PROC_MSG_BOX[1]+1)) $((PROC_MSG_BOX[2]+3));tp ech ${PROC_MSG_BOX[3]}
		tp cup $((PROC_MSG_BOX[1]+2)) $((PROC_MSG_BOX[2]+3));tp ech ${PROC_MSG_BOX[3]}
		tp cup $((PROC_MSG_BOX[1]+3)) $((PROC_MSG_BOX[2]+3));tp ech ${PROC_MSG_BOX[3]}
	fi

	#Check for paging and add nav,reset width if needed
	if [[ ${#MSGS} -gt $((DISPLAY_ROWS)) ]];then
		[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${RED_FG}MESSAGE PAGING PREDICTED; ADDING NAV BAR AND EXANDING WIDTH IF NEEDED${RESET}"
		NAV_BAR="<c>Navigation keys<N>: (<w>t<N>,<w>h<N>=top <w>b<N>,<w>l<N>=bottom <w>u<N>,<w>k<N>=up <w>d<N>,<w>j<N>=down)"
		MSGS=("${NAV_BAR}" ${MSGS[@]})
		[[ ${BOX_WIDTH} -lt 60 ]] && BOX_WIDTH=60 #wide enough to display nav
		_MSG_BOX_COORDS=(X ${BOX_X_COORD} Y ${BOX_Y_COORD} H ${BOX_HEIGHT} W ${BOX_WIDTH})
		[[ ${_DEBUG} -gt 2 ]] && dbg "${0}: _MSG_BOX_COORDS: ${(kv)_MSG_BOX_COORDS}"
	fi

	#Generate box
	msg_unicode_box ${BOX_X_COORD} ${BOX_Y_COORD} ${BOX_WIDTH} ${BOX_HEIGHT}

	[[ ${HEADER_LINES} -ne 0 ]] && HDR=(${MSGS[1,${HEADER_LINES}]})

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:MSGS:${WHITE_FG}${#MSGS}${RESET} DISPLAY_ROWS:${WHITE_FG}${DISPLAY_ROWS}${RESET}"

	#Handle last page gap
	if [[ ${#MSGS} -gt $((DISPLAY_ROWS)) ]];then
		PAGING=true
		[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${RED_FG}MESSAGE PAGING TRIGGERED${RESET}"
		((HEADER_LINES++))

		LAST_LINE=${MSGS[-1]} #save the last line
		MSGS[-1]=" " #erase last line

		GAP=$(msg_calc_gap ${#MSGS} ${DISPLAY_ROWS} ${HEADER_LINES})
		
		[[ ${_DEBUG} -gt 2 ]] && dbg "${0}: HEADER_LINES:${WHITE_FG}${HEADER_LINES}${RESET} PARTIAL:${WHITE_FG}$((DISPLAY_ROWS-GAP))${RESET} GAP:${WHITE_FG}${GAP}${RESET}"
		[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:BEFORE GAP FILL: MSGS:${#MSGS}"

		#Pad messages to break evenly across pages
		for ((GAP_NDX=1;GAP_NDX<=${GAP};GAP_NDX++));do
			MSGS+=" "
		done

		MSGS[-1]=${LAST_LINE} #move the last line to the bottom

		[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:AFTER GAP FILL: MSGS:${#MSGS}"
	else
		PAGING=false
	fi

	#Output msg lines
	BREAK_POINT=${DISPLAY_ROWS}

	SCR_NDX=${BOX_X_COORD} 
	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:START: SCR_NDX:${WHITE_FG}${SCR_NDX}${RESET}"

	DTL_NDX=0

	for ((MSG_NDX=1;MSG_NDX<=${#MSGS};MSG_NDX++));do
		((SCR_NDX++))
		((DTL_NDX++))

		#List,Left,Center,Normal
		if [[ ${MSGS[${MSG_NDX}]} =~ '<L>' ]];then #list?
			MSG_OUT=$(sed 's/<L>/\\u2022 /g' <<<${MSGS[${MSG_NDX}]})
			MSG_OUT=$(str_trim ${MSG_OUT})
			MSG_PAD_L=' '
			MSG_PAD_R=$(str_rep_char ' ' $(( BOX_WIDTH-(${#MSG_PAD_L}+${#MSG_OUT})-3 )) )
		elif [[ ${TEXT_STYLE} == 'l' ]];then #left
			MSG_OUT=$(str_trim ${MSGS[${MSG_NDX}]})
			MSG_PAD_L=' '
			MSG_PAD_R=$(str_rep_char ' ' $(( BOX_WIDTH-(${#MSG_PAD_L}+${#MSG_OUT})-3 )) )
		elif [[ ${TEXT_STYLE} == 'c' ]];then #center
			MSG_OUT=$(str_trim ${MSGS[${MSG_NDX}]})
			MSG_PAD_L=$(str_center_pad $((BOX_WIDTH-2)) $(msg_nomarkup ${MSG_OUT}))
			MSG_PAD_R=$(str_rep_char ' ' $(( ${#MSG_PAD_L}-1 )) )
		elif [[ ${TEXT_STYLE} == 'n' ]];then #normal
			MSG_OUT=${MSGS[${MSG_NDX}]}
			MSG_PAD_L=' '
			MSG_PAD_R=$(str_rep_char ' ' $(( BOX_WIDTH-(${#MSG_PAD_L}+${#MSG_OUT})-3 )) )
		fi

		tp cup ${SCR_NDX} ${MSG_Y_COORD} #Place cursor
		tp ech ${MSG_COLS} #Clear line
		echo -n "${MSG_PAD_L}$(msg_markup ${MSG_OUT})${MSG_PAD_R}" #apply padding to both sides of msg

		[[ ${_DEBUG} -ge 1 ]] && dbg "${0}:MSG_OUT:${MSG_OUT}, LEN:${#MSG_OUT}"
		[[ ${_DEBUG} -ge 1 ]] && dbg "${0}:MARKUP:$(msg_markup ${MSG_OUT}), LEN:${#$(msg_markup ${MSG_OUT})}"
		[[ ${_DEBUG} -ge 1 ]] && dbg "${0}:NOMARKUP:$(msg_nomarkup ${MSG_OUT}), LEN:${#$(msg_nomarkup ${MSG_OUT})}"
		[[ ${_DEBUG} -ge 1 ]] && dbg "${0}:MSG_OUT_L:[${MSG_PAD_L}], LEN:${#MSG_PAD_L}"
		[[ ${_DEBUG} -ge 1 ]] && dbg "${0}:MSG_OUT_R:[${MSG_PAD_R}], LEN:${#MSG_PAD_R}"
		[[ ${_DEBUG} -ge 1 ]] && dbg "${0}:BOX_WIDTH:${BOX_WIDTH}"
		 
		[[ ${SO} == 'true' ]] && tp smso

		if [[ $((DTL_NDX % BREAK_POINT)) -eq 0 ]];then
			if [[ ${PROMPT_USER} == "true" ]];then
				[[ ${XDG_SESSION_TYPE:l} == 'x11' ]] && eval "xset ${_XSET_LOW_RATE}"
				read -sk1 KEY
				case ${KEY:l} in
					[a-z]) K=${KEY:l};;
					[0-9]) K=${KEY};;
					*) [[ $(xxd -p <<<${KEY}) == '1b0a' ]] && K=esc;;
				esac 
				[[ ${XDG_SESSION_TYPE:l} == 'x11' ]] && eval "xset ${_XSET_DEFAULT_RATE}"
				_MSG_KEY=${K} #set global key
				if [[ ${PAGING} == 'true' ]];then
					[[ ${_MSG_KEY} == 'esc' ]] && break #exit msg window
					MSG_NDX=$(msg_paging ${KEY} ${MSG_NDX} ${#MSGS} ${DISPLAY_ROWS} ${HEADER_LINES})
				fi
				[[ -z ${_MSG_KEY} ]] && _MSG_KEY=n #default to no
			fi
			DTL_NDX=0
			BREAK_POINT=$((DISPLAY_ROWS-HEADER_LINES))
			SCR_NDX=$((BOX_X_COORD+HEADER_LINES))
			[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:PAGE_TOP: MSG_NDX:$((MSG_NDX-BREAK_POINT))"
		fi
	done

	[[ ${TIMEOUT} -gt 0 ]] && sleep ${TIMEOUT} && msg_box_clear

	[[ ${SO} == 'true' ]] && tp rmso #kill standout

	tp rc #Restore cursor position
	tp cup ${_MAX_ROWS} ${_MAX_COLS}
	tp cnorm #Restore cursor
}

msg_box_clear () {
	local BOX_X_COORD=${_MSG_BOX_COORDS[X]}
	local BOX_Y_COORD=${_MSG_BOX_COORDS[Y]}
	local BOX_HEIGHT=${_MSG_BOX_COORDS[H]}
	local BOX_WIDTH=${_MSG_BOX_COORDS[W]}
	local X

	[[ ${_DEBUG} -gt 1 ]] && dbg "${0}: BOX_X_COORD:${BOX_X_COORD}  BOX_Y_COORD:${BOX_Y_COORD} BOX_HEIGHT:${BOX_HEIGHT} BOX_WIDTH:${BOX_WIDTH}"

	[[ ${BOX_HEIGHT} -eq 0 ]] && return #ignore

	for ((X=BOX_X_COORD; X<=BOX_X_COORD+BOX_HEIGHT-1; X++));do
		tp cup ${X} ${BOX_Y_COORD}
		tp ech ${BOX_WIDTH}
	done
}

msg_calc_gap () {
	local LIST_ROWS=${1}
	local DISPLAY_ROWS=${2}
	local DETAIL_LINES=0
	local TL_PAGES=0
	local PARTIAL
	local GAP=0
	local NEED

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}: LIST_ROWS:${LIST_ROWS} DISPLAY_ROWS:${DISPLAY_ROWS} HEADER_LINES:${HEADER_LINES}"

	DETAIL_LINES=$((DISPLAY_ROWS-HEADER_LINES))
	TL_PAGES=$((LIST_ROWS/DISPLAY_ROWS))
	PARTIAL=$((LIST_ROWS % DETAIL_LINES))
	[[ ${PARTIAL} -ne 0 ]] && ((TL_PAGES++))

	NEED=$(( DISPLAY_ROWS + ( (TL_PAGES-1) * DETAIL_LINES ) ))

	[[ ${NEED} < ${LIST_ROWS} ]] && NEED=$((NEED+DETAIL_LINES)) #add another page

	GAP=$(( NEED-LIST_ROWS ))

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}: NEED:${NEED} DETAIL_LINES:${DETAIL_LINES} TL_PAGES:${TL_PAGES} PARTIAL:${PARTIAL} GAP:${GAP}"

	echo ${GAP}
}

msg_err () {
	local MSG=${@}

	if [[ -n ${MSG} ]];then
		[[ ${MSG} =~ ":" ]] && MSG=$(perl -p -e 's/:(\S+)\s/\e[m:\e[3;37m$1\e[m/g' <<<${MSG})
		echo "\\\n[${BOLD}${RED_FG}ERR${RESET}] ${MSG}\\\n"
	fi
}

msg_list () {
	local -a MSG=(${@})
	local L
	local DELIM='|'
	local NDX=0

	[[ ${_DEBUG} -gt 3 ]] && dbg "${0}:MSG COUNT:${#MSG}"

	for L in ${MSG};do
		((NDX++))
		echo -n "<L>${L}"
		[[ ${NDX} -lt ${#MSG} ]] && echo ${DELIM}
		[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${NDX}:<L>${L}"
	done

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:Generated ${NDX} lines"
}

msg_markup () {
	local MSG=${@}

	[[ ${_DEBUG} -gt 3 ]] && dbg "${0}:${@}"

	#Apply markup and print
	perl -pe 'BEGIN { 
	%ES=(
	"B"=>"[1m",
	"I"=>"[3m",
	"N"=>"[m",
	"O"=>"[9m",
	"R"=>"[7m",
	"U"=>"[4m",
	"b"=>"[34m",
	"c"=>"[36m",
	"g"=>"[32m",
	"m"=>"[35m",
	"r"=>"[31m",
	"u"=>"[4m",
	"w"=>"[37m",
	"y"=>"[33m"
	) }; 
	{ s/<([BINORSUrugybmcw])>/\e$ES{$1}/g; }' <<<${MSG}
}

msg_nomarkup () {
	local MSG=${@}
	local MSG_OUT

	MSG_OUT=$(perl -pe 's/(<B>|<I>|<L>|<N>|<O>|<R>|<U>|<b>|<c>|<g>|<m>|<r>|<w>|<y>)//g' <<<${MSG})

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}: MSG_OUT:\"${MSG_OUT}\""

	echo ${MSG_OUT}
}

msg_paging () {
	local KEY=${1}
	local NDX=${2}
	local LIST_ROWS=${3}
	local DISPLAY_ROWS=${4}
	local HEADER_LINES=${5}
	local DETAIL_LINES
	local TL_PAGES=0
	local PARTIAL

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}: NDX:${NDX}"

	DETAIL_LINES=$((DISPLAY_ROWS-HEADER_LINES))

	TL_PAGES=$((LIST_ROWS/DISPLAY_ROWS))
	PARTIAL=$((LIST_ROWS % DETAIL_LINES))
	[[ ${PARTIAL} -ne 0 ]] && ((TL_PAGES++))

	case ${KEY} in
		t|h) echo $((HEADER_LINES));; #top
		b|l) echo $(( ((TL_PAGES-1) * DETAIL_LINES) + HEADER_LINES));; #bottom
		u|k) [[ $((NDX-(DETAIL_LINES*2))) -lt ${HEADER_LINES} ]] && echo ${HEADER_LINES} || echo $((NDX-(DETAIL_LINES*2)));; #page up
		d|j) echo ${NDX};; #page down (default)
		*) echo ${NDX};;
	esac
}

msg_stream () {
	local -a CMD
	local -a MSG_LINES
	local DELIM='|'
	local TEXT_STYLE=l
	local FOLD_WIDTH=120
	local FOLD
	local MSG
	local LINE_CNT
	local PAD
	local NDX

	local OPTION
	local OPTSTR=":f:lcn"
	OPTIND=0

	while getopts ${OPTSTR} OPTION;do
		case ${OPTION} in
			f) FOLD_WIDTH=${OPTARG};;
			l) TEXT_STYLE=l;;
			c) TEXT_STYLE=c;;
			n) TEXT_STYLE=n;;
			:) print -u2 " ${_SCRIPT}: option: -${OPTARG} requires an argument" >&2;read ;;
			\?) print -u2 " ${_SCRIPT}: unknown option -${OPTARG}" >&2; read;;
		esac
	done
	shift $((OPTIND -1))

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	FOLD="| fold -s -w ${FOLD_WIDTH}"

	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:OPTIONS:FOLD:${FOLD} TEXT_STYLE:${TEXT_STYLE}"

	CMD=(${@})
	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:CMD:${CMD}"

	#convert carriage returns to newlines and any '<' to similar unicode to avoid collision with markup
	coproc { eval "${CMD} ${FOLD}" | sed -e "s//\n/g" -e 's/</\xe2\x98\x87/g'; } 

	LINE_CNT=0
	while read -p ${COPROC[0]} MSG;do
		[[ ${_DEBUG} -gt 1 ]] && dbg "${0}:COPROC READ MSG:${LINE_CNT}: [${MSG}] $(xxd <<<${MSG})"
		MSG_LINES+="<w>${MSG}<N>${DELIM}"
		((LINE_CNT++))
	done
	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:TOTAL MSGS FROM COPROC:${LINE_CNT}"

	while true;do
		[[ ${MSG_LINES[-1]} == "<w><N>|" ]] && MSG_LINES[-1]=() || break
	done

	MSG_LINES[-1]=$(sed 's/|//g' <<< ${MSG_LINES[-1]}) #remove DELIM on last line

	[[ -z ${#MSG_LINES[1]} || ${MSG_LINES[1]:l} =~ 'unable to locate' ]] && return
	
	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:MSG COUNT with BLANK LINES REMOVED:${#MSG_LINES}"

	msg_box -H0 -P"Last Page" -pc -s${DELIM} -j${TEXT_STYLE} ${MSG_LINES} #display window
}

msg_unicode_box () {
	local BOX_X_COORD=${1}
	local BOX_Y_COORD=${2}
	local BOX_WIDTH=${3}
	local BOX_HEIGHT=${4}
	local TOP_LEFT 
	local TOP_RIGHT
	local BOT_LEFT 
	local BOT_RIGHT
	local LEFT_SIDE
	local RIGHT_SIDE
	local HORIZ_BAR 
	local VERT_BAR
	local HEAVY
	local X Y

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	HEAVY=false
	[[ ${1} == '-h' ]] && HEAVY=true && shift

	if [[ ${HEAVY} == 'false' ]];then
		BOT_LEFT="\\u2514%.0s"
		BOT_RIGHT="\\u2518%.0s"
		HORIZ_BAR="\\u2500%.0s"
		TOP_LEFT="\\u250C%.0s"
		TOP_RIGHT="\\u2510%.0s"
		VERT_BAR="\\u2502%.0s"
	else
		BOT_LEFT="\\u2517%.0s"
		BOT_RIGHT="\\u251B%.0s"
		HORIZ_BAR="\\u2501%.0s"
		TOP_LEFT="\\u250F%.0s"
		TOP_RIGHT="\\u2513%.0s"
		VERT_BAR="\\u2503%.0s"
	fi

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:TOP LEFT: BOX_X_COORD:${BOX_X_COORD} BOX_Y_COORD:${BOX_Y_COORD}"

	#top left corner
	tp cup ${BOX_X_COORD} ${BOX_Y_COORD}
	printf ${TOP_LEFT}

	#top border
	for (( Y=BOX_Y_COORD+1; Y<=BOX_Y_COORD+BOX_WIDTH-2; Y++ ));do
		tp cup ${BOX_X_COORD} ${Y}
		printf ${HORIZ_BAR}
	done

	#top rightcorner
	printf ${TOP_RIGHT}

	#sides
	for (( X=BOX_X_COORD+1; X<=BOX_X_COORD+BOX_HEIGHT-2; X++ ));do
		tp cup ${X} ${BOX_Y_COORD}
		printf ${VERT_BAR}
		tp ech ${BOX_WIDTH} #clear box area
		tp cup ${X} $((BOX_Y_COORD+1+BOX_WIDTH-2))
		printf ${VERT_BAR}
	done

	#bottom left corner
	tp cup ${X} ${BOX_Y_COORD}
	printf ${BOT_LEFT}

	#bottom border
	for (( Y=BOX_Y_COORD+1; Y<=BOX_Y_COORD+BOX_WIDTH-2; Y++ ));do
		tp cup ${X} ${Y}
		printf ${HORIZ_BAR}
	done

	#bottom right corner
	tp cup ${X} ${Y}
	printf ${BOT_RIGHT}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:BOTTOM RIGHT: BOX_X_COORD:${X} BOX_Y_COORD:${Y}"
	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:BOX DIMENSIONS:$((X-BOX_X_COORD+1)) x $((Y-BOX_Y_COORD+1))"
}

msg_info () {
	local MSG=${@}

	if [[ -n ${MSG} ]];then
		[[ ${MSG} =~ ":" ]] && MSG=$(perl -p -e 's/:(\w+)/\e[m:\e[3;37m$1\e[m/g' <<<${MSG})
		echo "\\\n[${_SCRIPT}]:${BOLD}${CYAN_FG}${MSG}${RESET}\\\n"
	fi
}

msg_warn () {
	local MSG=${@}

	if [[ -n ${MSG} ]];then
		[[ ${MSG} =~ ":" ]] && MSG=$(perl -p -e 's/:(\w+)/\e[m:\e[3;37m$1\e[m/g' <<<${MSG})
		echo "\\\n[${_SCRIPT}]:${BOLD}${RED_FG}${MSG}${RESET}\\\n"
	fi
}

num_byte_conv () {
	local BYTES=${1}
	local WANTED=${2}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	case ${WANTED} in
		KB) echo $((${BYTES} / 1024 ));;
		MB) echo $((${BYTES} / 1024^2 ));;
		GB) echo $((${BYTES} / 1024^3 ));;
	esac
}

num_human () {
	local BYTES=${1}
	local GIG_D=1073741824
	local MEG_D=1048576
	local KIL_D=1024

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	(
	if [[ ${BYTES} -gt ${GIG_D} ]];then printf "%10.2fGB" $((${BYTES}.0/${GIG_D}.0))
	elif [[ ${BYTES} -gt ${MEG_D} ]];then printf "%10.2fMB" $((${BYTES}.0/${MEG_D}.0))
	elif [[ ${BYTES} -gt ${KIL_D} ]];then printf "%10.2fKB" $((${BYTES}.0/${KIL_D}.0))
	else printf "%10dB" ${BYTES} 
	fi
	) | sed 's/^[ \t]*//g' 
}

parse_find_valid_delim () {
	local LINE=${1}
	local DELIM
	local D

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	for D in ${_DELIMS};do
		DELIM=''
		grep -q ${D} <<<${LINE}

		[[ $? -ne 0 ]] && DELIM=${D} && break #delim not in line
	done

	[[ -n ${DELIM} ]] && echo ${DELIM} && return 0
	return 1
}

parse_get_last_field () {
	local DELIM=${1};shift
	local LINE=${@}

	echo -n ${LINE} | rev | cut -d"${DELIM}" -f1 | rev
}

path_expand () {
	local ARG=${@}
	local ARG_TST
	local PATH_TST

	ARG_TST=${ARG}

	[[ ${ARG_TST} =~ '\*$' ]] && ARG_TST=${ARG_TST:h} #remove glob

	ARG_TST=$(eval "echo ${ARG_TST}")
	PATH_TST=$(realpath ${ARG_TST})

	[[ -f ${PATH_TST} ]] && echo ${PATH_TST:h} || echo ${PATH_TST} #if it points to a file return only the head
}

path_find_prep () {
	local FLIST
	local NDX=0
	local K
	local HIT=false

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	FLIST='\( '
	for K in ${(k)_ARGS};do
		((NDX++))
		if [[ ${K} =~ 'list' ]];then
			HIT=true
			[[ ${NDX} -eq 1 ]] && FLIST+="-inum ${_ARGS[${K}]} " || FLIST+=" -o -inum ${_ARGS[${K}]}"
		fi
	done
	FLIST+=' \)'

	if [[ ${HIT} == 'false' ]];then
		return 1
	else
		echo ${FLIST}
		return 0
	fi
}

path_get_inode () {
	local FN=${@}
	local INODE

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	INODE=$(ls -i ${FN:Q} 2>/dev/null | cut -d' ' -f1 2>/dev/null)

	if [[ -n ${INODE} ]];then 
		echo ${INODE}
		return 0
	else
		[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${RED_FG}Unable to obtain inode${RESET}"
		return 1
	fi
}

path_get_label () {
	local MAX_LEN=${1}
	local LABEL
	local TAIL
	local RAW_PATH
	local PATH_HEAD
	local PATH_EXPANDED

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	RAW_PATH=$(path_get_raw_path)

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0} calling path_expand with: ${RAW_PATH}"
	PATH_EXPANDED=$(path_expand ${RAW_PATH})
	[[ ${_DEBUG} -gt 2 ]] && dbg "${0} path_expand returned: ${PATH_EXPANDED}"

	[[ -n ${MAX_LEN} ]] && MAX_LEN="-l ${MAX_LEN}" || MAX_LEN=''

	LABEL=$(echo ${PATH_EXPANDED} | pathabv ${MAX_LEN})
	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:Abbreviated ${PATH_EXPANDED} added to label"

	if [[ ${RAW_PATH:t} =~ "^[\.\~]$" ]];then
		TAIL=''
		[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:TAIL is symbolic path - omitted from label"
	elif is_glob ${RAW_PATH:t};then
		TAIL="/${RAW_PATH:t}"
		[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:TAIL is glob - added to label"
	fi

	LABEL=${LABEL}${TAIL}

	echo ${LABEL}
}

path_get_raw () {
	local RAW_CMD_LINE
	local -a TOKENIZED
	local -a PATH_TOKENS
	local -a RAW_CMD_LINE
	local -a TOKENS
	local WORDS
	local A I
	local PATH_HEAD=?
	local PATH_TAIL=?
	local RAW_PATH
	local FNDX
	local T
	local PATH_EXPANDED

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	if [[ ${_DURABLE[TESTMODE]} == 'true' ]];then
		RAW_CMD_LINE=${_RAW_CMD_LINE}
	else
		fc -R
		RAW_CMD_LINE=("${(f)$(fc -lnr | head -1)}") #parse raw cmdline
	fi

	[[ ${RAW_CMD_LINE} =~ '\|' ]] && echo "Input is piped" && return 1
	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${CYAN_FG}RAW_CMD_LINE:${RAW_CMD_LINE}${RESET}" 

	RAW_CMD_LINE=($(echo ${RAW_CMD_LINE} | perl -p -e 's/[^\s]+//')) #strip leading word (script name)
	RAW_PATH=$(path_strip_options ${RAW_CMD_LINE}) #strip options

	TOKENIZED=("${(f)$(path_read_raw ${RAW_PATH})}") #parse tokens incl names w/ spaces)

	#Eliminate all bare words from command line
	WORDS=0
	for T in ${TOKENIZED};do
		if is_bare_word "${T}";then
			((WORDS++))
			continue
		else
			TOKENS+=${T}
		fi
	done

	if [[ ${_DEBUG} -gt 0 ]];then
		dbg "${0}:${WHITE_FG}RAW_CMD_LINE${RESET}:${RAW_CMD_LINE}"
		dbg "${0}:${WHITE_FG}${WORDS}${RESET} plain words eliminated from command line"
		dbg "${0}:${WHITE_FG}${#TOKENS}${RESET} remaining tokens"
	fi

	RAW_PATH=${TOKENS:=.}
	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${RED_FG}RAW_PATH STRIPPED${RESET}:[${WHITE_FG}${RAW_PATH}${RESET}]"

	PATH_EXPANDED=$(path_expand ${RAW_PATH})

	PATH_HEAD=${PATH_EXPANDED}

	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${GREEN_FG}PATH_HEAD${RESET}:${WHITE_FG}${PATH_HEAD}${RESET} is set"
	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${MAGENTA_FG}Parsing TAIL${RESET}:${RAW_PATH:t}"

	case ${RAW_PATH:t} in
	   '*') PATH_TAIL="-name '*'";[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${WHITE_FG}TAIL is ASTERISK:${RAW_PATH:t}${RESET}";;
		 "") PATH_TAIL="-name '*'";[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${WHITE_FG}TAIL is NULL:${RAW_PATH:t}${RESET}";;
		"~") PATH_TAIL="-name '*'";[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${WHITE_FG}TAIL is TILDE:${RAW_PATH:t}${RESET}";;
		".") PATH_TAIL="-name '*'";[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${WHITE_FG}TAIL is DOT:${RAW_PATH:t}${RESET}";;
		  *)	if is_dir ${RAW_PATH};then
					[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${WHITE_FG}PATH is DIR:${RAW_PATH}${RESET}"
					PATH_TAIL="-name '*'"
				elif is_file ${PATH_HEAD}/${RAW_PATH:t};then
					[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${WHITE_FG}HEAD/TAIL is FILE:${PATH_HEAD}/${RAW_PATH:t}${RESET}"
					I=$(path_get_inode "${PATH_HEAD}/${RAW_PATH:t}")
					[[ ${?} -eq 0 ]] && PATH_TAIL="-inum ${I}" || PATH_TAIL='?' #fallback to prevent empty inode being passed
				elif is_dir ${PATH_HEAD}/${RAW_PATH:t};then
					[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${WHITE_FG}HEAD/TAIL is DIR:${PATH_HEAD}/${RAW_PATH:t}${RESET}"
					PATH_TAIL="-name '${RAW_PATH:t}'"
				elif is_glob ${RAW_PATH:t};then
					[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${WHITE_FG}TAIL is GLOB:${RAW_PATH:t}${RESET}"
					PATH_TAIL="-name '${RAW_PATH:t}'"
				else
					PATH_TAIL=?
				fi;;
	esac

	if [[ ${PATH_TAIL} = '?' ]];then
		#echo "PATH_TAIL is unknown; Parsing ${#TOKENIZED} TOKENS:${TOKENIZED}" >&2
		for T in ${TOKENIZED};do
			if is_file "${T}" || is_dir "${T}";then
				I=$(path_get_inode ${T})
				[[ ${?} -ne 0 ]] && dbg "${RED_FG}BAD INODE CALL${RESET}" && FNDX=0 && break  #bad inode call
				((FNDX++))
				_ARGS[list${FNDX}]=${I} #gather all items on command line
			else
				[[ ${DEBUG} -gt 0 ]] && dbg "TOKEN is neither file nor dir"
			fi
		done
		if [[ ${FNDX} -ne 0 ]];then
			PATH_HEAD=$(realpath $(eval echo ${RAW_PATH:h}))
			PATH_TAIL=$(path_find_prep) #prepare for find command
		fi
	fi

	if [[ ${PATH_TAIL} == '?' && ${FNDX} -eq 0 ]];then
		[[ ${DEBUG} -gt 0 ]] && dbg "No TOKENS were valid paths or files (invalid path or file name)" >&2
		echo "${PATH_HEAD}|Invalid Path:${RAW_PATH}" #return result
		return 1
	fi

	if [[ ${PATH_HEAD} = '?' || ${PATH_TAIL} = '?' ]];then
		[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${RED_FG}Unable to parse command line${RESET}"
		return 1
	fi

	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${CYAN_FG}PATH_HEAD:${PATH_HEAD} PATH_TAIL:${PATH_TAIL}${RESET}" 

	PATH_HEAD=$(realpath ${PATH_HEAD})

	echo "${PATH_HEAD}|${PATH_TAIL}" #return result
	return 0
}

path_get_raw_path () {
	local RAW_CMD_LINE
	local -a TOKENIZED
	local -a TOKENS
	local A
	local RAW_PATH

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	fc -R
	RAW_CMD_LINE=("${(f)$(fc -lnr | head -1)}") #parse raw cmdline
	[[ ${RAW_CMD_LINE} =~ '\|' ]] && echo "Input is piped" && return 0
	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${CYAN_FG}RAW_CMD_LINE:${RAW_CMD_LINE}${RESET}" 
	RAW_CMD_LINE=($(echo ${RAW_CMD_LINE} | perl -p -e 's/[^\s]+//')) #strip leading word (script name)
	RAW_PATH=$(path_strip_options ${RAW_CMD_LINE}) #strip options
	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${CYAN_FG}RAW_PATH:${RAW_PATH} (removed script name & options)${RESET}" 

	TOKENIZED=("${(f)$(path_read_raw ${RAW_PATH})}") #read whole lines (non-traditional file/dir names - spaces)

	for A in ${TOKENIZED};do
		if is_bare_word "${A}";then
			continue
		else
			TOKENS+=${A}
		fi
	done
	RAW_PATH=(${TOKENS:=.}) #default empty path to '.'

	echo ${RAW_PATH}
}

path_read_raw () {
	local RAWCMD=${@}
	local -a TEXT
	local LINE
	local L

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	while read -r LINE;do
		TEXT+=${LINE}
	done < <(path_split_fn ${RAWCMD})

	for L in ${TEXT};do
		echo ${L}
	done
}

path_set_bare_is_file () {
	_BAREWORD_IS_FILE=${1}
}

path_split_fn () {
	local TEXT="${@}"

	perl -pe 's/(?<![\\])[ ]/\n/g' <<<${TEXT}
}

path_strip_options () {
	local LINE=${@}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	while true;do #strip options
        #grep -q '^[-][[:print:]]' <<<${LINE}
        grep -qP '^\-\w+' <<<${LINE}
        [[ ${?} -ne 0 ]] && break
        LINE=$(echo ${LINE} | perl -pe 's/(-\w+)\s+(.*)/\2/g')
	done

	echo ${LINE}
}

selection_list () {
	local TITLE
	local MAX_NDX=${#_SELECTION_LIST}
	local MAX_ITEM_LEN=$(str_longest_len ${_SELECTION_LIST})
	local MAX_X_COORD=$((_MAX_ROWS-5)) #not including frame 5 up from bottom, 4 with frame
	local H=$(( MAX_NDX+2 ))
	local W=$(( MAX_ITEM_LEN+2 ))
	local DIR
	local KEY
	local OPTION
	local PAD=2
	local X_COORD_ARG Y_COORD_ARG
	local L X Y SX SY SW SH SL
	local BOX_NDX=0
	local BOX_ROW=0
	local BOX_X=0
	local BOX_Y=0
	local LIST_BOT=0
	local LIST_NDX=0
	local LIST_TOP=0
	local MAX_BOX=0
	local FULL_BOX=0
	local CTR_Y
	local CLEAN_TITLE
	local OPTSTR

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	OPTSTR=":x:y:"

	X_COORD_ARG=?
	Y_COORD_ARG=?

	OPTIND=0
	while getopts ${OPTSTR} OPTION;do
		case $OPTION in
	   x) X_COORD_ARG=${OPTARG};;
	   y) Y_COORD_ARG=${OPTARG};;
	   :) exit_leave "${RED_FG}${0}${RESET}: option: -${OPTARG} requires an argument";;
	  \?) exit_leave "${RED_FG}${0}${RESET}: unknown option -${OPTARG}";;
		esac
	done
	shift $((OPTIND -1))

	TITLE=${1}

	[[ ${MAX_X_COORD} -lt ${H} ]] && H=$((MAX_X_COORD-10 )) #long list

	[[ ${X_COORD_ARG} -ne '?' ]] && X=${X_COORD_ARG} || X=$(coord_center $((_MAX_ROWS)) ${H})
	[[ ${Y_COORD_ARG} -ne '?' ]] && Y=${Y_COORD_ARG} || Y=$(coord_center $((_MAX_COLS-60)) ${W})

	[[ ${MAX_ITEM_LEN} -gt ${#TITLE} ]] && SW=$(( MAX_ITEM_LEN+2 )) || SW=$(( ${#TITLE}+2 )) #choose either item or title for box width

	SX=$(( X-PAD ))
	SY=$(( Y-PAD ))
	SW=$(( SW+(PAD*2) ))
	SH=$(( H+(PAD*2) ))

	[[ $((SW % 2)) -ne 0 ]] && ((SW++)) #even width cols
	[[ $((W % 2)) -ne 0 ]] && ((W++)) #even width cols

	SL=$(( SX+H+(PAD*2)-1 )) #loop limit

	[[ ${_DEBUG} -ge 2 ]] && dbg "${0}: X:${X} Y:${Y} W:${W} H:${H} PAD:${PAD}=PAD"
	[[ ${_DEBUG} -ge 2 ]] && dbg "${0}: SX:${SX}->SL:${SL}, SY:${SY}->SW:${SW}"
	[[ ${_DEBUG} -ge 2 ]] && dbg "${0}: Y to center:${Y}"

	#Space around list
	for ((L=SX;L<=SL;L++));do
		tp cup ${L} ${SY};tp ech ${SW}
	done

	#Outer box w/ title
	msg_unicode_box ${SX} ${SY} ${SW} ${SH}
	CLEAN_TITLE=$(msg_nomarkup ${TITLE})
	tp cup $((SX+1)) $(( SY+(SW/2)-(${#CLEAN_TITLE}/2) ));echo $(msg_markup ${TITLE})

	#Initialize
	[[ ${H} -lt ${MAX_NDX} ]] && MAX_BOX=$((H-PAD)) || MAX_BOX=${MAX_NDX} #set box boundary
	CTR_Y=$(( SY+(SW/2)-(W/2) )) #new Y to center list
	BOX_X=$((X+1))
	BOX_Y=$((CTR_Y+1))
	LIST_NDX=0
	LIST_TOP=1
	LIST_BOT=0
	FULL_BOX=${MAX_BOX}
	 
	#Display list
	tp civis
	while true;do
		BOX_ROW=${BOX_X}
		BOX_NDX=1
		msg_unicode_box ${X} ${CTR_Y} ${W} ${H} #display inner box for list
		for (( LIST_NDX=LIST_TOP;LIST_NDX<=MAX_NDX;LIST_NDX++ ));do
			[[ $((BOX_NDX++)) -gt ${MAX_BOX} ]] && break
			tp cup ${BOX_ROW} ${BOX_Y}
			[[ ${BOX_ROW} -eq ${BOX_X} ]] && tp smso || tp rmso
			echo ${_SELECTION_LIST[${LIST_NDX}]}
			((BOX_ROW++))
		done
		LIST_BOT=$((LIST_NDX-1))
		[[ ${BOX_NDX} -lt ${MAX_BOX} ]] && MAX_BOX=$((BOX_NDX-1)) #handle partials

		#Operate list cursor
		local CURSOR_NDX=${LIST_TOP}
		local CURSOR_ROW=${BOX_X}
		while true;do
			KEY=$(list_get_keys)
			case ${KEY} in
				0) _SELECTION_VALUE=${_SELECTION_LIST[${CURSOR_NDX}]} && break 2;;
				27) return 2;;
				2|106) ((CURSOR_ROW++));((CURSOR_NDX++));DIR='D';;
				1|107) ((CURSOR_ROW--));((CURSOR_NDX--));DIR='U';;
				3|116) DIR='T';;
				4|98) DIR='B';;
			esac
			if [[ ${CURSOR_NDX} -lt ${LIST_TOP} ]];then
				CURSOR_NDX=${LIST_BOT}
				CURSOR_ROW=$((BOX_X+MAX_BOX-1))
			elif [[ ${CURSOR_NDX} -gt ${LIST_BOT} ]];then
				CURSOR_NDX=${LIST_TOP}
				CURSOR_ROW=${BOX_X}
			fi
			if [[ ${DIR} == 'D' ]];then
				if [[ ${CURSOR_NDX} -eq ${LIST_TOP} ]];then
					[[ ${LIST_BOT} -lt ${MAX_NDX} ]] && LIST_TOP=$((LIST_BOT+1)) && break #crossed boundary; advance list
					selection_list_norm $((BOX_X+MAX_BOX-1)) ${BOX_Y} ${_SELECTION_LIST[${LIST_BOT}]}
					selection_list_hilite ${BOX_X} ${BOX_Y} ${_SELECTION_LIST[${LIST_TOP}]}
				elif [[ ${CURSOR_NDX} -ge ${LIST_TOP} ]];then
					selection_list_norm $((CURSOR_ROW-1)) ${BOX_Y} ${_SELECTION_LIST[$((CURSOR_NDX-1))]}
					selection_list_hilite ${CURSOR_ROW} ${BOX_Y} ${_SELECTION_LIST[${CURSOR_NDX}]}
				fi
			elif [[ ${DIR} == 'U' ]];then
				if [[ ${CURSOR_NDX} -eq ${LIST_BOT} ]];then
					if [[ ${LIST_TOP} -gt 1 ]];then #crossed boundary; rewind list
						if [[ ${LIST_BOT} -lt ${MAX_NDX} ]];then
							LIST_TOP=$(( LIST_BOT-((MAX_BOX*2)-1) ))
						else
							LIST_TOP=$(( MAX_NDX-(MAX_BOX+FULL_BOX-1) ))
							MAX_BOX=${FULL_BOX}
						fi
						break
					fi
					selection_list_norm ${BOX_X} ${BOX_Y} ${_SELECTION_LIST[${LIST_TOP}]}
					selection_list_hilite $((BOX_X+MAX_BOX-1)) ${BOX_Y} ${_SELECTION_LIST[${LIST_BOT}]}
				elif [[ ${CURSOR_NDX} -le ${LIST_BOT} ]];then
					selection_list_norm $((CURSOR_ROW+1)) ${BOX_Y} ${_SELECTION_LIST[$((CURSOR_NDX+1))]}
					selection_list_hilite ${CURSOR_ROW} ${BOX_Y} ${_SELECTION_LIST[${CURSOR_NDX}]}
				fi
			elif [[ ${DIR} == 'T' ]];then
				selection_list_norm ${CURSOR_ROW} ${BOX_Y} ${_SELECTION_LIST[$((CURSOR_NDX))]}
				selection_list_hilite ${BOX_X} ${BOX_Y} ${_SELECTION_LIST[${LIST_TOP}]}
				CURSOR_NDX=${LIST_TOP}
				CURSOR_ROW=${BOX_X}
			elif [[ ${DIR} == 'B' ]];then
				selection_list_norm ${CURSOR_ROW} ${BOX_Y} ${_SELECTION_LIST[$((CURSOR_NDX))]}
				selection_list_hilite $((BOX_X+MAX_BOX-1)) ${BOX_Y} ${_SELECTION_LIST[${LIST_BOT}]}
				CURSOR_NDX=${LIST_BOT}
				CURSOR_ROW=$((BOX_X+MAX_BOX-1))
			fi
		done
	done
	tp cup ${_MAX_ROWS} ${_MAX_COLS}
	tp cnorm
}

selection_list_hilite () {
	local X=${1}
	local Y=${2}
	local TEXT=${3}

	[[ ${_DEBUG} -ge 2 ]] && dbg "${0}:X:${X} Y:${Y} TEXT:${TEXT}"

	tp cup ${X} ${Y}
	tp smso
	echo ${TEXT}
	tp rmso
}

selection_list_norm () {
	local X=${1}
	local Y=${2}
	local TEXT=${3}

	[[ ${_DEBUG} -ge 2 ]] && dbg "${0}:X:${X} Y:${Y} TEXT:${TEXT}"

	tp cup ${X} ${Y}
	tp rmso
	echo ${TEXT}
}

selection_list_set () {
	local LIST=(${@})

	_SELECTION_LIST=(${(on)LIST})
	[[ ${_DEBUG} -ge 1 ]] && dbg "${0} _SELECTION_LIST:${#_SELECTION_LIST} ITEMS"
}

set_exit_value () {
	_EXIT_VALUE=${1}
}

str_array_to_num () {
	local -a STR=(${@})
	local MAX=${#STR}
	local NUM=0
	local MAG=0
	local S

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	((MAX--))
	for S in ${STR};do
		((MAG=10**MAX))
		NUM=$((NUM+(S*MAG)))
		((MAX--))
	done

	echo ${NUM}
}

str_center () {
	local -i PAD
	local -i REM
	local BORDER
	local MSG 
	local TEXT 
	local TEXT_WIDTH
	local WIDTH

	WIDTH=${1};shift
	TEXT="${@}"
	TEXT_WIDTH=${#TEXT}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:WIDTH:${WIDTH} TEXT:${TEXT} TEXT_WIDTH:${TEXT_WIDTH}"

	REM=$(( WIDTH-${TEXT_WIDTH} ))
	BORDER=' ' #minimum border
	if [[ ${REM} -ne 0 ]];then
		PAD=$(( REM/2 ))
		BORDER=$(printf ' %.0s' {1..${PAD}})
	fi

	MSG="${BORDER}${TEXT}${BORDER}" #pad

	[[ ${#MSG} -lt ${WIDTH} ]] && MSG=$(str_pad_string ${WIDTH} ${MSG})
	[[ ${#MSG} -gt ${WIDTH} ]] && MSG=${MSG[1,${WIDTH}]} #  do not exceed width

	[[ ${_DEBUG} -gt 2 ]] && echo "${WHITE_FG}\nLeaving${RESET}:${0} with [${MSG}] Length:${#MSG}" >&2 

	echo "${MSG}"
}

str_center_pad () {
	local -i PAD
	local -i REM
	local BORDER=' ' #minimum border
	local MSG 
	local TEXT 
	local TEXT_WIDTH
	local WIDTH

	WIDTH=${1};shift
	TEXT=${@}
	TEXT_WIDTH=${#TEXT}
	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:WIDTH:${WIDTH} TEXT_WIDTH:${TEXT_WIDTH} TEXT:${TEXT}"

	REM=$((WIDTH-TEXT_WIDTH))
	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:WIDTH-TEXT_WIDTH:$((WIDTH-TEXT_WIDTH)) REM:${REM}"

	if [[ ${REM} -ne 0 ]];then
		[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:REM:${REM}"
		PAD=$(( REM/2 ))
		BORDER=$(printf ' %.0s' {1..${PAD}})
		[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:PAD:${PAD}"
	fi
	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:BORDER:${#BORDER}:[${BORDER}] WIDTH-(PAD+TEXT_WIDTH+2):$(( WIDTH - (PAD+TEXT_WIDTH+2) ))"

	echo "${BORDER}"
}

str_clean_line_len () {
	local STR_IN=${@}
	local LENGTH

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	LENGTH=$(echo ${STR_IN} | sed -e 's/\x1b\[[0-9;]*m//g' -e 's/ *$//g' | tr -d '\011\012\015') #ansi/trailing sp/newlines/etc
	echo ${#LENGTH}
}

str_clean_path () {
	local DIR=${1}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	echo "${DIR}" | perl -pe 's#/+#/#g'
}

str_expanded_length () {
	local STR=${@}
	local LEN

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	LEN=$(expand <<<${STR} | wc -m)
	echo $((--LEN))
}

str_from_hex () {
	local HEX=${@}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ -n ${HEX} ]] && printf $HEX
}

str_longest_len () {
	local ALIST=(${@})
	local LONGEST=0
	local STR
	local L

	for L in ${ALIST};do
		STR=$(msg_nomarkup ${L})
		[[ ${#STR} -ge ${LONGEST} ]] && LONGEST=${#STR}
		[[ ${_DEBUG} -gt 2 ]] && dbg "${0}: STR:\"${STR}\" LEN:${#STR}"
	done

	[[ ${_DEBUG} -gt 3 ]] && dbg "${0}: LONGEST:${LONGEST}"

	echo $((LONGEST+1))
}

str_longest_str () {
	local ALIST=(${@})
	local LONGEST=0
	local LONGEST_STR
	local STR
	local L

	[[ ${_DEBUG} -gt 3 ]] && dbg "${0}:${@}"

	for L in ${ALIST};do
		STR=$(str_trim ${L})
		[[ ${#STR} -ge ${LONGEST} ]] && LONGEST=${#STR} && LONGEST_STR=${STR}
	done

	[[ ${_DEBUG} -gt 1 ]] && dbg "${0}:ALIST:${#ALIST} items LONGEST:${LONGEST} STR:${STR}"

	echo ${STR}
}

str_pad_digit () {
	local NDX=${1}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ${NDX} -lt 10 ]] && echo "  ${NDX}" && return
	[[ ${NDX} -lt 100 ]] && echo " ${NDX}" && return
	[[ ${NDX} -lt 1000 ]] && echo "${NDX}" && return
}

str_pad_string () {
	local WIDTH
	local STR

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	WIDTH=${1};shift
	STR=${@}
	STR="${STR}$(str_rep_char ' ' $((WIDTH-${#STR})))"

	[[ ${_DEBUG} -gt 1 ]] && dbg "${0}:Returning with:${WHITE_FG}[${STR}]${RESET}" >&2 

	echo ${STR}
}

str_pluralize () {
	local WORD=${1}
	local CNT=${2}
	local RETURN_ALL=${3:=false} #any 3rd arg triggers 
	local RETURN_WORD

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	if [[ ${CNT} -eq 1 ]];then
		[[ ${RETURN_ALL} == 'false' ]] && echo "${WORD}" || echo "${CNT} ${WORD}"
		return
	fi

	case ${WORD:l} in
		app) RETURN_WORD="apps";;
		choice) RETURN_WORD="choices";;
		command) RETURN_WORD="commands";;
		config) RETURN_WORD="configs";;
		device) RETURN_WORD="devices";;
		directory) RETURN_WORD="directories";;
		duplicate) RETURN_WORD="duplicates";;
		entry) RETURN_WORD="entries";;
		file) RETURN_WORD="files";;
		item) RETURN_WORD="items";;
		link) RETURN_WORD="links";;
		line) RETURN_WORD="lines";;
		log) RETURN_WORD="logs";;
		match) RETURN_WORD="matches";;
		object) RETURN_WORD="objects";;
		option) RETURN_WORD="options";;
		package) RETURN_WORD="packages";;
		process) RETURN_WORD="processes";;
		row) RETURN_WORD="rows";;
		title) RETURN_WORD="titles";;
		torrent) RETURN_WORD="torrents";;
		track) RETURN_WORD="tracks";;
		was) RETURN_WORD="were";;
		*) RETURN_WORD=${WORD};;
	esac

	[[ ${WORD} == ${(C)WORD} ]] && RETURN_WORD=${(C)RETURN_WORD} || RETURN_WORD=${RETURN_WORD}

	if [[ ${WORD} == ${WORD:u} ]];then #assume uppercase
		RETURN_WORD=${RETURN_WORD:u}
	else #assume mixed or lowercase
		RETURN_WORD=${RETURN_WORD}
	fi

	[[ ${RETURN_ALL} == 'false' ]] && echo "${RETURN_WORD}" || echo "${CNT} ${RETURN_WORD}"
}

str_rep_char () {
	local CHAR=${1}
	local LENGTH=${2}
	local LINE
	local X

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	LINE=''
	for ((X=0;X < ${LENGTH};X++));do
		LINE=${LINE}''${CHAR}
	done

	echo ${LINE}
}

str_strip_ansi () {
	local OUTPUT_LEN
	local LINE
	local CLEAN_LINE
	local LEN

	[[ ${1} == '-l' ]] && OUTPUT_LEN=true || OUTPUT_LEN=false

	while read LINE;do
		#strip ansi escape chars
		CLEAN_LINE+=$(perl -pe 's/\x1B\[+[\d;]*[mK]//g' <<<${LINE})
		#CLEAN_LINE+=$(perl -pe 's/[\e^]\[+[\d;]*[mK]//g' <<<${LINE})
		#CLEAN_LINE+=$(perl -pe 's/\e\[\d+(?>(;\d+)*)m//g' <<<${LINE})
	done

	LEN=$(( ${#CLEAN_LINE[@]} ))
	[[ ${OUTPUT_LEN} == 'true' ]] && echo ${LEN} || echo ${CLEAN_LINE}
}

str_to_hex () {
	local TXT=${@}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	echo $TXT | od -An -tx1 | tr -d '[\n]' | sed 's/ /\\x/g' 
}

str_trim () {
	local TEXT=${@}

	[[ ${_DEBUG} -gt 3 ]] && dbg "${0}:${@}"

	if [[ -z ${TEXT} && ! -t 0 ]];then
		read TEXT
		sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//' <<<${TEXT}
	else
		echo ${TEXT} | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//'
	fi
}

str_truncate () {
	local LENGTH
	local TEXT

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	LENGTH=${1} && shift
	TEXT=${@}

	echo ${TEXT[1,${LENGTH}]}
}

str_unicode_line () {
	local LENGTH=${1}
	local HORIZ_BAR="\\u2500%.0s"

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	printf "\\u2500%.0s" {1..$((${LENGTH}))}
}

str_unpipe () {
	local FIELD
	local CUT_PARAM
	local PIPE_DATA

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ${#} -gt 1 ]] && FIELD=${1} && shift
	PIPE_DATA=${@}

	[[ -n ${FIELD} ]] && CUT_PARAM="-f${FIELD}" || CUT_PARAM="-f1-" 
	cut --output-delimiter=' ' -d'|' ${CUT_PARAM} <<<${PIPE_DATA}
}

validate_is_integer () {
	local VAL=${1}
	local RET

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	RET=$( echo "${VAL}" | sed 's/^[-+]*[0-9]*//g' )
	if [[ -z ${RET} ]];then
		return 0
	else
		return 1
	fi
}

validate_is_list_item () {
	local ITEM_NDX=${1}
	local MAX_ITEM=${2}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ ${ITEM_NDX} -gt 0 && ${ITEM_NDX} -le ${MAX_ITEM} ]] && return 0 || return 1
}

validate_is_number () {
	local NDX=${1}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	if [[ -n ${NDX} && ${NDX} == ${NDX%%[!0-9]*} ]];then
		return 0
	else
		return 1
	fi
}

win_close () {
	local WDW_ID=$(win_xdo_id_fix ${1})

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ -z ${1} ]] && echo "$0: Missing argument WDW_ID" && return 1

	xdotool windowclose ${WDW_ID}

	return 0
}

win_focus () {
	local WDW_ID=$(win_xdo_id_fix ${1})

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ -z ${1} ]] && echo "$0: Missing argument WDW_ID" && return 1

	xdotool windowfocus ${WDW_ID}
	xdotool windowraise ${WDW_ID}

	return 0
}

win_focus_title () {
	local WIN_NAME=${1}
	local WDW_ID

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ -z ${1} ]] && echo "$0: Missing argument WIN_NAME" && return 1

	WDW_ID=$(win_get_id ${WIN_NAME})
	win_focus ${WDW_ID}
}

win_get_id () {
	local WIN_NAME=${1}
	local WDW_ID

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ -z ${1} ]] && echo "$0: Missing argument WIN_NAME" && return 1

	xwininfo -root -tree | grep -qi ${WIN_NAME}

	[[ ${?} -ne 0 ]] && echo "Window ${WIN_NAME} not found">&2 && return $?

	WDW_ID=$(xwininfo -root -tree | grep -i ${WIN_NAME} | awk '{print $1}' | head -n 1)

	echo ${WDW_ID}

	return 0
}

win_get_pid () {
	local WIN_NAME=${1}
	local WDW_PID

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ -z ${1} ]] && echo "$0: Missing argument WIN_NAME" && return 1

	WDW_PID=$(pgrep -ifo ${WIN_NAME}) #case insensitive; full path; oldest

	echo ${WDW_PID}

	return $?
}

win_list () {
	local WIN_NAME=${1}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ -z ${1} ]] && echo "$0: Missing argument WIN_NAME" && return 1

	wmctrl -l | grep -i ${WIN_NAME} >&2

	return $?
}

win_xdo_id_fix () {
	local ID=${1}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ -z ${1} ]] && echo "$0: Missing argument ID" && return 1

	[[ ! ${ID} =~ '^0x0' ]] && sed 's/0x/0x0/g' <<<${ID} || echo ${ID} #make id xdotool compatible
}

win_xwin_dump () {
	local WIN_NAME=${1}

	[[ ${_DEBUG} -gt 2 ]] && dbg "${0}:${@}"

	[[ -z ${1} ]] && echo "$0: Missing argument WIN_NAME" && return 1

	xwininfo -root -tree | grep -i ${WIN_NAME} >&2

	return $?
}

#Initialize traps
if [[ ${_TRAP_BLACKLIST[(i)${_SCRIPT}]} -gt ${#_TRAP_BLACKLIST} ]];then #not blacklisted
	for SIG in {1..9}; do
		trap 'exit_sigexit '${SIG}'' ${SIG}
	done
	_TRAPS=true
	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}: ${RED_FG}TRAPS SET${RESET}"
else
	#prevent resident apps from exiting the shell
	_TRAPS=false
	[[ ${_DEBUG} -gt 0 ]] && dbg "${0}: ${RED_FG}TRAPS NOT SET${RESET}" 
fi
