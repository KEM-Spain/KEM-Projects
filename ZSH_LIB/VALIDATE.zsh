# LIB Dependencies
_DEPS_+="DBG.zsh"

# LIB Vars
_VALIDATE_LIB_DBG=5

validate_is_integer () {
	local VAL=${1}
	local RET

	[[ ${_DEBUG} -ge ${_VALIDATE_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

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

	[[ ${_DEBUG} -ge ${_VALIDATE_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${ITEM_NDX} -gt 0 && ${ITEM_NDX} -le ${MAX_ITEM} ]] && return 0 || return 1
}

validate_is_number () {
	local NDX=${1}

	[[ ${_DEBUG} -ge ${_VALIDATE_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	if [[ -n ${NDX} && ${NDX} == ${NDX%%[!0-9]*} ]];then
		return 0
	else
		return 1
	fi
}

