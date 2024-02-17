#LIB Dependencies
_DEPS_+="DBG.zsh MSG.zsh TPUT.zsh"

#LIB Declarations
typeset -a _DELIMS=('#' '|' ':' ',' '	') # Recognized field delimiters

#LIB Vars
_EXIT_VALUE=0
_FUNC_TRAP=false
_BAREWORD_IS_FILE=false

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
	CMD_LINE=("${(f)$(fc -lnr | head -1)}") # Parse raw cmdline
	echo ${CMD_LINE}
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

	# Decrease decimal places based on intensity
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

get_delim_field_cnt () {
	local DELIM_ROW=${@}
	local FCNT=0
	local DELIM=$(parse_find_valid_delim ${DELIM_ROW})

	if [[ -n ${DELIM} ]];then
		FCNT=$(echo ${DELIM_ROW} | grep -o ${DELIM} | wc -l)
		echo $(( ++FCNT ))
		return 0
	else
		return 1
	fi
}

get_keys () {
	local PROMPT
	local RESP=?;
	local -a NUM
	local K1 K2 K3 KEY
		
	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	PROMPT=${@}

	(tput cup $((_MAX_ROWS-2)) 0;printf "${PROMPT}")>&2 # Position cursor and display prompt to STDERR

	[[ ${XDG_SESSION_TYPE:l} == 'x11' ]] && eval "xset ${_XSET_LOW_RATE}"

	while read -sk1 KEY;do
		[[ -z ${KEY} ]] && break
		# Slurp input buffer
		read -sk1 -t 0.0001 K1
		read -sk1 -t 0.0001 K2
		read -sk1 -t 0.0001 K3
		KEY+=${K1}${K2}${K3}

		case "${KEY}" in 
			$'\x0A') RESP=0;; # Return
			$'\e[A') RESP=1;; # Up
			$'\e[B') RESP=2;; # Down
			$'\e[D') RESP=3;; # Left
			$'\e[C') RESP=4;; # Right
			$'\e[5~') RESP=5;; # PgUp
			$'\e[6~') RESP=6;; # PgDn
			$'\e[H') RESP=7;; # Home
			$'\e[F') RESP=8;; # End
			$'\x7F') if [[ ${#NUM} -gt 0 ]];then # BackSpace
							NUM[${#NUM}]=()
							echo -n " ">&2
						fi;;
			      *) RESP=$(printf '%d' "'${KEY}");; # Ascii letter value
		esac

		if [[ ${RESP} != "?" ]];then
			if [[ -z ${NUM} ]];then
				[[ ${RESP} -lt 65 ]] && echo ${RESP} || echo $(get_key_trans ${RESP})
			else
				echo "K${(j::)NUM}"
			fi
			break
		fi
	done

	[[ ${XDG_SESSION_TYPE:l} == 'x11' ]] && eval "xset ${_XSET_DEFAULT_RATE}"
}

get_key_trans () {
	local KEY_IN=${1}
	local KEY_OUT

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	case ${KEY_IN} in
		32) KEY_OUT=32;; # Space
		47) KEY_OUT=47;; # Forward Slash
		60) KEY_OUT=60;; # Less Than
		62) KEY_OUT=62;; # Greater Than
		65) KEY_OUT=65;; # A
		68) KEY_OUT=68;; # D
		69) KEY_OUT=69;; # E
		97) KEY_OUT=97;; # a
		98) KEY_OUT=98;; # b
		99) KEY_OUT=99;; # c
		100) KEY_OUT=100;; # d
		101) KEY_OUT=101;; # e
		102) KEY_OUT=102;; # f
		103) KEY_OUT=103;; # g
		104) KEY_OUT=104;; # h
		105) KEY_OUT=105;; # i
		106) KEY_OUT=106;; # j
		107) KEY_OUT=107;; # k
		108) KEY_OUT=108;; # l
		109) KEY_OUT=109;; # m
		110) KEY_OUT=110;; # n
		111) KEY_OUT=111;; # o
		112) KEY_OUT=112;; # p
		113) KEY_OUT=113;; # q
		114) KEY_OUT=114;; # r
		115) KEY_OUT=115;; # S
		116) KEY_OUT=116;; # t
		117) KEY_OUT=117;; # u
		118) KEY_OUT=118;; # v
		119) KEY_OUT=119;; # w
		120) KEY_OUT=120;; # x
		121) KEY_OUT=121;; # y
		122) KEY_OUT=122;; # z
		*) KEY_OUT=${KEY_IN};;
	esac
	echo ${KEY_OUT}
}

is_bare_word () {
	local TEXT="${@}"

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${TEXT} =~ '\*' || ${TEXT} =~ '\~' || ${TEXT} =~ '^/.*' ]] && return 1

	if [[ ${_BAREWORD_IS_FILE} == 'false' ]];then # Bare words should be tested as possible file and dir names
		[[ -f ${TEXT:Q} || -d ${TEXT:Q} ]] && return 1 || return 0
	fi
}

is_dir () {
	local TEXT="${@}"

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	TEXT=$(eval "echo ${TEXT}")
	[[ -d ${TEXT} ]] && return 0 || return 1
}

is_empty_dir () {
	local DIR=${1}

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ -d ${DIR} ]] && return $(ls -A ${DIR} | wc -l)
}

is_file () {
	local TEXT="${@}"

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ -f ${TEXT:Q} ]] && return 0 || return 1
}

is_glob () {
	local TEXT="${@}"

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${TEXT:Q} =~ '\*' ]] && return 0 || return 1
}

is_singleton () {
	local EXEC_NAME=${1}
	local INSTANCES=$(pgrep -fc ${EXEC_NAME})

	[[ ${INSTANCES} -eq 0 ]] && return 0 || return 1
}

is_symbol_dir () {
	local ARG=${1}

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

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

key_wait () {
	echo -n "Press any key..." && read -sk1
}

logit () {
	local MSG=${@}
	local STAMP=$(date +'%Y-%m-%d:%T')
	echo "${STAMP} ${MSG}" >> ${_LOG:=/tmp/${0}.log}
}

parse_find_valid_delim () {
	local LINE=${1}
	local DELIM=''
	local D

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	for D in ${_DELIMS};do
		grep -q ${D} <<<${LINE}
		[[ $? -eq 0 ]] && DELIM=${D} && break
	done

	[[ -n ${DELIM} ]] && echo ${DELIM} && return 0
	return 1
}

parse_get_last_field () {
	local DELIM=${1};shift
	local LINE=${@}

	echo -n ${LINE} | rev | cut -d"${DELIM}" -f1 | rev
}

num_byte_conv () {
	local BYTES=${1}
	local WANTED=${2}

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

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

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	(
	if [[ ${BYTES} -gt ${GIG_D} ]];then printf "%10.2fGB" $((${BYTES}.0/${GIG_D}.0))
	elif [[ ${BYTES} -gt ${MEG_D} ]];then printf "%10.2fMB" $((${BYTES}.0/${MEG_D}.0))
	elif [[ ${BYTES} -gt ${KIL_D} ]];then printf "%10.2fKB" $((${BYTES}.0/${KIL_D}.0))
	else printf "%10dB" ${BYTES} 
	fi
	) | sed 's/^[ \t]*//g' 
}

