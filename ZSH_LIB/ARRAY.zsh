# LIB Dependencies
_DEPS_+="DBG.zsh MSG.zsh STR.zsh"

# LIB Vars
_ARRAY_LIB_DBG=5

# LIB Functions
arr_get_nonzero_count () {
	local -a A=(${@})
	local CNT=0
	local E

	[[ ${_DEBUG} -ge ${_ARRAY_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	for E in ${A};do
		[[ ${E} -ne 0 ]] && ((CNT++))
	done

	echo ${CNT}
}

arr_get_populated_count () {
	local -a A=(${@})
	local CNT=0
	local E

	[[ ${_DEBUG} -ge ${_ARRAY_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	for E in ${A};do
		[[ -n ${E} ]] && ((CNT++))
	done

	echo ${CNT}
}

arr_is_populated () {
	local -a ARR=(${@})
	local RC
	
	[[ ${_DEBUG} -ge ${_ARRAY_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}, ARR:${#ARR}"
	[[ ${_DEBUG} -ge ${_ARRAY_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARR:${ARR}"

	[[ ${#} -eq 0 ]] && echo "${0}: ${RED_FG}requires an argument${RESET} of type <ARRAY> ${#}" >&2

	[[ ${ARR[@]} =~ "^ *$" ]] && RC=1 || RC=0

	[[ ${_DEBUG} -ge ${_ARRAY_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Returning:${RC}"

	return ${RC}
}

arr_long_elem () {
	local LIST=(${@})
	local LONGEST=0
	local LONGEST_STR
	local STR
	local L

	[[ ${_DEBUG} -ge ${_ARRAY_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	for L in ${LIST};do
		STR=$(msg_nomarkup ${L})
		STR=$(str_strip_ansi <<<${STR})
		STR=$(str_trim ${STR})
		[[ ${#STR} -ge ${LONGEST} ]] && LONGEST=${#STR} && LONGEST_STR=${STR}
	done

	[[ ${_DEBUG} -ge ${_ARRAY_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: LONGEST ELEMENT:${LONGEST} STR:${STR}"

	echo ${LONGEST_STR} # Trimmed/no markup
}

arr_long_elem_len () {
	local LIST=(${@})
	local LONGEST=0
	local STR
	local L

	for L in ${LIST};do
		STR=$(msg_nomarkup ${L})
		STR=$(str_strip_ansi <<<${STR})
		STR=$(str_trim ${STR})
		[[ ${#STR} -ge ${LONGEST} ]] && LONGEST=${#STR}
	done

	[[ ${_DEBUG} -ge ${_ARRAY_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  LONGEST ELEMENT LEN:${LONGEST}"

	echo ${LONGEST} # Trimmed/no markup
}

in_array () {
	local ELEMENT=${1};shift
	local -a ALIST=($(tr '\x0a' ' ' <<<${@}))
	local L

	[[ -z ${ALIST} ]] && return 1

	[[ ${_DEBUG} -ge ${_ARRAY_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@} ELEMENT:${ELEMENT} ALIST=${ALIST}"

	for L in ${ALIST};do
		[[ ${L} == ${ELEMENT} ]] && return 0
	done

	return 1
}

