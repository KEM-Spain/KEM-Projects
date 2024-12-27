# LIB Dependencies
_DEPS_+="DBG.zsh"

# LIB Vars
_CURSOR=''
_SMCUP=''
_TPUT_LIB_DBG=5
_TERM=xterm

# LIB Functions
coord_center () {
	local AREA=${1}
	local OBJ=${2}
	local CTR
	local REM
	local AC
	local OC

	[[ ${_DEBUG} -ge ${_TPUT_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	CTR=$((AREA / 2))
	REM=$((CTR % 2))
	[[ ${REM} -ne 0 ]] && AC=$((CTR+1)) || AC=${CTR}

	CTR=$((OBJ / 2))
	REM=$((CTR % 2))
	[[ ${REM} -ne 0 ]] && OC=$((CTR+1)) || OC=${CTR}

	echo $((AC-OC+1))
}

cursor_home () {
	[[ ${_DEBUG} -ge ${_TPUT_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	tput -T ${_TERM} cup $(tput lines) 0
}

cursor_off () {
	[[ ${_DEBUG} -ge ${_TPUT_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	tput -T ${_TERM} civis >&2 # Hide cursor
	_CURSOR=off
}

cursor_on () {
	[[ ${_DEBUG} -ge ${_TPUT_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	tput -T ${_TERM} cnorm >&2 # Normal cursor
	_CURSOR=on
}

cursor_restore () {
	[[ ${_DEBUG} -ge ${_TPUT_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	tput -T ${_TERM} rc # Save cursor
}

cursor_row () {
	[[ ${_DEBUG} -ge ${_TPUT_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

  echo -ne "\033[6n" > /dev/tty
  read -t 1 -s -d 'R' line < /dev/tty
  line="${line##*\[}"
  line="${line%;*}"
  echo $((line - 2))
}

cursor_save () {
	[[ ${_DEBUG} -ge ${_TPUT_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	tput -T ${_TERM} sc # Save cursor
}

do_rmcup () {
	[[ ${_DEBUG} -ge ${_TPUT_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${_SMCUP} == 'false' ]] && return
	tput -T ${_TERM} rmcup
	_SMCUP=false
}

do_smcup () {
	[[ ${_DEBUG} -ge ${_TPUT_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${_SMCUP} == 'true' ]] && return
	tput -T ${_TERM} smcup
	_SMCUP=true
}

tcup () {
	X=${1:=0}
	Y=${2:=0}

	[[ ${_DEBUG} -ge ${_TPUT_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	tput -T ${_TERM} cup ${X} ${Y}
}

