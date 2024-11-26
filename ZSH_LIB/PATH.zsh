# LIB Dependencies
_DEPS_+="DBG.zsh UTILS.zsh"

# LIB Declarations
typeset -A _ARGS # Holds command line arguments for raw path parsing

# LIB Vars
_RAW_CMD_LINE=false # For testing
_PATH_LIB_DBG=5

# LIB Functions
path_abbv () {
	local MAX_LEN=false
	local OPTIND=0
	local OPTION
	local LINE
	local OPTSTR="l:"
	local LEN_LIMIT

	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	while getopts ${OPTSTR} OPTION;do
		case $OPTION in
		  l) MAX_LEN=${OPTARG};;
		  :) print -u2 "${SCRIPT}: option: -${OPTARG} requires an argument"; usage;;
		 \?) print -u2 "${SCRIPT}: ${BOLD}${RED_FG}Unknown option${RESET} -${OPTARG}"; usage;;
		esac
	done
	shift $((OPTIND -1))

	[[ ${MAX_LEN} != 'false' ]] && LEN_LIMIT=${MAX_LEN} || LEN_LIMIT=60

	if [[ ! -t 0 ]];then
		read -r LINE
	else
		LINE=${1}
	fi

	[[ ${#LINE} -le ${LEN_LIMIT} ]] && printf ${LINE} && return

	echo ${LINE} | perl -wane'
		foreach $w (@F) {
			$w =~ s#/$(?=^/.*)##g;             # Kill if trailing slash if preceded by any chars
			$w =~ s#([^/])([^/]*(?=.*/))#$1#g; # For every word btwn slashes kill all after first char
			$w =~ s/%//g;                      # Kill any percent signs (not sure why)
			push (@line,$w);                   # Build line
		}
		printf("%-s\n", "@line");
	;' 
}

path_expand () {
	local ARG=${@}
	local ARG_TST
	local PATH_TST

	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARG:${ARG}"

	if [[ ${ARG} =~ "^[\.\~]" ]];then # Something to expand
		[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Expanding tilde or dot"
		ARG_TST=${ARG}

		[[ ${ARG_TST} =~ '\*$' ]] && ARG_TST=${ARG_TST:h} # Remove glob

		ARG_TST=$(eval "echo ${ARG_TST}")
		PATH_TST=$(realpath ${ARG_TST})

		[[ -f ${PATH_TST} ]] && echo ${PATH_TST:h} || echo ${PATH_TST} # If it points to a file return only the head
	else
		[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Nothing to expand"
		echo ${ARG}
		return 1
	fi
	return 0
}

path_find_prep () {
	local FLIST
	local NDX=0
	local K
	local HIT=false

	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

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

	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	INODE=$(ls -i ${FN:Q} 2>/dev/null | cut -d' ' -f1 2>/dev/null)

	if [[ -n ${INODE} ]];then 
		echo ${INODE}
		return 0
	else
		[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${RED_FG}Unable to obtain inode${RESET}"
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

	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	RAW_PATH=$(path_get_raw_path)

	[[ ! -d ${RAW_PATH:h} ]] && return 1

	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${0} calling path_expand with: ${RAW_PATH}"
	PATH_EXPANDED=$(path_expand ${RAW_PATH:h})
	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${0} path_expand returned: ${PATH_EXPANDED}"

	[[ -n ${MAX_LEN} ]] && MAX_LEN="-l ${MAX_LEN}" || MAX_LEN=''

	LABEL=$(echo ${PATH_EXPANDED} | path_abbv ${MAX_LEN})
	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Abbreviated ${PATH_EXPANDED} added to label"

	if [[ ${RAW_PATH:t} =~ "^[\.\~]$" ]];then
		TAIL=''
		[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: TAIL is symbolic path - omitted from label"
	elif is_glob ${RAW_PATH:t};then
		TAIL="/${RAW_PATH:t}"
		[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: TAIL is glob - added to label"
	fi

	LABEL=${LABEL}${TAIL}

	echo -n ${LABEL}
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

	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	if [[ ${_DURABLE[TESTMODE]} == 'true' ]];then
		RAW_CMD_LINE=${_RAW_CMD_LINE}
	else
		fc -R
		RAW_CMD_LINE=("${(f)$(fc -lnr | head -1)}") # Parse raw cmdline
	fi

	[[ ${RAW_CMD_LINE} =~ '\|\s+${_SCRIPT}' ]] && echo "Input is piped" && return 1
	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${CYAN_FG}RAW_CMD_LINE:${RAW_CMD_LINE}${RESET}" 

	RAW_CMD_LINE=($(echo ${RAW_CMD_LINE} | perl -p -e 's/[^\s]+//')) # Strip leading word (script name)
	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Stripped command name: RAW_CMD_LINE:${RAW_CMD_LINE}"

	RAW_PATH=$(path_strip_options ${RAW_CMD_LINE}) # Strip options
	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Stripped options: RAW_CMD_LINE:${RAW_CMD_LINE}"

	[[ -z ${RAW_PATH} ]] && PATH_HEAD=. # Empty path resolves to PWD

	if [[ ${PATH_HEAD} == '?' ]];then
		if is_glob ${RAW_PATH};then
			TOKENIZED=("${(f)$(eval ls ${RAW_PATH})}") # Expand glob - a clean file list will resolve PATH_HEAD

			for T in ${TOKENIZED};do
				[[ ! -f ${T} ]] && break
				PATH_HEAD=${T:h}
			done
			[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: RAW_PATH:${RAW_PATH} PATH_HEAD:${PATH_HEAD}"
		fi
	fi

	if [[ ${PATH_HEAD} == '?' ]];then
		TOKENIZED=("${(f)$(path_read_raw ${RAW_PATH})}") # Parse tokens incl names w/ spaces)
		[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Tokenized: TOKENIZED:${TOKENIZED}"

		# Eliminate all bare words from command line
		WORDS=0
		for T in ${TOKENIZED};do
			if is_bare_word "${T}";then
				((WORDS++))
				continue
			else
				TOKENS+=${T}
			fi
		done

		if [[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]];then
			dbg "${functrace[1]} called ${0}:${LINENO}: ${WHITE_FG}RAW_CMD_LINE${RESET}:${RAW_CMD_LINE}"
			dbg "${functrace[1]} called ${0}:${LINENO}: ${WHITE_FG}${WORDS}${RESET} plain words eliminated from command line"
			dbg "${functrace[1]} called ${0}:${LINENO}: ${WHITE_FG}${#TOKENS}${RESET} remaining tokens"
		fi

		RAW_PATH=${TOKENS:=.} # Default to PWD
		[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${RED_FG}RAW_PATH STRIPPED${RESET}:[${WHITE_FG}${RAW_PATH}${RESET}]"

		PATH_EXPANDED=$(path_expand ${RAW_PATH})

		PATH_HEAD=${PATH_EXPANDED}
	fi

	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${GREEN_FG}PATH_HEAD${RESET}:${WHITE_FG}${PATH_HEAD}${RESET} is set"
	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${MAGENTA_FG}Parsing TAIL${RESET}:${RAW_PATH:t}"

	case ${RAW_PATH:t} in
	   '*') PATH_TAIL="-name '*'";[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${WHITE_FG}TAIL is ASTERISK:${RAW_PATH:t}${RESET}";;
		 "") PATH_TAIL="-name '*'";[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${WHITE_FG}TAIL is NULL:${RAW_PATH:t}${RESET}";;
		"~") PATH_TAIL="-name '*'";[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${WHITE_FG}TAIL is TILDE:${RAW_PATH:t}${RESET}";;
		".") PATH_TAIL="-name '*'";[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${WHITE_FG}TAIL is DOT:${RAW_PATH:t}${RESET}";;
		  *)	if is_dir ${RAW_PATH};then
					[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${WHITE_FG}PATH is DIR:${RAW_PATH}${RESET}"
					PATH_TAIL="-name '*'"
				elif is_file ${PATH_HEAD}/${RAW_PATH:t};then
					[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${WHITE_FG}HEAD/TAIL is FILE:${PATH_HEAD}/${RAW_PATH:t}${RESET}"
					I=$(path_get_inode "${PATH_HEAD}/${RAW_PATH:t}")
					[[ ${?} -eq 0 ]] && PATH_TAIL="-inum ${I}" || PATH_TAIL='?' # Fallback to prevent empty inode being passed
				elif is_dir ${PATH_HEAD}/${RAW_PATH:t};then
					[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${WHITE_FG}HEAD/TAIL is DIR:${PATH_HEAD}/${RAW_PATH:t}${RESET}"
					PATH_TAIL="-name '${RAW_PATH:t}'"
				elif is_glob ${RAW_PATH:t};then
					[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${WHITE_FG}TAIL is GLOB:${RAW_PATH:t}${RESET}"
					PATH_TAIL="-name '${RAW_PATH:t}'"
				else
					PATH_TAIL=?
				fi;;
	esac

	if [[ ${PATH_TAIL} = '?' ]];then
		# Echo "PATH_TAIL is unknown; Parsing ${#TOKENIZED} TOKENS:${TOKENIZED}" >&2
		for T in ${TOKENIZED};do
			if is_file "${T}" || is_dir "${T}";then
				I=$(path_get_inode ${T})
				[[ ${?} -ne 0 ]] && dbg "${RED_FG}BAD INODE CALL${RESET}" && FNDX=0 && break  # Bad inode call
				((FNDX++))
				_ARGS[list${FNDX}]=${I} # Gather all items on command line
			else
				[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "TOKEN is neither file nor dir"
			fi
		done
		if [[ ${FNDX} -ne 0 ]];then
			PATH_HEAD=$(realpath $(eval echo ${RAW_PATH:h}))
			PATH_TAIL=$(path_find_prep) # Prepare for find command
		fi
	fi

	if [[ ${PATH_TAIL} == '?' && ${FNDX} -eq 0 ]];then
		[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "No TOKENS were valid paths or files (invalid path or file name)" >&2
		echo "${PATH_HEAD}|Invalid Path:${RAW_PATH}" # Return result
		return 1
	fi

	if [[ ${PATH_HEAD} = '?' || ${PATH_TAIL} = '?' ]];then
		[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${RED_FG}Unable to parse command line${RESET}"
		return 1
	fi

	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${CYAN_FG}PATH_HEAD:${PATH_HEAD} PATH_TAIL:${PATH_TAIL}${RESET}" 

	PATH_HEAD=$(realpath ${PATH_HEAD})

	echo -n "${PATH_HEAD}|${PATH_TAIL}" # Return result
	return 0
}

path_get_raw_cmdline () {
	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	fc -R
	local RAW_CMD_LINE=("${(f)$(fc -lnr | head -1)}") # Parse raw cmdline

	echo ${RAW_CMD_LINE}
}

path_get_raw_path () {
	local RAW_CMD_LINE
	local -a TOKENIZED
	local -a TOKENS
	local A
	local RAW_PATH

	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	fc -R
	RAW_CMD_LINE=("${(f)$(fc -lnr | head -1)}") # Parse raw cmdline
	[[ ${RAW_CMD_LINE} =~ '\|' ]] && echo "Input is piped" && return 0
	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${CYAN_FG}RAW_CMD_LINE:${RAW_CMD_LINE}${RESET}" 

	RAW_CMD_LINE=($(echo ${RAW_CMD_LINE} | perl -p -e 's/[^\s]+//')) # Strip leading word (script name)

	RAW_PATH=$(path_strip_options ${RAW_CMD_LINE}) # Strip options
	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${CYAN_FG}RAW_PATH:${RAW_PATH} (removed script name & options)${RESET}" 

	TOKENIZED=("${(f)$(path_read_raw ${RAW_PATH})}") # Read whole lines (non-traditional file/dir names - spaces)

	for A in ${TOKENIZED};do
		if is_bare_word "${A}";then
			continue
		else
			TOKENS+=${A}
		fi
	done
	RAW_PATH=(${TOKENS:=.}) # Default empty path to '.'

	echo -n ${RAW_PATH}
}

path_read_raw () {
	local RAWCMD=${@}
	local -a TEXT
	local LINE
	local L

	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	while read -r LINE;do
		TEXT+=${LINE}
	done < <(path_split_fn ${RAWCMD})

	for L in ${TEXT};do
		echo ${L}
	done
}

path_split_fn () {
	local TEXT="${@}"

	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	perl -pe 's/(?<![\\])[ ]/\n/g' <<<${TEXT}
}

path_strip_options () {
	local LINE=${@}

	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	while true;do # Strip options
        grep -qP '^\-\w+' <<<${LINE}
        [[ ${?} -ne 0 ]] && break
        LINE=$(echo ${LINE} | perl -pe 's/(-\w+)\s+(.*)/\2/g')
	done

	echo ${LINE}
}

path_trailing_segs () {
	local DIR_SLICE=${1}
	local TARGET=${2}
	local SEGS=(${(s:/:)${DIR_SLICE}})
	local -A SEG_NDX
	local NDX=0
	local OUT
	local S

	[[ ${_DEBUG} -ge ${_PATH_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	for S in ${SEGS};do
		((NDX++))
		SEG_NDX[${NDX}]=${S}
	done

	OUT=''
	for ((S=${#SEG_NDX}; S>$((${#SEG_NDX}-TARGET)); S--));do
		OUT=${SEG_NDX[${S}]}/${OUT}
		[[ ${S} -lt 1 ]] && break
	done
	echo ${OUT[1,-2]}
}

