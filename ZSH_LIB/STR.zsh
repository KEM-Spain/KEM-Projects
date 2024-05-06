#LIB Dependencies
_DEPS_+="TPUT.zsh DBG.zsh"

#LIB Vars
_STR_LIB_DBG=5

str_array_to_num () {
	local -a STR=(${@})
	local MAX=${#STR}
	local NUM=0
	local MAG=0
	local S

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

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

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: WIDTH:${WIDTH} TEXT:${TEXT} TEXT_WIDTH:${TEXT_WIDTH}"

	REM=$(( WIDTH-${TEXT_WIDTH} ))
	BORDER=' ' # Minimum border
	if [[ ${REM} -ne 0 ]];then
		PAD=$(( REM/2 ))
		BORDER=$(printf ' %.0s' {1..${PAD}})
	fi

	MSG="${BORDER}${TEXT}${BORDER}" # Pad

	[[ ${#MSG} -lt ${WIDTH} ]] && MSG=$(str_pad_string ${WIDTH} ${MSG})
	[[ ${#MSG} -gt ${WIDTH} ]] && MSG=${MSG[1,${WIDTH}]} # Do not exceed width

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && echo "${WHITE_FG}\nLeaving${RESET}:${0} with [${MSG}] Length:${#MSG}" >&2 

	echo "${MSG}"
}

str_center_pad () {
	local -i PAD
	local -i REM
	local BORDER=' ' # Minimum border
	local MSG 
	local TEXT 
	local TEXT_WIDTH
	local WIDTH

	WIDTH=${1};shift
	TEXT=${@}
	TEXT_WIDTH=${#TEXT}
	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: WIDTH:${WIDTH} TEXT_WIDTH:${TEXT_WIDTH} TEXT:${TEXT}"

	REM=$((WIDTH-TEXT_WIDTH))
	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: WIDTH-TEXT_WIDTH:$((WIDTH-TEXT_WIDTH)) REM:${REM}"

	if [[ ${REM} -ne 0 ]];then
		[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: REM:${REM}"
		PAD=$(( REM/2 ))
		BORDER=$(printf ' %.0s' {1..${PAD}})
		[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: PAD:${PAD}"
	fi
	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: BORDER:${#BORDER}:[${BORDER}] WIDTH-(PAD+TEXT_WIDTH+2):$(( WIDTH - (PAD+TEXT_WIDTH+2) ))"

	echo "${BORDER}"
}

str_clean_line_len () {
	local STR_IN=${@}
	local LENGTH

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	LENGTH=$(echo ${STR_IN} | sed -e 's/\x1b\[[0-9;]*m//g' -e 's/ *$//g' | tr -d '\011\012\015') # Ansi/trailing sp/newlines/etc
	echo ${#LENGTH}
}

str_clean_path () {
	local DIR=${1}

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	echo "${DIR}" | perl -pe 's#/+#/# G'
}

str_expanded_length () {
	local STR=${@}
	local LEN

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	LEN=$(expand <<<${STR} | wc -m)
	echo $((--LEN))
}

str_from_hex () {
	local HEX=${@}

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ -n ${HEX} ]] && printf $HEX
}

str_pad_digit () {
	local NDX=${1}

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${NDX} -lt 10 ]] && echo "  ${NDX}" && return
	[[ ${NDX} -lt 100 ]] && echo " ${NDX}" && return
	[[ ${NDX} -lt 1000 ]] && echo "${NDX}" && return
}

str_pad_string () {
	local WIDTH
	local STR

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	WIDTH=${1};shift
	STR=${@}
	STR="${STR}$(str_rep_char ' ' $((WIDTH-${#STR})))"

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Returning with:${WHITE_FG}[${STR}]${RESET}" >&2 

	echo ${STR}
}

str_pluralize () {
	local WORD=${1}
	local CNT=${2}
	local RETURN_BOTH=${3:=false} # Any 3rd arg triggers 
	local RETURN_WORD

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@} WORD:${WORD}"

	if [[ ${CNT} -eq 1 ]];then
		[[ ${RETURN_BOTH} == 'false' ]] && echo "${WORD}" || echo "${CNT} ${WORD}"
		return
	fi

	case ${WORD:l} in
		app) RETURN_WORD="apps";;
		choice) RETURN_WORD="choices";;
		command) RETURN_WORD="commands";;
		config) RETURN_WORD="configs";;
		country) RETURN_WORD="countries";;
		day) RETURN_WORD="days";;
		device) RETURN_WORD="devices";;
		directory) RETURN_WORD="directories";;
		download) RETURN_WORD="downloads";;
		duplicate) RETURN_WORD="duplicates";;
		entry) RETURN_WORD="entries";;
		file) RETURN_WORD="files";;
		function) RETURN_WORD="functions";;
		item) RETURN_WORD="items";;
		library) RETURN_WORD="libraries";;
		link) RETURN_WORD="links";;
		line) RETURN_WORD="lines";;
		log) RETURN_WORD="logs";;
		match) RETURN_WORD="matches";;
		object) RETURN_WORD="objects";;
		option) RETURN_WORD="options";;
		package) RETURN_WORD="packages";;
		process) RETURN_WORD="processes";;
		reminder) RETURN_WORD="reminders";;
		row) RETURN_WORD="rows";;
		title) RETURN_WORD="titles";;
		torrent) RETURN_WORD="torrents";;
		track) RETURN_WORD="tracks";;
		video) RETURN_WORD="videos";;
		was) RETURN_WORD="were";;
		*) RETURN_WORD=${WORD};;
	esac

	[[ ${WORD} == ${(C)WORD} ]] && RETURN_WORD=${(C)RETURN_WORD} || RETURN_WORD=${RETURN_WORD}

	if [[ ${WORD} == ${WORD:u} ]];then # Assume uppercase
		RETURN_WORD=${RETURN_WORD:u}
	else # Assume mixed or lowercase
		RETURN_WORD=${RETURN_WORD}
	fi

	[[ ${RETURN_BOTH} == 'false' ]] && echo "${RETURN_WORD}" || echo "${CNT} ${RETURN_WORD}"
}

str_rep_char () {
	local CHAR=${1}
	local LENGTH=${2}
	local LINE
	local X

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	LINE=''
	for ((X=0;X < ${LENGTH};X++));do
		LINE=${LINE}''${CHAR}
	done

	echo ${LINE}
}

str_strip_ansi () {
	local LINE_IN
	local LINE_OUT
	local LEN

	local OPTION
	local OPTSTR=":l"
	local REPLY
	local RETURN_LEN=false

	OPTIND=0

	while getopts ${OPTSTR} OPTION;do
		case ${OPTION} in
			l) RETURN_LEN=true;;
			:) print -u2 " ${_SCRIPT}: option: -${OPTARG} requires an argument" >&2;read ;;
			\?) print -u2 " ${_SCRIPT}: ${0}: unknown option -${OPTARG}" >&2; read;;
		esac
	done
	shift $((OPTIND -1))

	IFS='' #preserve white space
	while read -r LINE_IN;do
		# Strip ansi escape chars
		[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  LINE_IN:\"${LINE_IN}\""
		LINE_OUT+=$(perl -pe 's/\x1B\[+[\d;]*[mK]//g' <<<${LINE_IN})
		[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  LINE_OUT:\"${LINE_OUT}\""
	done

	LEN=${#LINE_OUT}

	if [[ ${RETURN_LEN} == 'true' ]];then
		echo ${LEN}
	else
		echo ${LINE_OUT}
	fi
}

str_to_hex () {
	local TXT=${@}

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	echo $TXT | od -An -tx1 | tr -d '[\n]' | sed 's/ /\\x/g' 
}

str_trim () {
	local TEXT_IN=${@}
	local TEXT

		[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"
		[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: TEXT_IN:\"${TEXT_IN}\""

		if [[ -z ${TEXT_IN} && ! -t 0 ]];then
			read TEXT
			[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  TEXT_IN:\"${TEXT}\""
			TEXT=$(sed 's/\t/ /g' <<<${TEXT}) # tabs distort output
			TEXT=$(sed 's/^ *//' <<<${TEXT}) # leading spaces
			TEXT=$(sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//' <<<${TEXT})
			[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  TEXT_OUT:\"${TEXT}\""
			echo ${TEXT}
		else
			TEXT_IN=$(sed 's/\t/ /g' <<<${TEXT_IN}) # tabs distort output
			TEXT_IN=$(sed 's/^ *//' <<<${TEXT_IN}) # leading spaces
			TEXT_IN=$(sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//' <<<${TEXT_IN})
			[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  TEXT_OUT:\"${TEXT_IN}\""
		echo ${TEXT_IN}
	fi
}

str_truncate () {
	local LENGTH=${1} && shift
	local TEXT=${@}

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@} LENGTH:${LENGTH}"

	echo ${TEXT[1,${LENGTH}]}
}

str_unicode_line () {
	local LENGTH=${1}
	local HORIZ_BAR="\\u2500%.0s"

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@} LENGTH:${LENGTH}"

	printf "\\u2500%.0s" {1..$((${LENGTH}))}
}

str_unpipe () {
	local FIELD
	local CUT_PARAM
	local PIPE_DATA

	[[ ${_DEBUG} -ge ${_STR_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${#} -gt 1 ]] && FIELD=${1} && shift
	PIPE_DATA=${@}

	[[ -n ${FIELD} ]] && CUT_PARAM="-f${FIELD}" || CUT_PARAM="-f1-" 
	cut --output-delimiter=' ' -d'|' ${CUT_PARAM} <<<${PIPE_DATA}
}

