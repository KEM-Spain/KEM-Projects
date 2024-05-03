#LIB Dependencies
_DEPS_+="ARRAY.zsh DBG.zsh MSG.zsh STR.zsh TPUT.zsh UTILS.zsh"

#LIB Vars
_INNER_BOX_COLOR=${RESET}
_OUTER_BOX_COLOR=${RESET}
_SELECTION_VALUE=?
_SELECTION_KEY=?
_SL_CATEGORY=false
_SL_MAX_ITEM_LEN=0
_TITLE_HL=${WHITE_ON_GREY}

#LIB Declarations
typeset -a _SELECTION_LIST # Holds indices of selected items in a list
typeset -A _PAGE_TOPS
typeset -a _CENTER_COORDS
typeset -A _COL_WIDTHS

_CUR_PAGE=1
_MAX_PAGE=0
_HILITE=${_TITLE_HL}
_PAGE_OPTION_KEY_HELP=''

#LIB Functions
selection_list () {
	local -A SKEYS
	local -a SLIST
	local MAX_X_COORD=$((_MAX_ROWS-5)) # Up from bottom 
	local MAX_NDX=${#_SELECTION_LIST}
	local BOX_BOT=0
	local BOX_HEIGHT=$(( MAX_NDX+2 ))
	local BOX_NDX=0
	local BOX_PARTIAL=0
	local BOX_ROW=0
	local BOX_TOP=0
	local BOX_WIDTH=0
	local BOX_X=0
	local BOX_X_COORD=0
	local BOX_Y=0
	local BOX_Y_COORD=0
	local CENTER_Y
	local CLEAN_TEXT
	local CURSOR_NDX=0
	local CURSOR_ROW=0
	local DIR
	local F1 F2
	local GUIDE=false
	local GUIDE_ROW=0
	local GUIDE_ROWS=1
	local GUIDE_OFFSET=2
	local ITEM_PAD=0
	local KEY
	local L P Q 
	local LAST_NDX
	local LAST_ROW
	local LINE
	local LIST_BOT=0
	local LIST_NDX=0
	local LIST_TOP=0
	local MAX_BOX=0
	local OPTION
	local OPTSTR
	local PAD=2
	local PG_BOT=0
	local PG_TOP=0
	local REM 
	local ROWS_OUT=0
	local ROW_ARG=?
	local SX SY SW SH SL
	local TITLE
	local TOP_SET=false
	local X_COORD_ARG=0
	local Y_COORD_ARG=0
	local _SORT_KEY=false
	local BOUNDARY_SET=false
	local OPT_KEY_ROW=0

	[[ ${_DEBUG} -ge 2 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	OPTSTR=":x:y:cr:w:O:I:s"
	OPTIND=0

	ITEM_PAD=2
	ROW_ARG=''
	_INNER_BOX_COLOR=${RESET}
	_OUTER_BOX_COLOR=${RESET}
	_SL_CATEGORY=false
	_SORT_KEY=false

	while getopts ${OPTSTR} OPTION;do
		case $OPTION in
	   c) _SL_CATEGORY=true;;
	   O) _OUTER_BOX_COLOR=${OPTARG};;
	   I) _INNER_BOX_COLOR=${OPTARG};;
	   w) ITEM_PAD=${OPTARG};;
	   r) ROW_ARG=${OPTARG};;
	   s) _SORT_KEY=true;;
	   x) X_COORD_ARG=${OPTARG};;
	   y) Y_COORD_ARG=${OPTARG};;
	   :) exit_leave "${RED_FG}${0}${RESET}: option: -${OPTARG} requires an argument";;
	  \?) exit_leave "${RED_FG}${0}${RESET}: unknown option -${OPTARG}";;
		esac
	done
	shift $((OPTIND -1))

	# Args
	TITLE=${1}

	# Hide cursor
	if [[ ${_CURSOR_STATE} == 'on' ]];then
		tput civis >&2
		_CURSOR_STATE=off
	fi

	#msg_box "Loading selection list..."

	if [[ ${_SORT_KEY} == 'true' ]];then
		for L in ${_SELECTION_LIST};do
			SKEYS+=$(cut -d':' -f1 <<<${L})
			SLIST+=$(cut -d':' -f2- <<<${L})
		done
		_SELECTION_LIST=(${SLIST})
	fi

	if [[ -z ${_SELECTION_LIST} ]];then
		exit_leave "_SELECTION_LIST is unset"
	else
		if [[ ${_SL_MAX_ITEM_LEN} -eq 0 ]];then
			_SL_MAX_ITEM_LEN=$(arr_long_elem_len ${_SELECTION_LIST}); ((_SL_MAX_ITEM_LEN++)) # 1 char pad
			_SL_MAX_ITEM_LEN=$((_SL_MAX_ITEM_LEN + ITEM_PAD))
		fi
		BOX_WIDTH=$(( _SL_MAX_ITEM_LEN+2 ))
	fi

	msg_box_clear

	[[ ${MAX_X_COORD} -lt ${BOX_HEIGHT} ]] && BOX_HEIGHT=$((MAX_X_COORD-10 )) # Long list

	[[ ${_SL_MAX_ITEM_LEN} -gt ${#TITLE} ]] && SW=$(( _SL_MAX_ITEM_LEN+2 )) || SW=$(( ${#TITLE}+2 )) # Choose either item or title for box width

	[[ ${X_COORD_ARG} -gt 0 ]] && BOX_X_COORD=${X_COORD_ARG} || BOX_X_COORD=$(coord_center $((_MAX_ROWS)) ${BOX_HEIGHT})
	[[ ${Y_COORD_ARG} -gt 0 ]] && BOX_Y_COORD=${Y_COORD_ARG} || BOX_Y_COORD=$(coord_center $((_MAX_COLS)) ${SW})

	SX=$(( BOX_X_COORD-PAD ))
	SY=$(( BOX_Y_COORD-PAD ))
	SW=$(( SW + (PAD * 2) ))
	SH=$(( BOX_HEIGHT + (PAD * 2) ))

	[[ $((SW % 2)) -ne 0 ]] && ((SW++)) # Even width cols
	[[ $((BOX_WIDTH % 2)) -ne 0 ]] && ((BOX_WIDTH++)) # Even width cols

	SL=$(( SX+BOX_HEIGHT + (PAD * 2) - 1 )) # Loop limit

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  BOX_X_COORD:${BOX_X_COORD} BOX_Y_COORD:${BOX_Y_COORD} BOX_WIDTH:${BOX_WIDTH} BOX_HEIGHT:${BOX_HEIGHT} PAD:${PAD}=PAD"
	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  SX:${SX}->SL:${SL}, SY:${SY}->SW:${SW}"

	# Space around list
	for ((L=SX;L<=SL;L++));do
		tput cup ${L} ${SY};tput ech ${SW}
	done

	# Set boundaries
	if [[ ${BOUNDARY_SET} == 'false' ]];then
		[[ ${BOX_HEIGHT} -lt ${MAX_NDX} ]] && MAX_BOX=$((BOX_HEIGHT-PAD)) || MAX_BOX=${MAX_NDX} # Set box boundary
		_MAX_PAGE=$(( ${#_SELECTION_LIST} / MAX_BOX ))
		REM=$(( ${#_SELECTION_LIST} % MAX_BOX ))
		[[ ${REM} -ne 0 ]] && (( _MAX_PAGE++ )) && BOX_PARTIAL=${REM}
		for ((P=1; P<=_MAX_PAGE; P++));do
			[[ ${P} -eq 1 ]] && PG_TOP=1 || PG_TOP=$(( _PAGE_TOPS[$(( P-1 ))] + MAX_BOX ))
			_PAGE_TOPS[${P}]=${PG_TOP}
		done

		# Extend box height if 2 guide info rows are needed
		[[ ${_MAX_PAGE} -gt 1 && -n ${_PAGE_OPTION_KEY_HELP} ]] && (( SH++ )) && GUIDE_ROWS=2 && GUIDE_OFFSET=3

		# Outer box w/ title
		echo -n ${_OUTER_BOX_COLOR}
		msg_unicode_box ${SX} ${SY} ${SW} ${SH} # OUTER box

		#echo -n ${RESET}
		CLEAN_TEXT=$(msg_nomarkup ${TITLE})
		tput cup $((SX+1)) $(( SY+(SW/2)-(${#CLEAN_TEXT}/2) ));echo $(msg_markup ${TITLE})

		GUIDE_ROW=$(( ${SX}+${SH} - ${GUIDE_OFFSET} ))

		# Option key guide
		if [[ -n ${_PAGE_OPTION_KEY_HELP} ]];then
			CLEAN_TEXT=$(msg_nomarkup ${_PAGE_OPTION_KEY_HELP})
			[[ ${GUIDE_ROWS} -eq 2 ]] && OPT_KEY_ROW=$(( GUIDE_ROW+1 )) || OPT_KEY_ROW=${GUIDE_ROW}
			tput cup ${OPT_KEY_ROW} $(( SY+(SW/2)-(${#CLEAN_TEXT}/2) ));echo $(msg_markup ${_PAGE_OPTION_KEY_HELP})
		fi

		BOUNDARY_SET=true
	fi

	# Save box coords
	_MSG_BOX_COORDS=(X ${SX} Y ${SY} W ${SW} H ${SH})

	# Initialize
	CENTER_Y=$(( SY+(SW/2)-(BOX_WIDTH/2) )) # New Y to center list
	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  CENTER_Y to center:${CENTER_Y}"

	BOX_X=$((BOX_X_COORD+1))
	BOX_Y=$((CENTER_Y+1))
	BOX_TOP=${BOX_X}
	BOX_BOT=0
	LIST_NDX=0
	LIST_TOP=1
	LIST_BOT=0
	LAST_NDX=0
	LAST_ROW=0

	#Record page tops
	for P in ${(onk)_PAGE_TOPS};do
		Q=$((P+1))
		[[ -n ${_PAGE_TOPS[${Q}]} ]] && PG_BOT=${_PAGE_TOPS[${Q}]} || PG_BOT=${MAX_NDX}
		if [[ ${ROW_ARG} -ge ${_PAGE_TOPS[${P}]} && ${ROW_ARG} -le ${PG_BOT} ]];then
			LIST_TOP=${_PAGE_TOPS[${P}]}
			TOP_SET=true
			break
		fi
	done

	# Display list
	while true;do
		BOX_ROW=${BOX_X}
		BOX_NDX=1
		echo -n ${_INNER_BOX_COLOR}
		msg_unicode_box ${BOX_X_COORD} ${CENTER_Y} ${BOX_WIDTH} ${BOX_HEIGHT} # Display INNER box for list
		echo -n ${RESET}

		if [[ ${_SL_CATEGORY} == 'true' ]];then
			for L in ${_SELECTION_LIST};do
				F1=$(cut -d: -f1 <<<${L})
				F2=$(cut -d: -f2 <<<${L})
				[[ ${#F1} -gt ${_COL_WIDTHS[1]} ]] && _COL_WIDTHS[1]=${#F1}
				[[ ${#F2} -gt ${_COL_WIDTHS[2]} ]] && _COL_WIDTHS[2]=${#F2}
			done
		fi

		# Paging key guide
		if [[ ${_MAX_PAGE} -gt 1 ]];then
			tput cup ${GUIDE_ROW} ${BOX_Y}
			printf "${CYAN_FG}Page:${WHITE_FG}%-2d ${CYAN_FG}of ${WHITE_FG}%d %s${RESET}\n" ${_CUR_PAGE} ${_MAX_PAGE} "(n)ext (p)rev"
		fi

		ROWS_OUT=0
		for (( LIST_NDX=LIST_TOP;LIST_NDX<=MAX_NDX;LIST_NDX++ ));do
			[[ $((BOX_NDX++)) -gt ${MAX_BOX} ]] && break # Increments BOX_NDX, break when page is full
			tput cup ${BOX_ROW} ${BOX_Y}
			[[ ${BOX_ROW} -eq ${BOX_X} ]] && tput smso || tput rmso # Highlight first item
			if [[ ${_SL_CATEGORY} == 'true' ]];then
				F1=$(cut -d: -f1 <<<${_SELECTION_LIST[${LIST_NDX}]})
				F2=$(cut -d: -f2 <<<${_SELECTION_LIST[${LIST_NDX}]})
				[[ ${LIST_NDX} -eq 1 ]] && _HILITE=${_TITLE_HL} || _HILITE=''
				printf "${WHITE_FG}%-*s${RESET} ${_HILITE}%-*s${RESET}\n" ${_COL_WIDTHS[1]} ${F1} ${_COL_WIDTHS[2]} ${F2}
			else
				echo ${_SELECTION_LIST[${LIST_NDX}]}
			fi

			((BOX_ROW++))
			((ROWS_OUT++))
		done
		_HILITE=${_TITLE_HL}

		LIST_BOT=$((LIST_NDX-1))
		[[ ${ROWS_OUT} -lt ${MAX_BOX} ]] && BOX_BOT=$((BOX_ROW-1)) || BOX_BOT=$((BOX_X+MAX_BOX-1))

		# Initialize list cursors
		CURSOR_NDX=${LIST_TOP}
		CURSOR_ROW=${BOX_TOP}

		while true;do
			KEY=$(get_keys)
			_SELECTION_VALUE='?'
			_SELECTION_KEY='?'
			case ${KEY} in
				0) _SELECTION_VALUE=${_SELECTION_LIST[${CURSOR_NDX}]} && break 2;;
				100) _SELECTION_VALUE=${_SELECTION_LIST[${CURSOR_NDX}]} && _SELECTION_KEY='d' && break 2;;
				108) _SELECTION_VALUE=${_SELECTION_LIST[${CURSOR_NDX}]} && _SELECTION_KEY='l' && break 2;;
				114) _SELECTION_VALUE=${_SELECTION_LIST[${CURSOR_NDX}]} && _SELECTION_KEY='r' && break 2;;
				121) _SELECTION_VALUE=${_SELECTION_LIST[${CURSOR_NDX}]} && _SELECTION_KEY='y' && break 2;;
				110) CURSOR_ROW=${BOX_TOP};CURSOR_NDX=$(selection_list_set_pg 'N' ${CURSOR_NDX});DIR='N';;
				112) CURSOR_ROW=${BOX_TOP};CURSOR_NDX=$(selection_list_set_pg 'P' ${CURSOR_NDX});DIR='P';;
				113) exit_request;;
				1|107) ((CURSOR_ROW--));((CURSOR_NDX--));DIR='U';;
				2|106) ((CURSOR_ROW++));((CURSOR_NDX++));DIR='D';;
				3|116) DIR='T';;
				4|98) DIR='B';;
				27) msg_box_clear; return 2;;
			esac

			# Ensure sane index boundaries
			if [[ ${CURSOR_NDX} -lt ${LIST_TOP} ]];then
				CURSOR_NDX=${LIST_BOT}
				CURSOR_ROW=${BOX_BOT}
			elif [[ ${CURSOR_NDX} -gt ${LIST_BOT} ]];then
				CURSOR_NDX=${LIST_TOP}
				CURSOR_ROW=${BOX_TOP}
			fi

			# Roll arounds
			case ${DIR} in
				D)	if [[ ${CURSOR_NDX} -eq ${LIST_TOP} ]];then
						LAST_NDX=${LIST_BOT}
						LAST_ROW=${BOX_BOT}
					else
						LAST_NDX=$((CURSOR_NDX-1))
						LAST_ROW=$((CURSOR_ROW-1))
					fi
					;;
				U)	if [[ ${CURSOR_NDX} -eq ${LIST_BOT} ]];then
						LAST_NDX=${LIST_TOP}
						LAST_ROW=${BOX_TOP}
					else
						LAST_NDX=$((CURSOR_NDX+1))
						LAST_ROW=$((CURSOR_ROW+1))
					fi
					;;
			esac

			# Row and Page changes
			case ${DIR} in
				D|U)	selection_list_hilite ${CURSOR_ROW} ${BOX_Y} ${_SELECTION_LIST[${CURSOR_NDX}]}
						selection_list_norm ${LAST_ROW} ${BOX_Y} ${_SELECTION_LIST[${LAST_NDX}]}
						;;

				T) 	if [[ ${CURSOR_NDX} -ne ${LIST_TOP} ]];then
							selection_list_hilite ${BOX_TOP} ${BOX_Y} ${_SELECTION_LIST[${LIST_TOP}]}
							selection_list_norm ${CURSOR_ROW} ${BOX_Y} ${_SELECTION_LIST[${CURSOR_NDX}]}
							CURSOR_NDX=${LIST_TOP}
							CURSOR_ROW=${BOX_TOP}
						fi
						;;

				B)		if [[ ${CURSOR_NDX} -ne ${LIST_BOT} ]];then
							selection_list_hilite ${BOX_BOT} ${BOX_Y} ${_SELECTION_LIST[${LIST_BOT}]}
							selection_list_norm ${CURSOR_ROW} ${BOX_Y} ${_SELECTION_LIST[${CURSOR_NDX}]}
							CURSOR_NDX=${LIST_BOT}
							CURSOR_ROW=${BOX_BOT}
						fi
						;;

				N) if [[ $(( _CUR_PAGE+1 )) -le ${_MAX_PAGE} ]];then
						((_CUR_PAGE++))
						LIST_TOP=${_PAGE_TOPS[${_CUR_PAGE}]}
						break
					else
						_CUR_PAGE=1
						LIST_TOP=${_PAGE_TOPS[${_CUR_PAGE}]}
						break
					fi
					;;

				P) if [[ $(( _CUR_PAGE-1 )) -ge 1 ]];then
						((_CUR_PAGE--))
						LIST_TOP=${_PAGE_TOPS[${_CUR_PAGE}]}
						break
					else
						_CUR_PAGE=${_MAX_PAGE}
						LIST_TOP=${_PAGE_TOPS[${_CUR_PAGE}]}
						break
					fi
					;;
			esac
		done
	done
	return 0
}

selection_list_set_pg() {
	local DIR=${1}
	local NDX=${2}
	local P

	for P in ${(onk)_PAGE_TOPS};do
		[[ ${NDX} -ge ${_PAGE_TOPS[${P}]} ]] && _CUR_PAGE=${P}
	done

	if [[ ${DIR} == 'P' ]];then
		if [[ ${_CUR_PAGE} -eq 1 ]];then
			echo ${NDX}
			return
		else
			_CUR_PAGE=$((_CUR_PAGE-1))
		fi
	fi

	if [[ ${DIR} == 'N' ]];then
		if [[ ${_CUR_PAGE} -eq ${_MAX_PAGE} ]];then
			echo ${NDX}
			return
		else
			_CUR_PAGE=$((_CUR_PAGE+1))
		fi
	fi

	echo ${_PAGE_TOPS[${_CUR_PAGE}]}
}

selection_list_hilite () {
	local X=${1}
	local Y=${2}
	local TEXT=${3}
	local F1 F2

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: X:${X} Y:${Y} TEXT:${TEXT}"

	tput cup ${X} ${Y}
	tput smso
	if [[ ${_SL_CATEGORY} == 'true' ]];then
		F1=$(cut -d: -f1 <<<${TEXT})
		F2=$(cut -d: -f2 <<<${TEXT})
		printf "${WHITE_FG}%-*s${RESET} ${_HILITE}%-*s${RESET}\n" ${_COL_WIDTHS[1]} ${F1} ${_COL_WIDTHS[2]} ${F2}
	else
		echo ${TEXT}
	fi
	tput rmso
}

selection_list_norm () {
	local X=${1}
	local Y=${2}
	local TEXT=${3}
	local F1 F2

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: X:${X} Y:${Y} TEXT:${TEXT}"

	tput cup ${X} ${Y}
	tput rmso
	if [[ ${_SL_CATEGORY} == 'true' ]];then
		F1=$(cut -d: -f1 <<<${TEXT})
		F2=$(cut -d: -f2 <<<${TEXT})
		printf "${WHITE_FG}%-*s${RESET} %-*s\n" ${_COL_WIDTHS[1]} ${F1} ${_COL_WIDTHS[2]} ${F2}
	else
		echo ${TEXT}
	fi
}

selection_list_set () {
	local -a LIST=(${@})

	_SELECTION_LIST=(${(on)LIST})
	[[ ${_DEBUG} -ge 3 ]] && dbg "${0} _SELECTION_LIST:${#_SELECTION_LIST} ITEMS"
}

selection_list_set_page_key_help () {
	_PAGE_OPTION_KEY_HELP=${@}
}

