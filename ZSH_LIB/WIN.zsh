# LIB Dependencies
_DEPS_+="DBG.zsh"

# LIB Vars
_WIN_LIB_DBG=5

win_close () {
	local WDW_ID=$(win_xdo_id_fix ${1})

	[[ ${_DEBUG} -ge ${_WIN_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ -z ${1} ]] && echo "$0: Missing argument WDW_ID" && return 1

	xdotool windowclose ${WDW_ID}

	return 0
}

win_focus () {
	local WDW_ID=$(win_xdo_id_fix ${1})

	[[ ${_DEBUG} -ge ${_WIN_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ -z ${1} ]] && echo "$0: Missing argument WDW_ID" && return 1

	xdotool windowfocus ${WDW_ID}
	xdotool windowraise ${WDW_ID}

	return 0
}

win_focus_title () {
	local WIN_NAME=${1}
	local WDW_ID

	[[ ${_DEBUG} -ge ${_WIN_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ -z ${1} ]] && echo "$0: Missing argument WIN_NAME" && return 1

	WDW_ID=$(win_get_id ${WIN_NAME})
	win_focus ${WDW_ID}
}

win_get_id () {
	local WIN_NAME=${1}
	local WDW_ID

	[[ ${_DEBUG} -ge ${_WIN_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

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

	[[ ${_DEBUG} -ge ${_WIN_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ -z ${1} ]] && echo "$0: Missing argument WIN_NAME" && return 1

	WDW_PID=$(pgrep -ifo ${WIN_NAME}) # Case insensitive; full path; oldest

	echo ${WDW_PID}

	return $?
}

win_list () {
	local WIN_NAME=${1}

	[[ ${_DEBUG} -ge ${_WIN_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ -z ${1} ]] && echo "$0: Missing argument WIN_NAME" && return 1

	wmctrl -l | grep -i ${WIN_NAME} >&2

	return $?
}

win_xdo_id_fix () {
	local ID=${1}

	[[ ${_DEBUG} -ge ${_WIN_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ -z ${1} ]] && echo "$0: Missing argument ID" && return 1

	[[ ! ${ID} =~ '^0x0' ]] && sed 's/0x/0x0/g' <<<${ID} || echo ${ID} # Make id xdotool compatible
}

win_xwin_dump () {
	local WIN_NAME=${1}

	[[ ${_DEBUG} -ge ${_WIN_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ -z ${1} ]] && echo "$0: Missing argument WIN_NAME" && return 1

	xwininfo -root -tree | grep -i ${WIN_NAME} >&2

	return $?
}

