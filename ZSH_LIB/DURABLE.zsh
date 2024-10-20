# LIB Dependencies
_DEPS_+="DBG.zsh"

# LIB Declarations
typeset -A _DURABLE # Holds variable values that can survive a subshell

# LIB Vars
_DURABLE_LIB_DBG=5

durable_array () {
	local NAME=${1}
	local LINE
	local KEY
	local VAL

	[[ ${_DEBUG} -ge ${_DURABLE_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	if [[ -e /tmp/${NAME} ]];then
		while read LINE;do
			KEY=$(cut -d: -f1 <<<${LINE})
			VAL=$(cut -d: -f2 <<<${LINE})
			_DURABLE[${KEY}]=${VAL}
		done < /tmp/${NAME}
	else
		return 1
	fi
}

durable_get () {
	local NAME=${1}
	local KEY=${2}
	local VAL

	[[ ${_DEBUG} -ge ${_DURABLE_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	if [[ -e /tmp/${NAME} ]];then
		VAL=$(grep --color=never "${KEY}:" < /tmp/${NAME} | cut -d: -f2)
		rm -f /tmp/${NAME}
	else
		return 1
	fi

	echo -n ${VAL}
	return 0
}

durable_set () {
	local NAME=${1}
	local KEY=${2}
	local VAL="${3}"

	[[ ${_DEBUG} -ge ${_DURABLE_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	# Remove old value
	if [[ -e /tmp/${NAME} ]];then
		sed -i "/${KEY}:/d" /tmp/${NAME}
	fi

	# Add new value
	echo "${KEY}:${VAL}" >> /tmp/${NAME}
	return 0
}

