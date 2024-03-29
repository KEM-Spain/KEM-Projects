#LIB Dependencies
_DEPS_+="MSG.zsh UTILS.zsh"


exit_leave () {
	local MSGS=(${@})

	if [[ ${_DEBUG} -ge 1 ]];then
		dbg "${RED_FG}${0}${RESET}: CALLER:${functrace[1]}"
		dbg "${RED_FG}${0}${RESET}: #_MSGS:${#_MSGS}"
		dbg "${RED_FG}${0}${RESET}: _SOURCED_APP_EXIT:${_SOURCED_APP_EXIT}"
		dbg "${RED_FG}${0}${RESET}: _SMCUP:${_SMCUP}"
	fi

	[[ -n ${MSGS} ]] && _EXIT_MSGS=${MSGS}

	[[ ${_DEBUG} -ge 1 ]] && dbg_msg | mypager && /bin/rm -f ${_DEBUG_FILE}
	
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

	kill -SIGINT $$ # Fire the traps
}

exit_pre_exit () {
	[[ ${_DEBUG} -ge 1 ]] && echo "${RED_FG}${0}${RESET}: CALLER:${functrace[1]}, #_EXIT_MSGS:${#_EXIT_MSGS}"

	if [[ ${XDG_SESSION_TYPE:l} == 'x11' ]];then
		xset r on # Reset key repeat
		eval "xset ${_XSET_DEFAULT_RATE}" # Reset key rate
		[[ ${_DEBUG} -ge 1 ]] && echo "${0}: reset key rate:${_XSET_DEFAULT_RATE}"
	fi

	kbd_activate
	[[ ${_DEBUG} -ge 1 ]] && echo "${0}: activated keyboard"

	[[ ${$(tabs -d | grep --color=never -o "tabs 8")} != 'tabs 8' ]] && tabs 8
	[[ ${_DEBUG} -ge 1 ]] && echo "${0}: reset tabstops"

	if typeset -f _cleanup > /dev/null; then
		[[ ${_DEBUG} -ge 1 ]] && echo "${0}: cleaning up"
		_cleanup
	fi

	[[ ${_DEBUG} -ge 1 ]] && echo "${0}: _EXIT_VALUE:${_EXIT_VALUE}"

	[[ -n ${_EXIT_MSGS} ]] && echo ${_EXIT_MSGS}

	tput cnorm >&2
}

exit_request () {
	local BOX_X=${1}
	local BOX_Y=${2}

	if [[ -n ${BOX_X} && -n ${BOX_Y} ]];then
		msg_box -u -O ${RED_FG} -x ${BOX_X} -y ${BOX_Y} -p "Quit application (y/n)"
	else
		msg_box -O ${RED_FG} -p "Quit application (y/n)"
	fi
	if [[ ${_MSG_KEY} == 'y' ]];then
		if [[ ${_FUNC_TRAP} == 'true' ]];then
			exit_pre_exit
			[[ ${_SMCUP} == 'true' ]] && do_rmcup
			exit 0
		else
			exit_leave
		fi
	fi
	msg_box_clear
}

exit_sigexit () {
	local SIG=${1}
	local SIGNAME
	local -A SIGNAMES=(\
		1 "Terminal vanished" 2 "Control-C" 3 "Core Dump" 4 "Illegal Instruction" 5 "Conditional Exit (DEBUG)" 6 "Emergency Abort"\
		7 "Memory Error" 8 "FLoating Point Exception" 9 "Termination Called from kill"
	)

	# Traps arrive here
	SIGNAME=$(kill -l ${SIG})
	[[ ${_DEBUG} -ge 1 ]] && dbg "${RED_FG}${0}${RESET}: Exited via interrupt: ${SIG} (${SIGNAME}) ${SIGNAMES[${SIG}]}" # Announce the interrupt

	exit_pre_exit # Pre-exit housekeeping

	exit ${_EXIT_VALUE} # Leave the app
}

set_exit_value () {
	_EXIT_VALUE=${1}
}

get_exit_value () {
	echo ${_EXIT_VALUE}
}

