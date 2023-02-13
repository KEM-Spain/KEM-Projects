#!/usr/bin/env zsh
#vim: syntax off
RESET="\033[m"
BOLD="\033[1m"
ITALIC="\033[3m"
UNDER="\033[4m"
REVERSE="\033[7m"
STRIKE="\033[9m"

BLACK_FG="\033[30m"
RED_FG="\033[31m"
GREEN_FG="\033[32m"
YELLOW_FG="\033[33m"
BLUE_FG="\033[34m"
MAGENTA_FG="\033[35m"
CYAN_FG="\033[36m"
WHITE_FG="\033[37m"

#Constants
PATH=${PATH}:/usr/local/bin/system #add custom utils
FAST_BASE_DIR=/usr/local/src/fast-syntax-highlighting
SYS_FUNCTIONS=/etc/zsh/system_wide/functions
LOC_FUNCTIONS=/home/kmiller/.zsh/completions
ZSH_ALIAS=/etc/zsh/aliases
ZSHRC_SYS=/etc/zsh/zshrc
BATT_LIMIT=87
CAL_LINES=12
WIFI_PREF="WiFi_OliveNet-Casa 7_5G"

#Functions 
cursor_row() {
	local ROW

	echo -ne "\033[6n" > /dev/tty
	read -t 1 -s -d 'R' ROW < /dev/tty
	ROW="${ROW##*\[}"
	ROW="${ROW%;*}"
	((ROW--))
	echo ${ROW}
}

#External 
source ${ZSH_ALIAS}
source ${ZSHRC_SYS}

#ENV
export GREP_COLORS='ms=01;31:mc=01;31:sl=:cx=:fn=97:ln=32:bn=32:se=36' #https://askubuntu.com/questions/1042234/modifying-the-color-of-grep
export HISTORY_IGNORE="(rm(| *)|cd(| *)|ls(| *)|tail(| *)|vi(| *)|tvi(| *)|cp(| *)|mv(| *)|ghis(| *)|exit(| *))"
export MUSIC_DIR=/media/kmiller/KEM_Misc/Music/KEM-B9
export PRINTER=ENVY-5000
export TERM=xterm
export DEFAULT_PLAYER=CLMN

#source ${FAST_BASE_DIR}/fast-syntax-highlighting.plugin.zsh
source ${FAST_BASE_DIR}/F-Sy-H.plugin.zsh
 
#MOTD
typeset -a MOTD=()

sudo chmod 644 /etc/update-motd.d/10-help-text #disable
MOTDS=("${(f)$(sudo run-parts /etc/update-motd.d/)}")

MOTD+="${MOTDS[1]}"

chkupd -s
if [[ ${?} -eq 0 ]];then
	MOTD+="${GREEN_FG}${BOLD}${ITALIC}Updates are available...${RESET}"
else
	MOTD+="${ITALIC}No updates are available...${RESET}"
fi

#Standard
umask 002
stty -ixon

#Sudo tweak
alias sudo='sudo '

#Completions
#/bin/rm -rf ~/.zcompdump #remove cache
fpath=(/home/kmiller/.zsh/completions ${fpath})
autoload -Uz compinit
compinit

#HOOK: Automatically reload any modified functions
reload_funcs () {
	local F
	local FILE
	local HOURS

	MODIFIED=("${(f)$(
		find -L ${SYS_FUNCTIONS} -type f
		find -L ${LOC_FUNCTIONS} -type f
	)}")

	NOW=$(date +'%s')
	for F in ${MODIFIED};do
		FILE=$(date +'%s' -r ${F})
		HOURS=$(((NOW - FILE)/3600))
		if [[ ${HOURS} -le 24 ]];then
			echo "Refreshing functions..."
			refunc ${F:t}
			sudo touch -d '25 hours ago' ${F}
		fi
	done
}
add-zsh-hook precmd reload_funcs
 
#HOOK: Automatically reload aliases if modified
reload_aliases () {
	local LAST_ALIAS_REFRESH=0
	local CURR_ALIAS_TIME
	local STAMP_FILE=~/.zsh/last_alias_refresh

	[[ -e ${ZSH_ALIAS} ]] || return 1
	[[ -e ${STAMP_FILE} ]] && LAST_ALIAS_REFRESH=$(<${STAMP_FILE})
	CURR_ALIAS_TIME=$(stat -c %Y ${ZSH_ALIAS}(:A)) #file mod time in seconds; the modifier `(:A)` resolves any symbolic links
	if [[ ${LAST_ALIAS_REFRESH} -lt ${CURR_ALIAS_TIME} ]]; then
		echo "Refreshing aliases..."
		unalias -m '*'
		source ${ZSH_ALIAS}
		echo "${CURR_ALIAS_TIME}" > ${STAMP_FILE}
	fi
}
add-zsh-hook precmd reload_aliases

#HOOK: Tweak chrome to prevent restore prompt
chrome_restore_tweak () {
	local CHROME_PREF=/home/kmiller/.config/google-chrome/Default/Preferences

    [[ -e ${CHROME_PREF} ]] || return 1

	RUNNING=$(pgrep -c chrome)
	[[ ${RUNNING} -ne 0 ]] && return 1

	grep -qi 'Crashed' ${CHROME_PREF} #check if edit is necessary
	[[ ${?} -ne 0 ]] && return 1
	#echo "Refreshing chrome restore tweak..."
	sudo sed -i 's/Crashed/Normal/g' ${CHROME_PREF} #disable restore session prompt
}
add-zsh-hook precmd chrome_restore_tweak

#Set battery charge limit
/usr/local/bin/system/tweaks/battery_charge_limit ${BATT_LIMIT} >/dev/null 2>&1

#Some HOMEDIR Cleanup
typeset -a CLEAN
CLEAN+=$(find ~ -maxdepth 1 -name 'jdraw*')
CLEAN+=$(find ~ -maxdepth 1 -name 'kazam*')
CLEAN+=$(find ~ -maxdepth 1 -name 'kodi*')
CLEAN+=$(find ~ -maxdepth 1 -name 'core*')
[[ -n ${CLEAN} ]] && for C in ${CLEAN};do rm -f ${C};done

TERMS=$(terms | cut -d' ' -f1)
if [[ ${TERMS} -le 1 ]];then
	INTERACTIVE=''
	if [[ -o interactive ]]; then
		INTERACTIVE=interactive
		tput cup 0 0
		tput ed
		for M in ${MOTD};do
			echo ${M}
		done
		echo "Current windowing system:${WHITE_FG}${(C)XDG_SESSION_TYPE}${RESET}"
		echo "Updating locate database..." && (sudo updatedb &) 2>/dev/null
		echo "Battery charging limit:${WHITE_FG}${BATT_LIMIT}%${RESET}"

		[[ -o login ]] && LOGIN=login || LOGIN=''

		#Center the mouse  pointer
		xdotool mousemove $((1920/2)) $((1080/2))

		#Show net status
		NC=$(net_conn) 
		if [[ ${NC:l} =~ "^no " ]];then
			nmcli radio wifi on
			echo "Wireless was activated"
			NDX=0
			while true;do
				((NDX++))
				[[ ${NDX} -gt 3 ]] && break
				sleep 1
				NC=$(net_conn)
				[[ ${NC:l} =~ "^no " ]] && continue
			done
		fi

		SSID=$(wless -s 2>/dev/null)
		NTWK=$(net_conn)
		[[ -n ${SSID} ]] && WIFI=" to ${WHITE_FG}${SSID}${RESET}" && echo ${NTWK}${WIFI}

		if [[ ! ${SSID} =~ ${WIFI_PREF} ]];then
			echo "Current wireless connection is ${BOLD}${ITALIC}${RED_FG}NOT ${WHITE_FG}${WIFI_PREF}${RESET} (preferred)"
			echo -n "${WHITE_FG}Select (p)referred ,(c)hoose, (i)gnore${RESET}? (p/c/i):"
			read -k1 KEY
			if [[ ${KEY:l} == "p" ]];then
				echo
				wless -n "${WIFI_PREF}"
			elif [[ ${KEY:l} == "c" ]];then
				tput sc
				tput smcup
				wless -cn
				tput rmcup
				tput rc
				SSID=$(wless -s 2>/dev/null)
				[[ -n ${SSID} ]] && WIFI=" to ${WHITE_FG}${SSID}${RESET}"
				echo
				echo ${NTWK}${WIFI}
			else
				echo
			fi
		fi

		echo "Last backup was:${WHITE_FG}$(backup -s)${RESET}" #show days since last backup 

		#External disk status
		dsk_external -s

		#Google Drive status
		gd -s

		#Clean history
		echo "Cleaning history..." && hist_no_dups

		setopt >~/.cur_setopts
		unsetopt >~/.cur_unsetopts

		#Check for Enpass
		ENPASS=/opt/enpass/Enpass
		ENP_FOUND=false
		RETRIES=0

		while true;do
			((++RETRIES))
			pgrep -f ${ENPASS} >/dev/null 2>&1
			[[ ${?} -eq 0 ]] && ENP_FOUND=true && break
			[[ ${RETRIES} -eq 6 ]] && break
			sleep .2
		done

		if [[ ${ENP_FOUND} == 'true' ]];then
			echo "Enpass:${GREEN_FG}${ITALIC}running${RESET}..."
		else
			echo "Enpass:${WHITE_FG}${ITALIC}waiting${RESET}..."
		fi

		#Turn off power mgt for monitor
		if [[ -n ${DISPLAY} ]];then
			if [[ ${XDG_SESSION_TYPE:l} == 'x11' ]];then
				echo "Killing ${WHITE_FG}screensaver and power management for monitor...${RESET}"
				xset s off -dpms
			fi
		fi

		#echo "Setting ${WHITE_FG}keyboard repeat delay...${RESET}"
		[[ ${XDG_SESSION_TYPE:l} == 'x11' ]] && xset r rate 500 33 #default

		#Turn off power mgt for wifi
		echo "Killing ${WHITE_FG}power management for wifi...${RESET}"
		sudo iwconfig wlo1 power off

		#Killing cam
		if [[ ${CAM_DEFAULT} == 'off' ]];then
			sys_cam off
		else
			sys_cam on
			echo "${WHITE_FG}Camera is on...${RESET}"
		fi

		if [[ ${TERMS} -eq 1 ]];then
			TERM_LINES=$(tput lines)
			OFFSET=1
			R=$(cursor_row)
			N_ROW=$(( R+(TERM_LINES-R-CAL_LINES-OFFSET) ))
			#echo "CURSOR_ROW:${R}, TERM_LINES:${TERM_LINES}, CAL_LINES:${CAL_LINES}, OFFSET:${OFFSET}, N_ROW:${N_ROW}      $(date)" >> ~/zshrc.dbg
			tput cup ${N_ROW} 0
			mycal
			echo
		fi
	fi
fi
