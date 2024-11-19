# LIB Dependencies
_DEPS_+="DBG.zsh MSG.zsh TPUT.zsh"

# LIB Declarations
typeset -a _DELIMS=('#' '|' ':' ',' '	') # Recognized field delimiters
typeset -a _POS_ARGS=()
typeset -A _KWD_ARGS=()

# LIB Vars
_EXIT_VALUE=0
_FUNC_TRAP=false
_BAREWORD_IS_FILE=false
_UTILS_LIB_DBG=4


arg_parse () {
	local KWD=false
	local A
	local NDX
	local KEY

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	NDX=0
	for A in ${@};do
		if [[ ${KWD} == 'true' ]];then
			_KWD_ARGS[${KEY}]=${A}
			KWD=false
			continue
		fi
		if [[ ${A} =~ ^(-|--) ]];then
			KEY=$(sed -e 's/^-*//' <<<${A})
			KWD=true
			continue
		fi
		((NDX++))
		_POS_ARGS[${NDX}]=${A}
	done
}

assoc_del_key () {
	emulate -LR zsh
	setopt extended_glob

	if [[ -${(Pt)1}- != *-association-* ]]; then
		return 120 # Fail early if $1 is not the name of an associative array
	fi

	set -- "$1" "${(j:|:)${(@b)@[2,$#]}}"

	# Copy all entries except the specified ones
	: "${(AAP)1::=${(@kv)${(P)1}[(I)^($~2)]}}"
}

boolean_color () {
	local STATE=${1}

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	case ${STATE} in
		0) echo ${GREEN_FG};;
		active) echo -n ${GREEN_FG};;
		connected) echo -n ${GREEN_FG};;
		current) echo -n ${GREEN_FG};;
		stale) echo -n ${RED_FG};;
		on) echo -n ${GREEN_FG};;
		pass) echo -n ${GREEN_FG};;
		running) echo -n ${GREEN_FG};;
		true) echo -n ${GREEN_FG};;
		valid) echo -n ${GREEN_FG};;
		*) echo -n ${RED_FG};;
	esac
}

boolean_color_word () {
	local STATE=${1}
	local ANSI_ECHO=false

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${#} -eq 2 ]] && ANSI_ECHO=true
	
	case ${STATE} in
		0) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${GREEN_FG}true${RESET}" || echo -n "${E_GREEN_FG}true${E_RESET}";;
		1) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${RED_FG}false${RESET}" || echo -n "${E_RED_FG}false${E_RESET}";;
		active) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${GREEN_FG}${STATE}${RESET}" || echo -n "${E_GREEN_FG}${STATE}${E_RESET}";;
		current) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${GREEN_FG}${STATE}${RESET}" || echo -n "${E_GREEN_FG}${STATE}${E_RESET}";;
		stale) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${RED_FG}${STATE}${RESET}" || echo -n "${E_RED_FG}${STATE}${E_RESET}";;
		fail) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${RED_FG}${STATE}${RESET}" || echo -n "${E_RED_FG}${STATE}${E_RESET}";;
		pass) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${GREEN_FG}${STATE}${RESET}" || echo -n "${E_GREEN_FG}${STATE}${E_RESET}";;
		true) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${GREEN_FG}${STATE}${RESET}" || echo -n "${E_GREEN_FG}${STATE}${E_RESET}";;
		valid) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${GREEN_FG}${STATE}${RESET}" || echo -n "${E_GREEN_FG}${STATE}${E_RESET}";;
		*) [[ ${ANSI_ECHO} == "false" ]] && echo -n "${RED_FG}${STATE}${RESET}" || echo -n "${E_RED_FG}${STATE}${E_RESET}";;
	esac
}

box_coords_repaint () {
	local TAG=${1}
	local ARR_NAME=${2:=_LIST}
	local -A COORDS=($(box_coords_get ${TAG}))
	local X_LIMIT
	local Y_LIMIT
	local X Y

	X_LIMIT=$(( COORDS[H] + COORDS[X] ))
	Y_LIMIT=$(( COORDS[Y] + COORDS[W] ))

	for (( X=${COORDS[X]}; X <= X_LIMIT; X++ ));do
		for (( Y=${COORDS[Y]}; Y <= Y_LIMIT; Y++ ));do
			tput cup $((X-1)) $((Y-1)); echo -n ${${(P)ARR_NAME}[${X}][${Y}]} # Offset zero based tput
		done
	done
}

box_coords_del () {
	local TAG=${1}

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@} TAG:${TAG}"

	assoc_del_key _BOX_COORDS ${TAG}
}

box_coords_dump () {
	local K

	echo "\n--- COORDS ---"
	for K in ${(k)_BOX_COORDS};do
		printf "${WHITE_FG}TAG${RESET}:%s ${WHITE_FG}COORDS${RESET}:%s\n" ${K} ${_BOX_COORDS[${K}]}
	done
	echo "--- End COORDS ---"
}

box_coords_overlap () {
	local TAG_1=${1}
	local TAG_2=${2}

	local -A BOX_A_COORDS=($(box_coords_get ${TAG_1}))
	local -A BOX_B_COORDS=($(box_coords_get ${TAG_2}))

	local -i L1_X=${BOX_A_COORDS[X]}
	local -i R1_X=$(( BOX_A_COORDS[X] + BOX_A_COORDS[H] -1 ))
	local -i L1_Y=${BOX_A_COORDS[Y]}
	local -i R1_Y=$(( BOX_A_COORDS[Y] + BOX_A_COORDS[W] -1 ))

	#tput cup ${L1_X} ${L1_Y};echo -n "${RED_FG}(L1 X:${L1_X},Y:${L1_Y})${RESET}"
	#tput cup ${R1_X} ${R1_Y};echo -n "${RED_FG}(R1 X:${R1_X},Y:${R1_Y})${RESET}"

	local -i L2_X=${BOX_B_COORDS[X]}
	local -i R2_X=$(( BOX_B_COORDS[X] + BOX_B_COORDS[H] -1 ))
	local -i L2_Y=${BOX_B_COORDS[Y]}
	local -i R2_Y=$(( BOX_B_COORDS[Y] + BOX_B_COORDS[W] -1 ))

	#tput cup ${L2_X} ${L2_Y};echo -n "${GREEN_FG}(L2 X:${L2_X},Y:${L2_Y})${RESET}"
	#tput cup ${R2_X} ${R2_Y};echo -n "${GREEN_FG}(R2 X:${R2_X},Y:${R2_Y})${RESET}"

	local STATE=OVERLAP
	[[ ${L2_X} -gt ${R1_X} ]] && STATE=CLEAR
	[[ ${L2_Y} -gt ${R1_Y} ]] && STATE=CLEAR
	echo ${STATE}
}

box_coords_relative () {
	local BASE_TAG=${1};shift
	local -A OFFSETS=(${@})
	local -A BASE_COORDS=()

	# OFFSETS are in the form [+-]INT or INT

	BASE_COORDS=($(box_coords_get ${BASE_TAG}))
	[[ -z ${BASE_COORDS} ]] && return 1

	if [[ -n ${OFFSETS[X]} ]];then
		[[ ${OFFSETS[X]} =~ '[+-]' ]] && BASE_COORDS[X]=$(( ${BASE_COORDS[X]}${OFFSETS[X]} )) || BASE_COORDS[X]=${OFFSETS[X]}
	fi
	if [[ -n ${OFFSETS[Y]} ]];then
		[[ ${OFFSETS[Y]} =~ '[+-]' ]] && BASE_COORDS[Y]=$(( ${BASE_COORDS[Y]}${OFFSETS[Y]} )) || BASE_COORDS[Y]=${OFFSETS[Y]}
	fi
	if [[ -n ${OFFSETS[W]} ]];then
		[[ ${OFFSETS[W]} =~ '[+-]' ]] && BASE_COORDS[W]=$(( ${BASE_COORDS[W]}${OFFSETS[W]} )) || BASE_COORDS[W]=${OFFSETS[W]}
	fi
	if [[ -n ${OFFSETS[H]} ]];then
		[[ ${OFFSETS[H]} =~ '[+-]' ]] && BASE_COORDS[H]=$(( ${BASE_COORDS[H]}${OFFSETS[H]} )) || BASE_COORDS[H]=${OFFSETS[H]}
	fi

	echo ${(kv)BASE_COORDS}
}

box_coords_set () {
	local -a ARGS=(${@})
	local TAG=${ARGS[1]}
	local COORDS=${ARGS[2,-1]}

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@} TAG:${TAG}"

	_BOX_COORDS[${TAG}]="${COORDS}"
}

box_coords_get () {
	local TAG=${1}

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@} TAG:${TAG}"

	[[ -z ${_BOX_COORDS[${TAG}]} ]] && return 1

	echo ${(kv)_BOX_COORDS[${TAG}]}
}

box_coords_upd () {
	local TAG=${1}
	local KEY=${2}
	local VAL=${3}
	local -A UPD=()
	local COORDS=''

	COORDS=$(box_coords_get ${TAG})
	[[ -z ${COORDS} ]] && return 1

	UPD=(${COORDS})

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@} TAG:${TAG}"

	[[ ${#UPD} -eq 0 ]] && return 1

	box_coords_set ${TAG} X ${UPD[X]} Y ${UPD[Y]} W ${UPD[W]} H ${UPD[H]} ${KEY} ${VAL}

	return 0
}

cmd_get_raw () {
	local CMD_LINE

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

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

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

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

func_delete () {
	local FUNC=${1}
	local FN=${2}

	sed -i "/${FUNC}.*() {/,/^}/d" ${FN}
}

func_list () {
	local FN=${1}

	grep --color=never -P "^\S.*() {\s*$" < ${FN} | cut -d'(' -f1 | sed -e 's/^[[:space:]]*//'
}

func_print () {
	local FN=${1}
	local FUNC=$(str_trim ${2})
	
	perl -ne "print if /^${FUNC}.*() {/ .. /^}$/" ${FN} | perl -pe 's/^}$/}\n/g'
}

func_normalize () {
	local FN=${1}

	perl -pe 's/^(function\s+)(.*) (\{.*)/${2} () ${3}/g; s/([a-z])(\(\))/${1} ${2}/g; s/\(\) \(\)/\(\)/g; s/(^})(.*)/${1}/g' < ${FN} > ${FN}.normalized
}

get_delim_field_cnt () {
	local DELIM_ROW=${@}
	local FCNT=0
	local DELIM=$(parse_find_valid_delim ${DELIM_ROW})

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	if [[ -n ${DELIM} ]];then
		FCNT=$(echo ${DELIM_ROW} | grep -o ${DELIM} | wc -l)
		echo ${FCNT}
		return 0
	else
		return 1
	fi
}

reset_rate () {
	eval "xset ${_XSET_DEFAULT_RATE}"
}

get_keys () {
	local PROMPT=${@}
	local -a NUM
	#local IDLE_PPID=$(cut -d '|' -f1 < <(idle_ppid))
	local IDLE_TIME=0
	local K1=''
	local K2=''
	local K3=''
	local KEY=''
	local MY_PPID=${PPID}
	local RATE=0
	local RESP=?;
	local XSET_DATA=''

	trap reset_rate INT

	while true;do
		if [[ ${IDLE_TIME} -le 1000 ]];then
			if [[ ${XSET_DATA} != ${_XSET_LOW_RATE} ]];then
				eval "xset ${_XSET_LOW_RATE}" # Keyboard Active
				XSET_DATA="${_XSET_LOW_RATE}"
			fi
		else
			if [[ ${XSET_DATA} != ${_XSET_DEFAULT_RATE} ]];then
				eval "xset ${_XSET_DEFAULT_RATE}" # Keyboard Inactive
				XSET_DATA="${_XSET_DEFAULT_RATE}"
			fi
		fi

		KEY=''; K1=''; K2=''; K3=''

		while read -t1 -sk1 KEY;do
			# Slurp input buffer
			read -sk1 -t 0.0001 K1 >/dev/null 2>&1
			read -sk1 -t 0.0001 K2 >/dev/null 2>&1
			read -sk1 -t 0.0001 K3 >/dev/null 2>&1
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
					case ${RESP} in
						<48-57>) RESP=${KEY};; # Numeric
						<65-122>) RESP=${KEY};; # Alpha
					esac
					echo ${RESP}
				else
					echo "K${(j::)NUM}"
				fi
				if [[ -n ${KEY} ]];then
					reset_rate
					break 2
				else
					continue
				fi
			fi
		done
		RATE=$(xset -q | grep rate | tr -d '[:space:]' | cut -d: -f3)
		IDLE_TIME=$(xprintidle)
	done
	trap - INT # key processed; cancel trap
}

#get_keys () {
#	local PROMPT
#	local RESP=?;
#	local -a NUM
#	local K1 K2 K3 KEY
#
#	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"
#
#	PROMPT=${@}
#
#	(tput cup $((_MAX_ROWS-2)) 0;printf "${PROMPT}")>&2 # Position cursor and display prompt to STDERR
#
#	[[ ${XDG_SESSION_TYPE:l} == 'x11' ]] && eval "xset ${_XSET_LOW_RATE}"
#
#	{
#	while read -sk1 KEY;do
#		[[ -z ${KEY} ]] && break
#		# Slurp input buffer
#		read -sk1 -t 0.0001 K1 >/dev/null 2>&1
#		read -sk1 -t 0.0001 K2 >/dev/null 2>&1
#		read -sk1 -t 0.0001 K3 >/dev/null 2>&1
#		KEY+=${K1}${K2}${K3}
#
#		case "${KEY}" in 
#			$'\x0A') RESP=0;; # Return
#			$'\e[A') RESP=1;; # Up
#			$'\e[B') RESP=2;; # Down
#			$'\e[D') RESP=3;; # Left
#			$'\e[C') RESP=4;; # Right
#			$'\e[5~') RESP=5;; # PgUp
#			$'\e[6~') RESP=6;; # PgDn
#			$'\e[H') RESP=7;; # Home
#			$'\e[F') RESP=8;; # End
#			$'\x7F') if [[ ${#NUM} -gt 0 ]];then # BackSpace
#							NUM[${#NUM}]=()
#							echo -n " ">&2
#						fi;;
#			*) RESP=$(printf '%d' "'${KEY}");; # Ascii letter value
#		esac
#
#		if [[ ${RESP} != "?" ]];then
#			if [[ -z ${NUM} ]];then
#				case ${RESP} in
#					<48-57>) RESP=${KEY};; # Numeric
#					<65-122>) RESP=${KEY};; # Alpha
#				esac
#				echo ${RESP}
#			else
#				echo "K${(j::)NUM}"
#			fi
#			eval "xset ${_XSET_DEFAULT_RATE}"
#			break
#		fi
#	done
#	} 2>/dev/null
#
#	[[ ${XDG_SESSION_TYPE:l} == 'x11' ]] && eval "xset ${_XSET_DEFAULT_RATE}"
#}

inline_vi_edit () {
	local PROMPT=${1}
	local CUR_VALUE=${2}
	local PERL_SCRIPT
	
	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	read -r -d '' PERL_SCRIPT <<'___EOF'
	use warnings;
	use strict;
	use Term::ReadLine;

	my $term = new Term::ReadLine 'list_search';
	$term->parse_and_bind("set editing-mode vi");

	system('sleep .1;xdotool key Home &');
	while ( defined ($_ = $term->readline($ARGV[0],$ARGV[1])) ) {
		print $_;
		exit;
	}
___EOF

perl -e "$PERL_SCRIPT" ${PROMPT} ${CUR_VALUE}
}

is_bare_word () {
	local TEXT="${@}"

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${TEXT} =~ '\*' || ${TEXT} =~ '\~' || ${TEXT} =~ '^/.*' ]] && return 1

	if [[ ${_BAREWORD_IS_FILE} == 'false' ]];then # Bare words should be tested as possible file and dir names
		[[ -f ${TEXT:Q} || -d ${TEXT:Q} ]] && return 1 || return 0
	fi
}

is_dir () {
	local TEXT="${@}"

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	TEXT=$(eval "echo ${TEXT}")
	[[ -d ${TEXT} ]] && return 0 || return 1
}

is_empty_dir () {
	local DIR=${1}

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ -d ${DIR} ]] && return $(ls -A ${DIR} | wc -l)
}

is_file () {
	local TEXT="${@}"

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ -f ${TEXT:Q} ]] && return 0 || return 1
}

is_glob () {
	local TEXT="${@}"

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${TEXT:Q} =~ '\*' ]] && return 0 || return 1
}

is_singleton () {
	local EXEC_NAME=${1}
	local INSTANCES=$(pgrep -fc ${EXEC_NAME})

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${INSTANCES} -eq 0 ]] && return 0 || return 1
}

is_symbol_dir () {
	local ARG=${1}

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${ARG} =~ '^[\.~]$' ]] && return 0 || return 1
}

kbd_activate () {
	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${XDG_SESSION_TYPE:l} != 'x11' ]] && return 0

	local KEYBOARD_DEV=$(kbd_get_keyboard_id)

	xinput reattach ${KEYBOARD_DEV} 3
}

kbd_get_keyboard_id () {
	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${XDG_SESSION_TYPE:l} != 'x11' ]] && return 0

	local KEYBOARD_DEV=$(xinput list | grep  "AT Translated" | cut -f2 | cut -d= -f2)

	echo ${KEYBOARD_DEV}
}

kbd_suspend () {
	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${XDG_SESSION_TYPE:l} != 'x11' ]] && return 0

	local KEYBOARD_DEV=$(kbd_get_keyboard_id)

	xinput float ${KEYBOARD_DEV}
}

key_wait () {
	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	echo -n "Press any key..." && read -sk1
}

logit () {
	local MSG=${@}
	local STAMP=$(date +'%Y-%m-%d:%T')

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	echo "${STAMP} ${MSG}" >> ${_LOG:=/tmp/${0}.log}
}

num_byte_conv () {
	local BYTES=${1}
	local WANTED=${2}

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

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

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

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
	local DELIM=''
	local D

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

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

	[[ ${_DEBUG} -ge ${_UTILS_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	echo -n ${LINE} | rev | cut -d"${DELIM}" -f1 | rev
}

max () {
	local N1=${1}
	local N2=${2}

	[[ ${N1} -gt ${N2} ]] && echo ${N1} || echo ${N2} 
}

min () {
	local N1=${1}
	local N2=${2}

	[[ ${N1} -lt ${N2} ]] && echo ${N1} || echo ${N2} 
}
