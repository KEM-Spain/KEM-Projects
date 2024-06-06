# LIB Dependencies
_DEPS_+="MSG.zsh UTILS.zsh"

# LIB vars
_PRE_EXIT_RAN=false
_EXIT_CALLBACK=''
_EXIT_LIB_DBG=1
_EXIT_REQUEST=false

exit_leave () {
	local MSGS=(${@})

	if [[ ${_DEBUG} -ne 0 ]];then
		dbg "${RED_FG}${0}${RESET}: CALLER:${functrace[1]}"
		dbg "${RED_FG}${0}${RESET}: #_MSGS:${#_MSGS}"
		dbg "${RED_FG}${0}${RESET}: _SOURCED_APP_EXIT:${_SOURCED_APP_EXIT}"
		dbg "${RED_FG}${0}${RESET}: _SMCUP:${_SMCUP}"
		dbg_msg | mypager wait
	fi

	[[ -n ${MSGS} ]] && _EXIT_MSGS=${MSGS}
	
	if [[ ${_APP_IS_SOURCED} == 'true' ]];then
		_SOURCED_APP_EXIT=true
		echo ${MSGS} >&2
		return 9
	fi

	if [[ ${functrace[1]} =~ 'usage' && -z ${MSGS} ]];then
		echo "\n"
		set_exit_value 1
	else
		[[ ${_SMCUP} == 'true' ]] && do_rmcup # Screen restore if not usage
	fi

	tput cnorm >&2

	exit_pre_exit

 # Kill -SIGINT $$ # Fire the traps
	exit ${_EXIT_VALUE}
}

exit_pre_exit () {
	[[ ${_PRE_EXIT_RAN} == 'true' ]] && return
	
	_PRE_EXIT_RAN=true

	[[ ${_DEBUG} -ge ${_EXIT_LIB_DBG} ]] && echo "${RED_FG}${0}${RESET}: CALLER:${functrace[1]}, #_EXIT_MSGS:${#_EXIT_MSGS}"

	if [[ ${XDG_SESSION_TYPE:l} == 'x11' ]];then
		xset r on # Reset key repeat
		eval "xset ${_XSET_DEFAULT_RATE}" # Reset key rate
		[[ ${_DEBUG} -ge ${_EXIT_LIB_DBG} ]] && echo "${0}: reset key rate:${_XSET_DEFAULT_RATE}"
	fi

	kbd_activate
	[[ ${_DEBUG} -ge ${_EXIT_LIB_DBG} ]] && echo "${0}: activated keyboard"

	[[ ${$(tabs -d | grep --color=never -o "tabs 8")} != 'tabs 8' ]] && tabs 8
	[[ ${_DEBUG} -ge ${_EXIT_LIB_DBG} ]] && echo "${0}: reset tabstops"

	if typeset -f _cleanup > /dev/null; then
		[[ ${_DEBUG} -ge ${_EXIT_LIB_DBG} ]] && echo "${0}: cleaning up"
		_cleanup
	fi

	[[ ${_DEBUG} -ge ${_EXIT_LIB_DBG} ]] && echo "${0}: _EXIT_VALUE:${_EXIT_VALUE}"

	[[ -n ${_EXIT_MSGS} ]] && echo "\n${_EXIT_MSGS}"

	[[ -n ${_EXIT_CALLBACK} ]] && ${_EXIT_CALLBACK}

	tput cnorm >&2
}

exit_request () {
	local BOX_X=${1}
	local BOX_Y=${2}
	local MSG="Quit application (y/n)"

	if [[ -n ${BOX_X} && -n ${BOX_Y} ]];then
		msg_box -u -O ${RED_FG} -x ${BOX_X} -y ${BOX_Y} -p ${MSG}
	else
		msg_box -O ${RED_FG} -p ${MSG}
	fi

	if [[ ${_MSG_KEY} == 'y' ]];then
		if [[ ${_FUNC_TRAP} == 'true' ]];then
			exit_pre_exit
			[[ ${_SMCUP} == 'true' ]] && do_rmcup
			exit 0
		else
			exit_leave
		fi
	else
		_EXIT_REQUEST=true
		if [[ ${_LIST_TYPE} == 'classic' ]];then
			list_repaint_section 3 ${_CURRENT_PAGE}
		elif [[ ${_LIST_TYPE} == 'select' ]];then
			selection_list_repaint_section 3 ${_CURRENT_PAGE}
		else
			msg_box_clear
		fi
	fi
}

exit_sigexit () {
	local SIG=${1}
	local SIGNAME=$(kill -l ${SIG})
	local -A SIGNAMES=(\
		1 "Terminal vanished" 2 "Control-C" 3 "Core Dump" 4 "Illegal Instruction" 5 "Conditional Exit (DEBUG)" 6 "Emergency Abort"\
		7 "Memory Error" 8 "FLoating Point Exception" 9 "Termination Called from kill"
	)

	# Traps arrive here
	[[ ${_DEBUG} -ne 0 ]] && echo "\n${RED_FG}${0}${RESET}: Exited via interrupt: ${SIG} (${SIGNAME}) ${SIGNAMES[${SIG}]}" # Announce the interrupt

	exit_pre_exit # Pre-exit housekeeping

	exit ${SIG} # Leave the app
}

set_exit_value () {
	_EXIT_VALUE=${1}
}

get_exit_value () {
	echo ${_EXIT_VALUE}
}

set_exit_callback () {
	_EXIT_CALLBACK=${1}
}
