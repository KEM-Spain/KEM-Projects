#LIB Dependencies
TERM=${TERM:=xterm}
_DEPS_+="DBG.zsh"

#LIB Vars
_CURSOR=''
_SMCUP=''

coord_center () {
	local AREA=${1}
	local OBJ=${2}
	local CTR
	local REM
	local AC
	local OC

	[[ ${_DEBUG} -ge 2 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	CTR=$((AREA / 2))
	REM=$((CTR % 2))
	[[ ${REM} -ne 0 ]] && AC=$((CTR+1)) || AC=${CTR}

	CTR=$((OBJ / 2))
	REM=$((CTR % 2))
	[[ ${REM} -ne 0 ]] && OC=$((CTR+1)) || OC=${CTR}

	echo $((AC-OC))
}

cursor_off () {
	tput civis >&2 # Hide cursor
	_CURSOR=off
}

cursor_on () {
	tput cnorm >&2 # Normal cursor
	_CURSOR=on
}

cursor_row () {
  echo -ne "\033[6n" > /dev/tty
  read -t 1 -s -d 'R' line < /dev/tty
  line="${line##*\[}"
  line="${line%;*}"
  echo $((line - 2))
}

cursor_home () {
	tput cup $(tput lines) 0
}

cursor_save () {
	tput sc # Save cursor
}

cursor_restore () {
	tput rc # Save cursor
}

do_rmcup () {
	[[ ${_SMCUP} == 'false' ]] && return
	tput rmcup
	# Echo "called rmcup"
	_SMCUP=false
}

do_smcup () {
	[[ ${_SMCUP} == 'true' ]] && return
	# Echo "calling smcup"
	tput smcup
	_SMCUP=true
}
