#!/usr/bin/env zsh

# Inline ansi
BOLD="\033[1m"
ITALIC="\033[3m"
RESET="\033[m"
REVERSE="\033[7m"
STRIKE="\033[9m"
UNDER="\033[4m"

BLACK_BG="\033[40m"

BLUE_FG="\033[34m"
CYAN_FG="\033[36m"
GREEN_FG="\033[32m"
MAGENTA_FG="\033[35m"
RED_FG="\033[31m"
WHITE_FG="\033[37m"
YELLOW_FG="\033[33m"

# Constants
PATH=${PATH}:/usr/local/bin/system # add custom utils
PATH=${PATH}:/snap/bin # add snaps
PATH=${PATH}:/usr/local/bin/_perl.local # add local perl
_REL=$(lsb_release -d | cut -d: -f2- | sed 's/^[ \t]*//')
_RLBL=$(lsb_release -c | cut -d: -f2- | sed 's/^[ \t]*//')
_USR_LOCAL_SRC=/usr/local/src
_CMP_FUNCTIONS=/home/kmiller/.zsh/completions
_SYS_FUNCTIONS=/etc/zsh/system_wide/functions
_MOTD_DIR=/etc/update-motd.d
_SYS_ALIASES=/etc/zsh/aliases
_SYS_ZSHRC=/etc/zsh/zshrc
_WIFI_PREF="WiFi_OliveNet-Casa 7_5G"
_BATT_LIMIT=95
_CAL_LINES=9
_TERMS=$(terms -c)

# Declarations
typeset -a _MOTD=()
typeset -U path cdpath fpath manpath # automatically remove duplicates from these arrays

# Imports 
source ${_SYS_ALIASES}
source ${_SYS_ZSHRC}
source ${_USR_LOCAL_SRC}/fast-syntax-highlighting/F-Sy-H.plugin.zsh # fast-syntax-highlighting.plugin
source ${_USR_LOCAL_SRC}/zhooks/zhooks.plugin.zsh # add zhooks command to display active hooks
TERM=xterm-256color

# Exports
export GREP_COLORS='ms=01;31:mc=01;31:sl=:cx=:fn=97:ln=32:bn=32:se=36' # https://askubuntu.com/questions/1042234/modifying-the-color-of-grep
export HISTORY_IGNORE="(rm(| *)|cd(| *)|ls(| *)|tail(| *)|tvi(| *)|cp(| *)|mv(| *)|exit(| *))"
export MUSIC_DIR=/media/kmiller/KEM_Misc/Music/KEM-B9
export PRINTER=ENVY-5000
export TERM=xterm
export DEFAULT_PLAYER=CLMN
export PYDEVD_DISABLE_FILE_VALIDATION=1

[[ -o login ]] && LOGIN=login || LOGIN=''

# Functions 
_cursor_row () {
	local ROW

	echo -ne "\033[6n" > /dev/tty
	read -t 1 -s -d 'R' ROW < /dev/tty
	ROW="${ROW# #*\[}"
	ROW="${ROW%;*}"
	((ROW--))
	echo ${ROW}
}

_cursor_on () {
	tput cnorm
}

_reload_aliases () {
	local LAST_ALIAS_REFRESH=0
	local CURR_ALIAS_TIME
	local STAMP_FILE=~/.zsh/last_alias_refresh

	[[ -e ${_SYS_ALIASES} ]] || return 1
	[[ -e ${STAMP_FILE} ]] && LAST_ALIAS_REFRESH=$(<${STAMP_FILE})
	CURR_ALIAS_TIME=$(stat -c %Y ${_SYS_ALIASES}) 
	if [[ ${LAST_ALIAS_REFRESH} -lt ${CURR_ALIAS_TIME} ]]; then
		echo "Refreshing aliases..."
		unalias -m '*'
		source ${_SYS_ALIASES}
		echo "${CURR_ALIAS_TIME}" > ${STAMP_FILE}
	fi
}

_reload_funcs () {
	local F
	local FILE
	local HOURS

	MODIFIED=("${(f)$(
		find -L ${_SYS_FUNCTIONS} -type f
		find -L ${_CMP_FUNCTIONS} -type f
	)}")

	NOW=$(date +'%s')
	for F in ${MODIFIED};do
		FILE=$(date +'%s' -r ${F}) # last file mod secs
		HOURS=$(((NOW - FILE)/3600)) # last file mod hours
		if [[ ${HOURS} -le 24 ]];then # today?
			echo "Refreshing functions..."
			unfunction ${F} &> /dev/null
			autoload -Uz ${F}
			sudo touch -d '25 hours ago' $(realpath ${F})
		fi
	done
}

_chrome_restore_tweak () {
	local CHROME_PREF=/home/kmiller/.config/google-chrome/Default/Preferences

	 [[ -e ${CHROME_PREF} ]] || return 1

	RUNNING=$(pgrep -c chrome)
	[[ ${RUNNING} -ne 0 ]] && return 1

	grep -qi 'crashed' ${CHROME_PREF} # check if edit is necessary
	[[ ${?} -ne 0 ]] && return 1
	# echo "Refreshing chrome restore tweak..."
	sudo sed -i 's/Crashed/Normal/g' ${CHROME_PREF} # disable restore session prompt
	return 0
}

_check_updates () {
	sudo chmod 644 ${_MOTD_DIR}/10-help-text # disable

	local -a MSGS_1
	local -a MSGS_2
	local COUNT=0
	local NUM=0
	local M

	MSGS_1+=("${(f)$(sudo run-parts ${_MOTD_DIR})}")

	for M in ${MSGS_1};do
		[[ ${M:l} =~ 'esm' ]] && continue
		[[ ! ${M:l} =~ 'applied' ]] && continue
		NUM=$(cut -d' ' -f1 <<<${M})
		if [[ ${NUM} -gt 0 && ${M} =~ 'applied' ]];then
			(( COUNT += ${NUM} ))
		fi
	done

	MSGS_2=("${(f)$(apt list --upgradable 2>/dev/null)}")

	if [[ ${COUNT} -ne 0 ]];then
		for M in ${MSGS_2};do
			[[ ! ${M:l} =~ 'listing\|done' ]] && continue
			((COUNT++))
		done
	fi

	if [[ ${COUNT} -eq 0 ]];then
		_MOTD+="${ITALIC}No updates available...${RESET}"
	else
		_MOTD+="${GREEN_FG}${BOLD}${ITALIC}Updates available:${RESET}(${WHITE_FG}${COUNT}${RESET})"
	fi
}

_wifi_on () {
	local R=$(nmcli -c no r | tail -1 | cut -d' ' -f1)

	if [[ ! ${R} =~ "enabled" ]];then
		nmcli radio wifi on
		return 1
	fi
	return 0
}

_set_ssid () {

	local SSID=$(wless -s)
	local NTWK=$(nut conn)
	local KEY

	tput sc
	[[ -n ${SSID} ]] && WIFI=" to ${WHITE_FG}${SSID}${RESET}" && echo ${NTWK}${WIFI}

	if [[ ! ${SSID} =~ ${_WIFI_PREF} ]];then
		echo -n "Change wireless to:${WHITE_FG}${_WIFI_PREF}${RESET} [y]es, [n]o [c]hoose:"
		read -sk1 KEY
		if [[ ${KEY:l} == "y" ]];then
			tput rc
			tput ed
			wless -n "${_WIFI_PREF}"
		elif [[ ${KEY:l} == "c" ]];then
			C_POS=$(_cursor_row)
			((C_POS--)) # up 1 line to overwrite prompt
			tput smcup
			wless -cn
			tput rmcup
			SSID=$(wless -s 2>/dev/null)
			[[ -n ${SSID} ]] && WIFI=" to ${WHITE_FG}${SSID}${RESET}"
			tput cup ${C_POS} 0
			tput ed
			echo ${NTWK}${WIFI}
		else
			tput rc
			tput ed
			echo ${NTWK}${WIFI}
		fi
	fi
}

stty -ixon
umask 002 # Standard
alias sudo='sudo ' # Sudo tweak

# Completions
# /bin/rm -rf ~/.zcompdump # remove cache
fpath=(/home/kmiller/.zsh/completions ${fpath})
autoload -Uz compinit && compinit

# Hooks
add-zsh-hook precmd _reload_funcs # HOOK: Automatically reload any modified functions
add-zsh-hook precmd _reload_aliases # HOOK: Automatically reload any modified aliases
#add-zsh-hook precmd _chrome_restore_tweak # HOOK: Tweak chrome to prevent restore prompt
add-zsh-hook precmd _cursor_on

# Misc Cleanup
# typeset -a CLEAN
# CLEAN+=$(find ~ -maxdepth 1 -name 'jdraw*')
# CLEAN+=$(find ~ -maxdepth 1 -name 'kazam*')
# CLEAN+=$(find ~ -maxdepth 1 -name 'kodi*')
# CLEAN+=$(find ~ -maxdepth 1 -name 'core*')
# [[ -n ${CLEAN} ]] && for C in ${CLEAN};do rm -f ${C};done

# Execution
if [[ ${_TERMS} -eq 1 ]];then
	INTERACTIVE=''
	if [[ -o interactive ]]; then
		INTERACTIVE=interactive
		tput cup 0 0
		tput ed

		echo "${_REL} (${(C)_RLBL}):${WHITE_FG}${(C)XDG_SESSION_TYPE}${RESET}"

		# show update status
		_check_updates
		for M in ${_MOTD};do
			echo ${M}
		done

		upd_locate -I >/dev/null 2>&1 &|

		# Show/set wifi
		if ! _wifi_on;then
			echo "Wireless was activated"
		fi
		_set_ssid

		echo "Last backup was:${WHITE_FG}$(backup -s)${RESET}" # show days since last backup 

		tput sc
		echo "Cleaning history..." 
		HIST=$(hist_no_dups)
		tput rc
		echo ${HIST}

		setopt >~/.cur_setopts
		unsetopt >~/.cur_unsetopts

		# Check for Enpass
		ENPASS=/opt/enpass/Enpass
		ENP_FOUND=false
		RETRIES=0

		while true;do
			((++RETRIES))
			pgrep -f ${ENPASS} >/dev/null 2>&1
			[[ ${?} -eq 0 ]] && ENP_FOUND=true && break
			[[ ${RETRIES} -eq 10 ]] && break
			sleep .2
		done

		if [[ ${ENP_FOUND} == 'true' ]];then
			echo "Enpass:${GREEN_FG}${ITALIC}running${RESET}..."
		else
			echo "Enpass:${WHITE_FG}${ITALIC}waiting${RESET}..."
		fi

		dut external -b # External drive status

		gd -s # Google Drive status

		[[ ${XDG_SESSION_TYPE:l} == 'x11' ]] && xset r rate 500 33 # set keyboard repeat delay

		echo "Battery charging limit:${WHITE_FG}${_BATT_LIMIT}%${RESET}"
		/usr/local/bin/system/tweaks/battery_charge_limit ${_BATT_LIMIT} >/dev/null 2>&1 # Set battery charge limit

		echo "Killing ${WHITE_FG}power management for wifi...${RESET}"
		sudo iwconfig wlo1 power off # Turn off power mgt for wifi

		[[ ${CAM_DEFAULT} == 'off' ]] && sut cam off # Kill cam - show status

		# show calendar
		if [[ ${_TERMS} -eq 1 ]];then
			TERM_LINES=$(tput lines)
			CAL_TOP_ROW=$(( TERM_LINES - _CAL_LINES ))
			tput cup ${CAL_TOP_ROW} 0
			cal_clr
		fi

		# background dbus - maximize new windows (gnome forgets win coords issue)
		INSTANCE=$(pgrep -c wait_app_start)
		if [[ ${INSTANCE} -eq 0 ]];then
			( wait_app_start & ) >/dev/null 2>&1
		fi

		remind # post any reminders

		xdotool mousemove $((1920/2)) $((1080/2)) # center the mouse  pointer
	fi
fi
