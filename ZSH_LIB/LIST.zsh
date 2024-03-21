#LIB Dependencies
_DEPS_+="ARRAY.zsh DBG.zsh MSG.zsh PATH.zsh STR.zsh TPUT.zsh UTILS.zsh VALIDATE.zsh"

#LIB Vars
_BARLINES=false
_CB_KEY=''
_CLEAR_GHOSTS=false
_CLIENT_WARN=true
_CURRENT_ARRAY=1
_CURRENT_CURSOR=0
_CURRENT_PAGE=1
_CURSOR_COL=${CURSOR_COL:=0}
_CURSOR_ROW=${CURSOR_ROW:=0}
_AVAIL_ROW=0
_HELD_ROW=1
_GHOST_ROW=2 # any value above 1 is not selectable
_HEADER_CALLBACK_FUNC=''
_HOLD_CURSOR=false
_HOLD_PAGE=false
_INVISIBLE_ROWS_MSG=''
_KEY_CALLBACK_FUNC=''
_LIST_DELIM='|'
_LIST_HEADER_BREAK=false
_LIST_HEADER_BREAK_COLOR=${WHITE_FG}
_LIST_HEADER_BREAK_LEN=0
_LIST_IS_SEARCHABLE=true
_LIST_IS_SORTABLE=false
_LIST_LINE_ITEM=''
_LIST_PROMPT=''
_LIST_SELECT_NDX=0
_LIST_SELECT_ROW=0
_LIST_SORT_COL_MAX=0
_LIST_SORT_COL_DEFAULT=0
_LIST_SORT_TYPE=flat
_LIST_TOGGLE_STATE=off
_LIST_USER_PROMPT_STYLE=none
_MSG_KEY=n
_NO_TOP_OFFSET=false
_PROMPT_KEYS=''
_ROW_OVERRIDE=false
_SELECTABLE=true
_SELECTION_LIMIT=0
_SELECT_ALL=false
_SELECT_CALLBACK_FUNC=''
_TARGET_CURSOR=1
_TARGET_KEY=''
_TARGET_MAX=''
_TARGET_MIN=''
_TARGET_NDX=1
_TARGET_PAGE=1

#LIB Declarations
typeset -A _CAL_SORT=(year F6 month E5 week D4 day C3 hour B2 minute A1)
typeset -a _LIST_ACTION_MSGS # Holds text for contextual prompts
typeset -a _LIST_HEADER=() # Holds header lines
typeset -a _LIST # Holds the list values to be managed by the list menu
typeset -a _LIST_INDEX_RANGE=() # Holds the top and bottom screen row indicies
typeset -A _LIST_SELECTED_PAGE # Selected rows by page
typeset -A _LIST_SELECTED # Status of selected list items; can contain 0,1,2, etc.; 0,1 can toggle; -gt 2 cannot toggle - ex: a deleted file
typeset -a _SELECTION_LIST # Holds indices of selected items in a list
typeset -A _SORT_TABLE # sort assoc array names
typeset -A _SORT_DIRECTION # Status of list sort direction
typeset -a _TARGETS # target indexes

#LIB Functions
inline_vi_edit () {
	local PROMPT=${1}
	local CUR_VALUE=${2}
	local PERL_SCRIPT
	
	read -r -d '' PERL_SCRIPT <<'___EOF'
	use warnings;
	use strict;
	use Term::ReadLine;

	my $term = new Term::ReadLine 'list_search';
	$term->parse_and_bind("set editing-mode vi");

	system('sleep .1;xdotool key Home &');
	while ( defined ($_ = $term->readline($ARGV[0],$ARGV[1])) ) {
		print $_;
		exit;
	}
___EOF

perl -e "$PERL_SCRIPT" ${PROMPT} ${CUR_VALUE}
}

list_add_header_break () {
	_LIST_HEADER_BREAK=true
}

list_call_sort () {
	case ${_LIST_SORT_TYPE} in
		assoc) list_sort_assoc;;
		flat) list_sort;;
	esac
}

list_clear_selected () {
	local NDX=${1}

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	_LIST_SELECTED[${NDX}]=0
}

list_do_header () {
	local PAGE=${1}
	local MAX_PAGE=${2}
	local CLEAN_HDR
	local CLEAN_TAG
	local HDR_LEN
	local HDR_LINE
	local HDR_PG=false
	local L
	local LONGEST_HDR=0
	local PAD_LEN
	local PAD_TAG
	local PG_TAG
	local SCRIPT_TAG='printf "${_LIST_HEADER_BREAK_COLOR}[${RESET}${_SCRIPT}${_LIST_HEADER_BREAK_COLOR}]${RESET}"'
	local SELECTED_COUNT=$(list_get_selected_count); 

	[[ ${_DEBUG} -ge 2 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: HEADER COUNT:${#_LIST_HEADER}"
	[[ ${_DEBUG} -ge 2 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: PAGE=${PAGE} MAX_PAGE=${MAX_PAGE} SELECTED_COUNT=${SELECTED_COUNT}"

	for ((L=1; L<=${#_LIST_HEADER}; L++))do
		HDR_LINE=$(eval ${_LIST_HEADER[${L}]})
		CLEAN_HDR=$(str_strip_ansi <<<${HDR_LINE})
		[[ ${#CLEAN_HDR} > ${LONGEST_HDR} ]] && LONGEST_HDR=${#CLEAN_HDR}
	done

	[[ ${_DEBUG} -ge 2 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: LONGEST_HDR:${LONGEST_HDR} (before any modifications)"

	# Position cursor
	tput cup 0 0
	tput el

	for ((L=1; L<=${#_LIST_HEADER}; L++))do
		[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Processing header 1 of ${#_LIST_HEADER}"
		if [[ -n ${_LIST_HEADER[${L}]} ]];then

			HDR_LINE=$(eval ${_LIST_HEADER[${L}]})
			[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: (eval) HEADER LINE:${L} -> ${HDR_LINE}"


			if [[ ${L} -eq 1 ]];then # top line
				#prepend script name
				SCRIPT_TAG=$(eval ${SCRIPT_TAG}) && HDR_LINE="${SCRIPT_TAG} ${HDR_LINE}" && CLEAN_HDR=$(str_strip_ansi <<<${HDR_LINE})
				[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Added header name tag:${HDR_LINE}"
			fi

			[[ ${_LIST_HEADER[${L}]} =~ '_PG' ]] && HDR_PG=true # do page numbering

				if [[ ${HDR_PG} == 'true' ]];then #append page number
					PG_TAG=$(eval "printf 'Page:${WHITE_FG}%d${RESET} of ${WHITE_FG}%d${RESET}' ${PAGE} ${MAX_PAGE}") && CLEAN_TAG=$(str_strip_ansi <<<${PG_TAG})
					HDR_LEN=$(( ${#CLEAN_HDR} + ${#CLEAN_TAG} ))
					[[ ${LONGEST_HDR} -gt ${HDR_LEN} ]] && PAD_LEN=$(( LONGEST_HDR-HDR_LEN )) || PAD_LEN=1
					PG_TAG="$(str_rep_char ' ' ${PAD_LEN})${PG_TAG}"
					[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: HDR_LEN:${HDR_LEN}, LONGEST_HDR:${LONGEST_HDR}, PAD_LEN:${PAD_LEN}"

					HDR_LINE="${HDR_LINE}${PG_TAG}"
					CLEAN_HDR=$(str_strip_ansi <<<${HDR_LINE})
					LONGEST_HDR=${#CLEAN_HDR} # this header will now be the longest
					[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Added header page tag:${HDR_LINE}, LONGEST_HDR:${LONGEST_HDR}"

					HDR_PG=false
				fi
				
				tput el
				echo ${HDR_LINE}
			fi

			tput cup ${L} 0
		done

		if [[ ${_LIST_HEADER_BREAK} == 'true' ]];then
			tput el
			echo -n ${_LIST_HEADER_BREAK_COLOR}
			str_unicode_line ${LONGEST_HDR}
			[[ ${_DEBUG} -ge 4 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Header break length:${LONGEST_HDR}"
			echo -n ${RESET}
		fi
	}

list_get_index_range () {
	echo "${_LIST_INDEX_RANGE}"
}

list_get_next_page () {
	local KEY=${1}
	local PAGE=${2}
	local MAX_PAGE=${3}

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@} ARGS:${@}"

	case ${KEY} in
		n) ((PAGE++));;
		p) ((PAGE--));;
		fp) PAGE=1;;
		lp) PAGE=${MAX_PAGE};;
		*) PAGE=${KEY};;
	esac

	[[ ${PAGE} -lt 1 ]] && PAGE=${MAX_PAGE}
	[[ ${PAGE} -gt ${MAX_PAGE} ]] && PAGE=1

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Returning PAGE:${WHITE_FG}${PAGE}${RESET}"

	echo ${PAGE}
}

list_get_page_target () {
	local NEXT=${1}
	local NDX
	local R C P T N

	case ${NEXT} in
		get_key) NDX=1;;
		fwd) N=${_TARGETS[(i)*last_target]}; [[ -z ${_TARGETS[$((N+1))]} ]] && NDX=1 || NDX=$((N+1));;
		rev) N=${_TARGETS[(i)*last_target]}; [[ -z ${_TARGETS[$((N-1))]} ]] && NDX=${#_TARGETS} || NDX=$((N-1));;
	esac

	IFS=":" read R C P T <<<${_TARGETS[${NDX}]} # target text ignored; not used in key

	echo "${R}:${C}:${P}:${NDX}" # pass the current index
}

list_get_selected () {
	local S

	for S in ${(k)_LIST_SELECTED};do
		[[ ${_LIST_SELECTED[${S}]} -ne 1 ]] && continue
		echo ${S}
	done
}

list_get_selected_count () {
	local COUNT=0
	local S

	for S in ${(k)_LIST_SELECTED};do
		[[ ${_LIST_SELECTED[${S}]} -ne 1 ]] && continue
		((COUNT++))
	done

	echo ${COUNT}
}

list_get_selection_limit () {
	echo ${_SELECTION_LIMIT}
}

list_is_valid_selection () {
	local -a SELECTED
	local MAX
	local MIN
	local N

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	MIN=${1};shift
	MAX=${1};shift
	SELECTED=(${@})

	for N in ${SELECTED};do
		if ! validate_is_integer ${N};then
			return 1
		elif ! list_is_within_range ${N} ${MIN} ${MAX};then
			return 1
		elif [[ ${_CLEAR_GHOSTS} == 'false' && ${_LIST_SELECTED[${N}]} -ge ${_GHOST_ROW} && ${_SELECT_ALL} == 'false' ]];then # Cannot select deleted row; select 'all' is exception
			return 1
		fi
	done

	return 0
}

list_is_within_range () {
	local NDX=${1}
	local MIN=${2}
	local MAX=${3}

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	if [[ ${NDX} -ge ${MIN} && ${NDX} -le ${MAX} ]];then
		return 0
	else
		echo "Selection:${NDX} not in page range ${MIN}-${MAX}"
		return 1
	fi
}

list_item_highlight () {
	local LINE_ITEM=${1}
	local X_POS=${2}
	local Y_POS=${3}
	local SHADE=${4}
	local BARLINE BAR

	[[ -z ${_LIST_NDX} ]] && msg_box -p "_LIST_NDX is not populated" && return

	[[ ${_DEBUG} -gt 3 ]] && dbg "${0}:${LINENO} LINE_ITEM:${LINE_ITEM} X_POS:${X_POS} Y_POS:${Y_POS} SHADE:${SHADE}"
	[[ ${_DEBUG} -ge 3 && -z ${_LIST[${_LIST_NDX}]} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: _LIST item is empty - returning"

	[[ -z ${_LIST[${_LIST_NDX}]} ]] && return

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: LINE_ITEM:$(eval echo ${LINE_ITEM})"

	tput cup ${X_POS} ${Y_POS}
	tput smso

	if [[ ${_BARLINES} == 'true' ]];then
		BARLINE=$((_LIST_NDX % 2)) # Barlining 
		[[ ${BARLINE} -ne 0 ]] && BAR=${BLACK_BG} || BAR="" # Barlining
	fi

	eval ${LINE_ITEM} # Output line

	tput rmso
}

list_item_normal () {
	local LINE_ITEM=${1}
	local X_POS=${2}
	local Y_POS=${3}
	local BARLINE BAR

	[[ -z ${_LIST_NDX} ]] && msg_box -p "_LIST_NDX is not populated" && return

	[[ ${_DEBUG} -ge 3 && -z ${_LIST[${_LIST_NDX}]} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: _LIST item is empty - returning"
	[[ -z ${_LIST[${_LIST_NDX}]} ]] && return

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: LINE_ITEM:$(eval echo ${LINE_ITEM})"

	tput rmso
	tput cup ${X_POS} ${Y_POS}

	if [[ ${_BARLINES} == 'true' ]];then
		BARLINE=$((_LIST_NDX % 2)) # Barlining 
		[[ ${BARLINE} -ne 0 ]] && BAR=${BLACK_BG} || BAR="" # Barlining
	fi

	eval ${LINE_ITEM} # Output line
}

list_parse_series () {
	local PATTERN=(${@})
	local -a FROM=()
	local -a TO=()
	local -a R1=()
	local -a R2=()
	local -a SELECTED=()
	local -a KEYLIST=()
	local RANGE=false
	local BEG
	local END
	local P K

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	PATTERN+="#" # Force extra parse cycle

	for P in ${PATTERN};do
		[[ ${P} == '-' ]] && RANGE=true && continue

		if [[ ${P} =~ "[,# ]" ]];then # Hit separator
			if [[ ${RANGE} == 'true' ]];then
				BEG=$(str_array_to_num ${FROM})
				KEYLIST+="B${BEG}"
				FROM=()
				END=$(str_array_to_num ${TO})
				KEYLIST+="E${END}"
				TO=()
			else
				ITEM=$(str_array_to_num ${FROM})
				KEYLIST+=${ITEM}

				FROM=()
			fi
			RANGE=false
			continue
		fi

		if [[ ${RANGE} == 'true' ]];then
			TO+=${P}
		else
			FROM+=${P}
		fi
	done


	for K in ${KEYLIST};do
		if [[ ${K[1,1]} =~ "[BE]" ]];then
			case ${K[1,1]} in
				B) R1+=${K[2,${#K}]};continue;;
				E) R2+=${K[2,${#K}]};continue;;
			esac
		fi
		SELECTED+=${K} # Non range element
	done


	# Handle range elements
	if [[ -n ${R1} ]];then
		for ((X=1;X<=${#R1};X++));do
			SELECTED+=$(echo {${R1[${X}]}..${R2[${X}]}})
		done
	fi

	echo ${SELECTED}
}

list_quote_marked_elements () {
	local MARKED=(${@})
	local M
	local -a STR

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	for M in ${MARKED};do
		#STR+=${(qqq)_LIST[${M}]}
		STR+=${(q)_LIST[${M}]}
	done

	echo ${STR}
}

list_repaint () {
	local _LIST_NDX=${1}
	local TOP_OFFSET=${2}
	local MAX_DISPLAY_ROWS=${3}
	local MAX_ITEM=${4}
	local PAGE=${5}
	local FIRST_ITEM=$((((PAGE*MAX_DISPLAY_ROWS)-MAX_DISPLAY_ROWS)+1))
	local LAST_ITEM=$((PAGE*MAX_DISPLAY_ROWS))
	local CURSOR_NDX=1
	local BARLINE BAR
	local S R
	local OUT

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${LAST_ITEM} -gt ${MAX_ITEM} ]] && LAST_ITEM=${MAX_ITEM} # Partial page

	tput cup ${TOP_OFFSET} 0
	for ((R=0; R<${MAX_DISPLAY_ROWS}; R++));do
		tput cup $((TOP_OFFSET+CURSOR_NDX-1)) 0
		if [[ ${_LIST_NDX} -le ${MAX_ITEM} ]];then
			OUT=${_LIST_NDX}

			if [[ $_BARLINES == 'true' ]];then
				BARLINE=$((NDX % 2)) # Barlining 
				[[ ${BARLINE} -ne 0 ]] && BAR=${BLACK_BG} || BAR="" # Barlining
			fi

			[[ ${_LIST_SELECTED[${OUT}]} -eq 1 ]] && SHADE=${REVERSE} || SHADE=''
			eval ${_LIST_LINE_ITEM} # Output the line
		else
			printf "\n" # Output filler
		fi
		((_LIST_NDX++))
		((CURSOR_NDX++))
	done

	list_do_header ${PAGE} ${MAX_PAGE}
}

list_repaint_section () {
	local -A MC=($(msg_get_box_coords kv))
	local ROWS=${1}
	local PAGE=${2}
	local START_ROW=${MC[X]}
	local END_ROW=0
	local HDR_OFFSET=${#_LIST_HEADER}
	local NDX=${_LIST_NDX}
	local CURSOR=0
	local DISPLAY_ROWS=0
	local R

	DISPLAY_ROWS=$(( ${_LIST_INDEX_RANGE[2]} - ${_LIST_INDEX_RANGE[1]} +1 ))
	CURSOR=$(( START_ROW - 1 ))

	[[ ${_LIST_HEADER_BREAK} == 'true' ]] && ((HDR_OFFSET++))
	((HDR_OFFSET--))

	START_ROW=$(( ${_LIST_INDEX_RANGE[1]} + START_ROW - HDR_OFFSET - 1))
	END_ROW=$((START_ROW + ROWS + 1))
	_LIST_NDX=$(( START_ROW - 1 ))

#	((CURSOR++))
#	((_LIST_NDX++))
#	tput cup ${CURSOR} 0
#	echo -n "-------- START ROW --------"
#	msg_box -p "PAGE:${PAGE} CURSOR:${CURSOR} START_ROW:${START_ROW} END_ROW:${END_ROW} _LIST_NDX:${_LIST_NDX}"
#	return

	for ((R=START_ROW; R<=END_ROW; R++));do
		((CURSOR++))
		((_LIST_NDX++))
		tput cup ${CURSOR} 0 # tput is base 0
		if [[ $_BARLINES == 'true' ]];then
			BARLINE=$((_LIST_NDX % 2)) # Barlining 
			[[ ${BARLINE} -ne 0 ]] && BAR=${BLACK_BG} || BAR="" # Barlining
		fi
		if [[ ${_LIST_NDX} -le ${#_LIST} ]];then
			#echo -n "repainting START_ROW:${START_ROW} HDR_OFFSET:${HDR_OFFSET} ${_LIST_NDX} ${${_LIST[${_LIST_NDX}]}[1,20]}"
			eval ${_LIST_LINE_ITEM} # Output the line
		else
 			tput ech ${_MAX_COLS}
			#echo -n "repainting START_ROW:${START_ROW} HDR_OFFSET:${HDR_OFFSET} ${_LIST_NDX} ${${_LIST[${_LIST_NDX}]}[1,20]}"
		fi
	done

	_LIST_NDX=${NDX}
}

list_search () {
	local PAGE=${1} 
	local NEXT=${2}
	local HDR
	local H_CTR
	local H_POS=7
	local INIT
	local KEY
	local PROMPT
	local RC
	local ROW
	local T P R C N
	local TARGET
	local TNDX
	local V_CTR

	[[ ${_LIST_IS_SEARCHABLE} == 'false' ]] && return

	/bin/rm -f /tmp/list_get_page_target.out # debug trace

	#Initialize scan loop
	if [[ ${NEXT} == 'get_key' ]];then # start new search
		kbd_suspend
		HDR="<m>$(str_unicode_line 12) List Search (Next:<w>><m>, Prev:<w><<m>) $(str_unicode_line 12)<N>"

		V_CTR=$(( _MAX_ROWS/2 - 4 )) # vertical center
 		H_CTR=$(coord_center $((_MAX_COLS-3)) ${#HDR}) # horiz center
 
 		for ((ROW=1;ROW<=${H_POS};ROW++));do # clear a space to place the UI
 			tput cup $(( V_CTR + ROW )) ${H_CTR}
 			tput ech ${#HDR}
 		done
 
 		msg_box -x${V_CTR} -y${H_CTR} "${HDR}" # display header
 
 		tput cup $((V_CTR+4)) $((H_CTR+2))
 		PROMPT="${E_RESET}${E_BOLD}Find${E_RESET}:"
 
		kbd_activate
 		TARGET=$(inline_vi_edit ${PROMPT} "") # call line editor
		msg_box_clear X Y ${H_POS} W  # clear box containing inline edit 

 		if [[ -z ${TARGET} ]];then # user entered nothing
			list_repaint_section ${H_POS} ${PAGE}
			_TARGET_NDX=${_LIST_NDX}
			_TARGET_CURSOR=${CURSOR_NDX}
			_TARGET_PAGE=${PAGE}
			_TARGET_KEY=''
			TARGET=''
			return # early return
		fi

		if ! list_set_targets ${TARGET};then
			for ((ROW=0;ROW<=${H_POS};ROW++));do # clear a space to place the MSG
				tput cup $(( V_CTR + ROW )) ${H_CTR}
				tput ech ${#HDR}
			done
			msg_box -x$((V_CTR)) -y$((H_CTR+10)) -p -PK "<m>List Search<N>| |\"<w>${TARGET}<N>\" - <r>NOT<N> found" 
			msg_box_clear
			list_repaint_section $((H_POS+3)) ${PAGE}
			_TARGET_NDX=${_LIST_NDX}
			_TARGET_CURSOR=${CURSOR_NDX}
			_TARGET_PAGE=${PAGE}
			_TARGET_KEY=''
			TARGET=''
			return # early return
		fi

		list_repaint_section $((H_POS+1)) ${PAGE}

		_TARGET_KEY=$(list_get_page_target ${NEXT})
		IFS=":" read _TARGET_NDX _TARGET_CURSOR _TARGET_PAGE TNDX <<<${_TARGET_KEY}
		_TARGETS[${TNDX}]="${_TARGET_NDX}:${_TARGET_CURSOR}:${_TARGET_PAGE}:last_target"

		[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${LINENO} NEXT:${NEXT} TNDX:${TNDX} _TARGET_KEY:${_TARGET_KEY} _TARGET_NDX:${_TARGET_NDX} _TARGET_CURSOR:${_TARGET_CURSOR} _TARGET_PAGE:${_TARGET_PAGE}"

		list_item_highlight ${_LIST_LINE_ITEM} $(( TOP_OFFSET + (CURSOR_NDX-1) )) 0 ${SHADE} # First target

	else
		[[ -z ${_TARGET_KEY} ]] && return

		_TARGET_KEY=$(list_get_page_target ${NEXT})
		IFS=":" read _TARGET_NDX _TARGET_CURSOR _TARGET_PAGE TNDX <<<${_TARGET_KEY}

		N=${_TARGETS[(i)*last_target]}
		_TARGETS[${N}]=$(sed "s/last_target/seen/" <<<${_TARGETS[${N}]})
		_TARGETS[${TNDX}]="${_TARGET_NDX}:${_TARGET_CURSOR}:${_TARGET_PAGE}:last_target"

		[[ ${_DEBUG} -gt 0 ]] && dbg "${0}:${LINENO} NEXT:${NEXT} TNDX:${TNDX} _TARGET_KEY:${_TARGET_KEY} _TARGET_NDX:${_TARGET_NDX} _TARGET_CURSOR:${_TARGET_CURSOR} _TARGET_PAGE:${_TARGET_PAGE}"
	fi
}

list_select () {
	local -a ACTION_MSGS
	local -a LIST_RANGE
	local -a LIST_SELECTION=()
	local _LIST_NDX=0
	local BARLINE BAR SHADE
	local BOT_OFFSET=3
	local COLS=$(tput cols)
	local CURSOR_NDX=0
	local DIR_KEY
	local HDR_NDX
	local ITEM
	local KEY
	local KEY_LINE=''
	local L R S 
	local LAST__LIST_NDX=0
	local LINE_ITEM
	local LIST_DATA
	local NEXT
	local MAX_CURSOR
	local MAX_DISPLAY_ROWS
	local MAX_ITEM
	local MAX_LINE_WIDTH=$(((COLS - ${#${#_LIST}}) - 10)) # Display-cols minus width-of-line-number plus a 10 space margin
	local MAX_PAGE
	local OUT
	local PAGE=1
	local PAGE_BREAK
	local PAGE_RANGE_BOT
	local PAGE_RANGE_TOP
	local PARTIAL
	local RANGE_CHECK_OPTION
	local REM
	local ROWS=$(tput lines)
	local SELECTED_COUNT=0
	local SELECTION
	local SELECTION_LIMIT=$(list_get_selection_limit)
	local TOP_OFFSET
	local USER_PROMPT

	# Initialization
	_LIST=(${@})
	MAX_ITEM=${#_LIST}
	_SELECT_ALL=false

	# Hide cursor
	if [[ ${_CURSOR_STATE} == 'on' ]];then
		tput civis >&2
		_CURSOR_STATE=off
	fi

	# Default sort settings
	if [[ ${_LIST_SORT_COL_DEFAULT} -ne 0 ]];then
		_SORT_DIRECTION[${_LIST_SORT_COL_DEFAULT}]=a
		list_sort ${_LIST_SORT_COL_DEFAULT}
	fi
	 
	[[ ${_DEBUG} -gt 0 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@} _LIST:${#_LIST}"
	
	# Calculate display rows based on number of header lines
	[[ -z ${_LIST_HEADER} ]] && _LIST_HEADER+='printf "List of %-d items\tPage %-d of %-d \tSelected:%-d" ${MAX_ITEM} ${PAGE} ${MAX_PAGE} ${SELECTED_COUNT}' # Default header
	TOP_OFFSET=${#_LIST_HEADER}
	[[ ${_LIST_HEADER_BREAK} == 'true' ]] && ((TOP_OFFSET++))

	# Boundaries
	MAX_DISPLAY_ROWS=$(( ROWS-(TOP_OFFSET+BOT_OFFSET) ))
	MAX_PAGE=$((MAX_ITEM / MAX_DISPLAY_ROWS))
	REM=$((MAX_ITEM % MAX_DISPLAY_ROWS))
	[[ ${REM} -ne 0 ]] && ((MAX_PAGE++))

	# Assign Defaults for Header, Prompt, and Line_Item formatting
	[[ -z ${_LIST_LINE_ITEM} ]] && _LIST_LINE_ITEM='printf "${BOLD}${WHITE_FG}%*d${RESET}) ${SHADE}%s${RESET}\n" ${#MAX_ITEM} ${_LIST_NDX} ${${_LIST[${_LIST_NDX}]}[1,${MAX_LINE_WIDTH}]}'
	[[ -n ${_LIST_PROMPT} ]] && USER_PROMPT=${_LIST_PROMPT} || USER_PROMPT="Enter to toggle selection"
	[[ -n ${_LIST_ACTION_MSGS[1]} ]] && ACTION_MSGS[1]=${_LIST_ACTION_MSGS[1]} || ACTION_MSGS[1]="process"
	[[ -n ${_LIST_ACTION_MSGS[2]} ]] && ACTION_MSGS[2]=${_LIST_ACTION_MSGS[2]} || ACTION_MSGS[2]="item"
	[[ -n ${_PROMPT_KEYS} ]] && KEY_LINE=$(eval ${_PROMPT_KEYS}) || KEY_LINE=$(printf "Press ${WHITE_FG}%s%s%s%s${RESET} Home End PgUp PgDn <${WHITE_FG}n${RESET}>ext, <${WHITE_FG}p${RESET}>rev, <${WHITE_FG}b${RESET}>ottom, <${WHITE_FG}t${RESET}>op, <${WHITE_FG}c${RESET}>lear, vi[${WHITE_FG}j,k${RESET}], <${WHITE_FG}a${RESET}>ll${RESET}, <${GREEN_FG}Enter${RESET}>${RESET}, <${WHITE_FG}q${RESET}>uit${RESET}" $'\u2190' $'\u2191' $'\u2193' $'\u2192')
	[[ -n ${KEY_LINE} ]] && USER_PROMPT="${KEY_LINE}\n${USER_PROMPT}"

	# Navigation init
	PAGE_BREAK=false
	PAGE_RANGE_TOP=1
	PAGE_RANGE_BOT=${MAX_DISPLAY_ROWS}
	list_set_index_range ${PAGE_RANGE_TOP} ${PAGE_RANGE_BOT}
	# End of Initialization

	# Display current page of list items
	while true;do
		tput clear

		# Prepare page display
		# Navigation; maintain 2 indexes; 1 for array access (_LIST_NDX), 1 for cursor position (CURSOR_NDX)
		if [[ ${PAGE_BREAK} == 'true' ]];then
			PAGE=$(list_get_next_page ${DIR_KEY} ${PAGE} ${MAX_PAGE}) # Next page
			PAGE_RANGE_TOP=$(( (PAGE-1) * MAX_DISPLAY_ROWS +1 ))
			PAGE_RANGE_BOT=$(( (PAGE_RANGE_TOP-1) + MAX_DISPLAY_ROWS ))
			list_set_index_range ${PAGE_RANGE_TOP} ${PAGE_RANGE_BOT}
			PAGE_BREAK=false # Reset
		elif [[ ${_HOLD_PAGE} == 'true' ]];then
			PAGE=${_CURRENT_PAGE}
			PAGE_RANGE_TOP=$(( (_CURRENT_PAGE-1) * MAX_DISPLAY_ROWS +1 ))
			PAGE_RANGE_BOT=$(( (PAGE_RANGE_TOP-1) + MAX_DISPLAY_ROWS ))
			list_set_index_range ${PAGE_RANGE_TOP} ${PAGE_RANGE_BOT}
			_HOLD_PAGE=false # Reset
		fi

		_CURRENT_PAGE=${PAGE} # Store current page position

		LIST_RANGE=($(list_get_index_range))
		PAGE_RANGE_TOP=${LIST_RANGE[1]}
		PAGE_RANGE_BOT=${LIST_RANGE[2]}

		[[ ${PAGE_RANGE_BOT} -gt ${MAX_ITEM} ]] && PAGE_RANGE_BOT=${MAX_ITEM} # Page boundary check

		list_do_header ${PAGE} ${MAX_PAGE}

		[[ ${_NO_TOP_OFFSET} == 'false' ]] && tput cup ${TOP_OFFSET} 0 # Place cursor
		 
		# Initialize page display
		_LIST_NDX=$((PAGE_RANGE_TOP-1)) # Prime page top

		for ((R=0; R<${MAX_DISPLAY_ROWS}; R++));do
			[[ ${_DEBUG} -ge 4 && -n ${_LIST[${_LIST_NDX}]} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: _LIST display loop - ROW:${R} _LIST_NDX:${_LIST_NDX} - _LIST:${_LIST[${_LIST_NDX}]}"
			((_LIST_NDX++)) # Increment array index

			if [[ $_BARLINES == 'true' ]];then # Barlining 
				[[ ${PAGE_BREAK} == 'false' ]] && BARLINE=$((_LIST_NDX % 2))
				[[ ${BARLINE} -ne 0 ]] && BAR=${BLACK_BG} || BAR=""
			fi

			if [[ ${_LIST_NDX} -le ${MAX_ITEM} ]];then
				OUT=${_LIST_NDX}
				[[ ${_LIST_SELECTED[${OUT}]} -eq 1 ]] && SHADE=${REVERSE} || SHADE=''
				eval ${_LIST_LINE_ITEM} # Output line item
			else
				printf "\n" # Output filler
			fi
		done

		# Page is displayed; initialize navigation
		if [[ ${_HOLD_CURSOR} == 'true' ]];then
			_LIST_NDX=${_CURRENT_ARRAY} # Hold array position
			CURSOR_NDX=${_CURRENT_CURSOR} # Hold cursor position
			[[ ${_LIST_SELECTED[${_LIST_NDX}]} -eq 1 ]] && SHADE=${REVERSE} || SHADE='' 
			list_item_highlight ${_LIST_LINE_ITEM} $(( (CURSOR_NDX+TOP_OFFSET) -1)) 0 ${SHADE} # Highlight current item
			_HOLD_CURSOR=false # Reset
		else
			_LIST_NDX=${PAGE_RANGE_TOP} # Page top
			CURSOR_NDX=1 # Page top
			[[ ${_LIST_SELECTED[${_LIST_NDX}]} -eq 1 ]] && SHADE=${REVERSE} || SHADE='' 
			list_item_highlight ${_LIST_LINE_ITEM} ${TOP_OFFSET} 0 ${SHADE} # Highlight first item
		fi

		while true;do
			LAST__LIST_NDX=${_LIST_NDX} # Store current index
			_CURRENT_CURSOR=${CURSOR_NDX} # Store current cursor position

			# Partial page boundary
			[[ ${PAGE} -eq ${MAX_PAGE} ]] && MAX_CURSOR=$(( (MAX_ITEM-PAGE_RANGE_TOP) +1 )) || MAX_CURSOR=${MAX_DISPLAY_ROWS}
	
			# WAIT FOR INPUT - get list selection(s)  - if only 1 item in list, skip selection and process item
			 
			KEY=$(get_keys ${USER_PROMPT})

			case ${KEY} in
				1) DIR_KEY=u;((CURSOR_NDX--));_LIST_NDX=$(list_set_index ${DIR_KEY} ${_LIST_NDX} ${PAGE_RANGE_TOP} ${PAGE_RANGE_BOT} ${MAX_ITEM});; # Up Arrow
				2) DIR_KEY=d;((CURSOR_NDX++));_LIST_NDX=$(list_set_index ${DIR_KEY} ${_LIST_NDX} ${PAGE_RANGE_TOP} ${PAGE_RANGE_BOT} ${MAX_ITEM});; # Down Arrow
				3) DIR_KEY=t;CURSOR_NDX=1;_LIST_NDX=${PAGE_RANGE_TOP};; # Left Arrow
				4) DIR_KEY=b;CURSOR_NDX=${MAX_CURSOR};_LIST_NDX=${PAGE_RANGE_BOT};; # Right Arrow
				5) DIR_KEY=p;PAGE_BREAK=true;break;; # PgUp
				6) DIR_KEY=n;PAGE_BREAK=true;break;; # PgDn
				7) DIR_KEY=fp;PAGE_BREAK=true;break;; # Home
				8) DIR_KEY=lp;PAGE_BREAK=true;break;; # End
				32) [[ ${_SELECTABLE} == 'true' ]] && list_toggle_selected ${_LIST_NDX};; # Space
				47|62|60)	[[ ${KEY} -eq 47 ]] && NEXT=get_key;
								[[ ${KEY} -eq 60 ]] && NEXT=rev;
								[[ ${KEY} -eq 62 ]] && NEXT=fwd;
								list_search ${PAGE} ${NEXT};
								if [[ ${_TARGET_PAGE} -eq ${PAGE} ]];then # same page - move cursor
									CURSOR_NDX=${_TARGET_CURSOR} && _LIST_NDX=${_TARGET_NDX}
								else # different page - navigate
									DIR_KEY=${_TARGET_PAGE}; _CURRENT_ARRAY=${_TARGET_NDX}; _CURRENT_CURSOR=${_TARGET_CURSOR}; _HOLD_CURSOR=true; PAGE_BREAK=true; break
								fi
								;;
				97) [[ ${_SELECTABLE} == 'true' ]] && list_toggle_all ${PAGE_RANGE_TOP} ${TOP_OFFSET} ${MAX_DISPLAY_ROWS} ${MAX_ITEM} ${PAGE} ${MAX_PAGE} toggle;; # 'a' Toggle all
				98) DIR_KEY=lp;PAGE_BREAK=true;break;; # 'b' Top row last page
				99) [[ ${_SELECTABLE} == 'true' ]] && list_toggle_all ${PAGE_RANGE_TOP} ${TOP_OFFSET} ${MAX_DISPLAY_ROWS} ${MAX_ITEM} ${PAGE} ${MAX_PAGE} off;; # 'c' Clear
				104) DIR_KEY=t;CURSOR_NDX=1;_LIST_NDX=${PAGE_RANGE_TOP};; # 'h' Top Row current page
				106) DIR_KEY=d;((CURSOR_NDX++));_LIST_NDX=$(list_set_index ${DIR_KEY} ${_LIST_NDX} ${PAGE_RANGE_TOP} ${PAGE_RANGE_BOT} ${MAX_ITEM});; # 'j' Next row
				107) DIR_KEY=u;((CURSOR_NDX--));_LIST_NDX=$(list_set_index ${DIR_KEY} ${_LIST_NDX} ${PAGE_RANGE_TOP} ${PAGE_RANGE_BOT} ${MAX_ITEM});; # 'k' Prev row
				108) DIR_KEY=b;CURSOR_NDX=${MAX_CURSOR};_LIST_NDX=${PAGE_RANGE_BOT};; # 'l' Bottom Row current page
				110) DIR_KEY=n;PAGE_BREAK=true;break;; # 'n' Next page
				112) DIR_KEY=p;PAGE_BREAK=true;break;; # 'p' Prev page
				113) exit_request;; # 'q' Quit app request
				115) list_call_sort;_HOLD_PAGE=true;break;; # 's' Sort
				116) DIR_KEY=fp;PAGE_BREAK=true;break;; # 't' Top row first page
				122) return -1;; # 'z' Quit loop
				${_CB_KEY}) ${_KEY_CALLBACK_FUNC};return -2;; # Custom runtime key
				0) SELECTED_COUNT=$(list_get_selected_count); # Enter
					_HOLD_PAGE=true;
					_HOLD_CURSOR=true;
					if [[ ${SELECTED_COUNT} -eq 0 ]];then
						break 2
					else
						if [[ ${_CLIENT_WARN} == 'true' ]];then
							list_warn_invisible_rows ${MAX_DISPLAY_ROWS} ${PAGE}
							break 2
						else
							if [[ ${_SELECTION_LIMIT} -ne 0 ]];then
								msg_box -p "${(C)ACTION_MSGS[1]} $(str_pluralize ${ACTION_MSGS[2]} ${SELECTED_COUNT})?|(y/n)"
							else
								msg_box -p "${(C)ACTION_MSGS[1]} ${SELECTED_COUNT} $(str_pluralize ${ACTION_MSGS[2]} ${SELECTED_COUNT})?|(y/n)"
							fi
							if [[ ${_MSG_KEY} == 'y' ]];then
								return ${SELECTED_COUNT}
							else
								continue
							fi
						fi
					fi
					;;
			esac

			# Cursor index boundary
			[[ ${CURSOR_NDX} -gt ${MAX_CURSOR} ]] && CURSOR_NDX=1
			[[ ${CURSOR_NDX} -lt 1 ]] && CURSOR_NDX=${MAX_CURSOR}

			# Clear highlight of last line output
			ITEM=${_LIST_NDX}; _LIST_NDX=${LAST__LIST_NDX} # Save value of _LIST_NDX
			[[ ${_LIST_SELECTED[${_LIST_NDX}]} -eq 1 ]] && SHADE=${REVERSE} || SHADE='' 
			list_item_normal ${_LIST_LINE_ITEM} $(( TOP_OFFSET + (_CURRENT_CURSOR-1) )) 0 #_CURRENT_CURSOR is value before nav key

			# Highlight current line output
			_LIST_NDX=${ITEM} # Restore value of _LIST_NDX
			[[ ${_LIST_SELECTED[${_LIST_NDX}]} -eq 1 ]] && SHADE=${REVERSE} || SHADE='' 
			list_item_highlight ${_LIST_LINE_ITEM} $(( TOP_OFFSET + (CURSOR_NDX-1) )) 0 ${SHADE} # CURSOR_NDX is value after nav key

			_CURRENT_ARRAY=${ITEM} # Store current array position
		done
	done

	return $(list_get_selected_count)
}

list_select_range () {
	local -a RANGE=($@)
	local -a SELECTED
	local NDX=0

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"
	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: RANGE:${RANGE}"

	for (( NDX=${RANGE[1]}; NDX <= ${RANGE[2]}; NDX++ ));do
		[[ ${_CLEAR_GHOSTS} == 'false' && ${_LIST_SELECTED[${NDX}]} -ge ${_GHOST_ROW} ]] && continue
		SELECTED[${NDX}]=${NDX}
	done

	echo ${SELECTED}
}

list_set_action_msgs () {
	_LIST_ACTION_MSGS=(${@})
}

list_set_barlines () {
	_BARLINES=${1}
}

list_set_clear_ghosts () {
	_CLEAR_GHOSTS=${1}
}

list_set_client_warn () {
	_CLIENT_WARN=${1}
}

list_set_header () {
	local HDR_LINE=${1}

	[[ ${_DEBUG} -ge 1 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@} HEADER LINE:${WHITE_FG}${#_LIST_HEADER}${RESET}"

	[[ -z ${HDR_LINE:gs/ //} ]] && HDR_LINE="printf ' '"

	_LIST_HEADER+=${HDR_LINE}
	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: RAW HEADER:${HDR_LINE}"
	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ECHO HDR:${WHITE_FG}${#_LIST_HEADER}${RESET}:\"$(eval echo ${HDR_LINE})\""
	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: EVAL HDR:${WHITE_FG}${#_LIST_HEADER}${RESET}:\"$(eval ${HDR_LINE})\""
}

list_set_header_break_color () {
	_LIST_HEADER_BREAK_COLOR=${1}
}

list_set_header_callback () {
	_HEADER_CALLBACK_FUNC=${1}
}

list_set_header_init () {
	_LIST_HEADER=()
}

list_set_index () {
	local KEY=${1}
	local ROW_NDX=${2}
	local PAGE_RANGE_TOP=${3}
	local PAGE_RANGE_BOT=${4}
	local MAX_ITEM=${5}
	local NDX

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${PAGE_RANGE_BOT} -gt ${MAX_ITEM} ]] && PAGE_RANGE_BOT=${MAX_ITEM}

	case ${KEY} in
		u)	((ROW_NDX--));NDX=${ROW_NDX};;
		d)	((ROW_NDX++));NDX=${ROW_NDX};;
	esac

	[[ ${NDX} -lt ${PAGE_RANGE_TOP} ]] && NDX=${PAGE_RANGE_BOT}
	[[ ${NDX} -gt ${PAGE_RANGE_BOT} ]] && NDX=${PAGE_RANGE_TOP}

	echo ${NDX}
}

list_set_index_range () {
	local TOP_NDX=${1}
	local BOT_NDX=${2}

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@} TOP_NDX:${TOP_NDX} BOT_NDX:${BOT_NDX}"

	[[ ${TOP_NDX} -lt 0 ]] && return 1 # TOP_NDX must be >= 0
	[[ ${BOT_NDX} -lt 0 ]] && return 1 # BOT_NDX must be >= 0

	_LIST_INDEX_RANGE=()
	_LIST_INDEX_RANGE+=${TOP_NDX}
	_LIST_INDEX_RANGE+=${BOT_NDX}

	return 0
}

list_set_key_callback () {
	_CB_KEY=${1}
	_KEY_CALLBACK_FUNC=${2}
}

list_set_key_msg () {
	_PROMPT_KEYS=${@}
}

list_set_line_item () {
	_LIST_LINE_ITEM=${@}
}

list_set_no_top_offset () {
	_NO_TOP_OFFSET=true
}

list_set_page_hold () {
	_HOLD_PAGE=true
}

list_set_pages () {
	local P=0
	local L
	local TOP
	local BOT
	local -A PAGES

	for ((L=1; L <= ${#_LIST}; L++));do
		if [[ $(( L % MAX_DISPLAY_ROWS )) -eq 0 ]];then
			((P++))
			TOP=$(( L - MAX_DISPLAY_ROWS +1 ))
			PAGES[${P}]="${TOP}:${L}"
		fi
	done

	# last page
	BOT=$(cut -d: -f2 <<<${PAGES[${P}]})
	TOP=$(( BOT+1 ))
	BOT=$(( L-1 ))
	((P++))
	PAGES[${P}]=${TOP}:${BOT}

	[[ ${_DEBUG} -gt 1 ]] && dbg "${0}:${LINENO} Set ${#PAGES} page boundaries"

	echo "${(kv)PAGES}"
}

list_set_prompt () {
	[[ -n ${@} ]] && _LIST_PROMPT=${@}
}

list_set_searchable () {
	_LIST_IS_SEARCHABLE=${1}
}

list_set_selectable () {
	_SELECTABLE=${1}
}

list_set_select_callback () {
	_SELECT_CALLBACK_FUNC=${1}
}

list_set_selected () {
	local -i ROW=${1}
	local -i VAL=${2}

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${functrace[1]} ARGC:${#@} ROW:${ROW} VAL:${VAL}"

	_LIST_SELECTED[${ROW}]=${VAL}
}

list_set_selection_limit () {
	_SELECTION_LIMIT=${1}
}

list_set_sortable () {
	_LIST_IS_SORTABLE=${1}
}

list_set_sort_default () {
	_LIST_SORT_COL_DEFAULT=${1}
	if validate_is_integer ${_LIST_SORT_COL_DEFAULT};then
		return
	else
		msg_box -p -PK "echo ${0}: error _LIST_SORT_COL_DEFAULT not integer:${_LIST_SORT_COL_DEFAULT}"
	fi
}

list_set_max_sort_col () {
	_LIST_SORT_COL_MAX=${1}
	if validate_is_integer ${_LIST_SORT_COL_MAX};then
		return
	else
		msg_box -p -PK "echo ${0}: error _LIST_SORT_COL_MAX not integer:${_LIST_SORT_COL_MAX}"
	fi
}

list_set_sort_type () {
	_LIST_SORT_TYPE=${1}
}

list_set_targets () {
	local TARGET=${@}
	local TOP BOT
	local C P R
	local -A PAGES=($(list_set_pages))

	_TARGETS=("${(f)$(
	for P in ${(onk)PAGES};do
		IFS=":" read TOP BOT <<<${PAGES[${P}]}
		for ((R=TOP; R<=BOT; R++));do
			C=$((R-TOP+1))
			echo "${C}:${P}:${_LIST[${R}]:t}"
		done
	done | grep --color=never -ni -P ":.*${TARGET}.*$" | perl -p -e "s/^(\d+:\d+:\d+)(.*)$/\1/" # return key:NDX/CURSOR/PAGE
	)}")

	[[ -z ${_TARGETS} ]] && return 1 || return 0
}

list_show_key () {
	local KEY=${@}

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${KEY} == '-' ]] && echo -n - '-' >&2 && return # Show dash and return
	echo -n ${KEY} >&2 # Show key value
}

list_verify_sort_params () {
	if ! validate_is_integer ${_LIST_SORT_COL_MAX};then
		msg_box -p -PK "Invalid sort column:${_LIST_SORT_COL_MAX}"
		return 1
	fi

	if [[ ${_LIST_SORT_TYPE} == 'assoc' ]];then
		if [[ -z ${_SORT_TABLE} ]];then
			msg_box -p -PK "_SORT_TABLE:${#_SORT_TABLE} is not populated"
			return 1
		fi
	fi

	return 0
}

list_sort () {
	local SORT_COL=${1}
	local FIELD_MAX
	
	[[ ${_DEBUG} -ge 2 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	if ! list_verify_sort_params;then
		return 1
	fi

	if [[ ${_LIST_SORT_COL_MAX} -eq 0 ]];then
		FIELD_MAX=$(get_delim_field_cnt ${_LIST[1]})
	else
		FIELD_MAX=${_LIST_SORT_COL_MAX}
	fi

	if [[ -z ${SORT_COL} ]];then
		msg_box -p "Enter column to sort:|(1 through ${FIELD_MAX})"
		SORT_COL=${_MSG_KEY}
	fi

	if [[ ${SORT_COL} -lt 1 || ${SORT_COL} -gt ${FIELD_MAX} ]];then
		msg_box -p -PK "Invalid sort column:${SORT_COL}"
		return 1
	fi

	[[ ${_DEBUG} -ge 2 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: COLUMN to sort:${SORT_COL}"

	list_sort_set_direction ${SORT_COL}
	[[ ${_DEBUG} -ge 2 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: sort direction set:${_SORT_DIRECTION[${SORT_COL}]}"

	_LIST=("${(f)$(list_sort_flat ${_LIST_DELIM} ${SORT_COL} ${_SORT_DIRECTION[${SORT_COL}]} _LIST)}") # Forward sort default

	[[ ${_DEBUG} -ge 2 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: list SORTED:${_LIST[1]}"
}

list_sort_assoc () {
	local COLUMN=${1:=null} # direct call - no prompts
	local ARRAY
	local -a SLIST
	local SORT_COL
	local SORT_CMD
	local S

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	if ! list_verify_sort_params;then
		return 1
	fi

	if [[ ${COLUMN} == 'null' ]];then
		msg_box -p "Enter column to sort:|(1 through ${_LIST_SORT_COL_MAX})"
		SORT_COL=${_MSG_KEY}

		validate_is_integer ${SORT_COL}
		if [[ ${?} -ne 0 || ${SORT_COL} -lt 1 || ${SORT_COL} -gt ${_LIST_SORT_COL_MAX} ]];then
			msg_box -p -PK "Not integer:|Need 1 through ${_LIST_SORT_COL_MAX}"
			return 1 # Bounce
		fi
	else
		SORT_COL=${COLUMN}
	fi

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: _SORT_TABLE:${_SORT_TABLE}"
	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: _SORT_COL:${SORT_COL}"
	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARRAY to sort:${ARRAY}"

	ARRAY=${_SORT_TABLE[${SORT_COL}]}
	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: _SORT_TABLE array name:${ARRAY}"
	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: _SORT_TABLE elements:${#${(P)ARRAY}}"

	[[ ${#${(P)ARRAY}} -eq 0 ]] && msg_box -p -PK "_SORT_TABLE ${(P)ARRAY} has no rows" && return 1 # Bounce

	list_sort_set_direction ${SORT_COL}
	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: sort direction set:${_SORT_DIRECTION[${SORT_COL}]}"

	if [[ ${_SORT_DIRECTION[${SORT_COL}]} == "a" ]];then
		_LIST=("${(f)$(
			for S in ${(k)${(P)ARRAY}};do
				echo "${S}|${${(P)ARRAY}[${S}]}"
				[[ ${_DEBUG} -ge 4 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: sort line:${S}|${${(P)ARRAY}[${S}]}"
			done | sort -t'|' -k2 | cut -d'|' -f1
		)}")
	else
		_LIST=("${(f)$(
			for S in ${(k)${(P)ARRAY}};do
				echo "${S}|${${(P)ARRAY}[${S}]}"
				[[ ${_DEBUG} -ge 4 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: sort line:${S}|${${(P)ARRAY}[${S}]}"
			done | sort -r -t'|' -k2 | cut -d'|' -f1
		)}")
	fi
}

list_sort_flat () {
	local DELIM=${1}
	local SORT_COL=${2}
	local DIRECTION=${3}
	local ARR_NAME=${4}
	local CAL_SORT=${5:=false}
	local -a RANKED
	local RANK_COL
	local S L

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"
	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGS:DELIM:${DELIM}, SORT_COL:${SORT_COL}, DIRECTION:${DIRECTION}, ARR_NAME:${ARR_NAME}"

	for L in ${(P)ARR_NAME};do
		RANK_COL=$(cut -d "${DELIM}" -f ${SORT_COL} <<<${L})
		[[ ${RANK_COL} =~ 'year' ]] && RANKED+="${_CAL_SORT[year]}|${L}" && continue
		[[ ${RANK_COL} =~ 'month' ]] && RANKED+="${_CAL_SORT[month]}|${L}" && continue
		[[ ${RANK_COL} =~ 'week' ]] && RANKED+="${_CAL_SORT[week]}|${L}" && continue
		[[ ${RANK_COL} =~ 'day' ]] && RANKED+="${_CAL_SORT[day]}|${L}" && continue
		[[ ${RANK_COL} =~ 'hour' ]] && RANKED+="${_CAL_SORT[hour]}|${L}" && continue
		[[ ${RANK_COL} =~ 'minute' ]] && RANKED+="${_CAL_SORT[minute]}|${L}" && continue
		[[ ${RANK_COL} =~ ':' ]] && RANKED+="B999|${L}" && continue
		[[ ${RANK_COL} =~ '-' ]] && RANKED+="A888|${L}" && continue
		[[ ${RANK_COL} =~ '^\d{4}-\d{2}-\d{2}' ]] && RANKED+="${L[1-10]}|${L}" && continue
		[[ ${RANK_COL} =~ '\d{4}$' ]] && RANKED+="ZZZZ|$(echo ${L} | perl -pe 's/(.*)(\d{4})$/\2\1\2/g')" && continue
		[[ ${RANK_COL} =~ '\d[.]\d\D' ]] && RANKED+="ZZZZ|$(echo ${L} | perl -pe 's/([.]\d)(.*)((G|M).*)$/${1}0 ${3}/g')" && continue
		[[ ${RANK_COL} =~ 'Mi?B' ]] && RANKED+="A888|${L}" && continue
		[[ ${RANK_COL} =~ 'Gi?B' ]] && RANKED+="B999|${L}" && continue
		RANKED+="${RANK_COL}|${L}"
	done

# Debugging ranked data
#	/bin/rm -f /tmp/list_sorted
#	for S in ${RANKED};do
#		echo ${S} >> /tmp/list_sorted
#	done

	if [[ ${DIRECTION} == 'd' ]];then # Descending
		for S in ${(On)RANKED};do
			cut -d '|' -f2- <<<${S}
		done
	else
		for S in ${(on)RANKED};do # Ascending
			cut -d '|' -f2- <<<${S}
		done
	fi
}

list_sort_set_direction () {
	local SORT_COL=${1}

	[[ -z ${SORT_COL} ]] && SORT_COL=1

	[[ ${_DEBUG} -ge 2 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGS:SORT_COL:${SORT_COL}"

	if [[ -z ${_SORT_DIRECTION[${SORT_COL}]} ]];then
		_SORT_DIRECTION[${SORT_COL}]=a
		[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Returning:${_SORT_DIRECTION[${SORT_COL}]}" # Initialize if needed
		return
	fi

	[[ ${_DEBUG} -ge 2 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Incoming sort direction:${_SORT_DIRECTION[${SORT_COL}]}"

	if [[ ${_SORT_DIRECTION[${SORT_COL}]} == "a" ]];then
		_SORT_DIRECTION[${SORT_COL}]=d
	else
		_SORT_DIRECTION[${SORT_COL}]=a
	fi

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Returning:${_SORT_DIRECTION[${SORT_COL}]}"
}

list_toggle_all () {
	local _LIST_NDX=${1}
	local TOP_OFFSET=${2}
	local MAX_DISPLAY_ROWS=${3}
	local MAX_ITEM=${4}
	local PAGE=${5}
	local MAX_PAGE=${6}
	local ACTION=${7} 
	local -a SELECTED
	local CURSOR_NDX=1
	local FIRST_ITEM=$(( ( (PAGE * MAX_DISPLAY_ROWS ) - MAX_DISPLAY_ROWS )+1))
	local LAST_ITEM=$(( PAGE * MAX_DISPLAY_ROWS ))
	local HIGHLIGHTING=false
	local OUT
	local S R

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  _LIST_NDX:${_LIST_NDX}, TOP_OFFSET:${TOP_OFFSET}, MAX_DISPLAY_ROWS:${MAX_DISPLAY_ROWS}, MAX_ITEM:${MAX_ITEM}, PAGE:${PAGE}, ACTION:${ACTION}, FIRST_ITEM:${FIRST_ITEM}, LAST_ITEM:${LAST_ITEM}"

	[[ ${LAST_ITEM} -gt ${MAX_ITEM} ]] && LAST_ITEM=${MAX_ITEM} # Partial page
	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  LAST_ITEM:${LAST_ITEM}, MAX_ITEM:${MAX_ITEM}"

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  SELECTED:${#SELECTED}, FIRST_ITEM:${FIRST_ITEM}, MAX_ITEM:${MAX_ITEM}"

	if [[ ${ACTION} == 'toggle' ]];then # mark/unmark all
		[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  ACTION:${ACTION}"
		[[ ${_LIST_SELECTED_PAGE[${PAGE}]} -eq 1 ]] && _LIST_SELECTED_PAGE[${PAGE}]=0 || _LIST_SELECTED_PAGE[${PAGE}]=1 # toggle state

		if [[ ${MAX_PAGE} -gt 1 && ${_LIST_SELECTED_PAGE[${PAGE}]} -eq 1 ]];then # prompt only for setting rows
			msg_box -p -P"(A)ll, (P)age, or (N)one" "Select Rows"
			case ${_MSG_KEY:l} in
				a) SELECTED=($(list_select_range 1 ${MAX_ITEM})); _LIST_SELECTED_PAGE[0]=1;;
				p) SELECTED=($(list_select_range ${FIRST_ITEM} ${LAST_ITEM})); _LIST_SELECTED_PAGE[0]=0;;
				*) SELECTED=();
			esac
			msg_box_clear

			[[ -z ${SELECTED} ]] && return
		else # set clearing scope - all or page
			if [[ ${_LIST_SELECTED_PAGE[0]} -eq 1 ]];then # all was set
				SELECTED=($(list_select_range 1 ${MAX_ITEM})) && _LIST_SELECTED_PAGE[0]=0
			else
				SELECTED=($(list_select_range ${FIRST_ITEM} ${LAST_ITEM}))
			fi
		fi

	else
		_LIST_SELECTED_PAGE[${PAGE}]=0 # clear - unmark page
		_LIST_SELECTED_PAGE[0]=0 # clear - unmark all
		SELECTED=($(list_select_range 1 ${MAX_ITEM}))
	fi

	for S in ${SELECTED};do
		_LIST_SELECTED[${S}]=${_LIST_SELECTED_PAGE[${PAGE}]}
	done

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  _HEADER_CALLBACK_FUNC:${_HEADER_CALLBACK_FUNC}"
	[[ -n ${_HEADER_CALLBACK_FUNC} ]] && ${_HEADER_CALLBACK_FUNC} 0 "${0}|${_LIST_SELECTED_PAGE[${PAGE}]}"

	tput cup ${TOP_OFFSET} 0
	for ((R=0; R<${MAX_DISPLAY_ROWS}; R++));do
		tput cup $((TOP_OFFSET+CURSOR_NDX-1)) 0
		if [[ ${_LIST_NDX} -le ${MAX_ITEM} ]];then
			OUT=${_LIST_NDX}

			if [[ $_BARLINES == 'true' ]];then
				BARLINE=$((_LIST_NDX % 2)) # Barlining 
				[[ ${BARLINE} -ne 0 ]] && BAR=${BLACK_BG} || BAR="" # Barlining
			fi

			if [[ ${_LIST_SELECTED[${OUT}]} -eq 1 ]];then
				_SELECT_ALL=true
				SHADE=${REVERSE}
			else
				_SELECT_ALL=false
				SHADE=''
			fi

			eval ${_LIST_LINE_ITEM} # Output the line
			[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  _LIST_LINE_ITEM:${_LIST_LINE_ITEM}"
		else
			printf "\n" # Output filler
		fi
		((_LIST_NDX++))
		((CURSOR_NDX++))
	done

	list_do_header ${PAGE} ${MAX_PAGE}
	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  PAGE:${PAGE}, MAX_PAGE:${MAX_PAGE}"
}

list_toggle_selected () {
	local ROW_NDX=${1}
	local COUNT=$(list_get_selected_count)

	if [[ -n ${_SELECT_CALLBACK_FUNC} ]];then
		${_SELECT_CALLBACK_FUNC} ${ROW_NDX}
		[[ ${?} -ne 0 ]] && return
	fi

	[[ ${_DEBUG} -ge 1 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ROW_NDX:${ROW_NDX} _CLEAR_GHOSTS:${_CLEAR_GHOSTS} _SELECTION_LIMIT:${_SELECTION_LIMIT}"

	[[ ${_CLEAR_GHOSTS} == 'false' && ${_LIST_SELECTED[${ROW_NDX}]} -ge ${_GHOST_ROW} ]] && return # Ignore ghosts

	if [[ ${_LIST_SELECTED[${ROW_NDX}]} -ne 1 ]];then
		if [[ ${_SELECTION_LIMIT} -ne 0 && ${COUNT} -gt $((_SELECTION_LIMIT - 1)) ]];then
			msg_box -p -PK "Selection is limited to ${_SELECTION_LIMIT}"
			msg_box_clear
			return # Ignore over limit
		fi
		list_set_selected ${ROW_NDX} 1 
		[[ -n ${_HEADER_CALLBACK_FUNC} ]] && ${_HEADER_CALLBACK_FUNC} ${ROW_NDX} "${0}|1" #all on
	else
		list_set_selected ${ROW_NDX} 0
		[[ -n ${_HEADER_CALLBACK_FUNC} ]] && ${_HEADER_CALLBACK_FUNC} ${ROW_NDX} "${0}|0" #all off
	fi

	list_do_header ${PAGE} ${MAX_PAGE}
}

list_validate_selection () {
	local -a KEYLIST
	local -A OPTION
	local -a R1
	local -a R2
	local -a SELECTED
	local -a NDX_RANGE
	local K X MSG
	local RC

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${1} == '-r' ]] && OPTION[no_range_check]=1 && shift

	KEYLIST=(${@})
	KEYLIST=("${(f)$(echo ${KEYLIST} | grep -o .)}")
	KEYLIST=$(list_parse_series ${KEYLIST})

	R1=()
	R2=()
	SELECTED=()
	for K in ${=KEYLIST};do
		if [[ ${K[1,1]} =~ "[BE]" ]];then
			case ${K[1,1]} in
				B) R1+=${K[2,${#K}]};continue;;
				E) R2+=${K[2,${#K}]};continue;;
			esac
		fi
		SELECTED+=${K} # Non range element
	done

	# Handle range elements
	if [[ -n ${R1} ]];then
		for ((X=1;X<=${#R1};X++));do
			SELECTED+=$(echo {${R1[${X}]}..${R2[${X}]}})
		done
	fi

	RC=0
	if [[ ${OPTION[no_range_check]} -ne 1 ]];then
		NDX_RANGE=($(list_get_index_range))
		MSG=$(list_is_valid_selection ${NDX_RANGE[1]} ${NDX_RANGE[-1]} ${SELECTED})
		RC=$?
	fi

	if [[ ${RC} -eq 0 ]];then
		echo ${(on)SELECTED}

		return 0
	else
		echo "Invalid Selection"

		return 1
	fi
}

list_warn_invisible_rows () {
	local MAX_DISPLAY_ROWS=${1}
	local PAGE=${2}
	local FIRST_ITEM=$((((PAGE*MAX_DISPLAY_ROWS)-MAX_DISPLAY_ROWS)+1))
	local LAST_ITEM=$((PAGE*MAX_DISPLAY_ROWS))
	local S

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ${LAST_ITEM} -gt ${MAX_ITEM} ]] && LAST_ITEM=${MAX_ITEM} # Partial page

	# Warn user of marked rows not on current page
	_INVISIBLE_ROWS_MSG=''
	for S in ${(k)_LIST_SELECTED};do
		if [[ ${S} -ge ${FIRST_ITEM} && ${S} -le ${LAST_ITEM}  ]];then
			continue 
		else
			[[ ${_LIST_SELECTED[${S}]} -eq 0 || ${_LIST_SELECTED[${S}]} -ge ${_GHOST_ROW} ]] && continue 
			_INVISIBLE_ROWS_MSG="(<w><I>there are marked rows on other pages<N>)|"
			break
		fi
	done
}

list_write_to_file () {
	local ALIST=(${@})
	local L

	[[ ${_DEBUG} -ge 3 ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	if [[ -n ${ALIST[1]} ]];then
		[[ -e ${_SCRIPT}.out ]] && rm -f ${_SCRIPT}.out
		msg_box -c -p "Writing ${#ALIST} list $(str_pluralize item) to file: ${_SCRIPT}.out|Press any key"
		for L in ${ALIST};do
			echo ${L} >> ${_SCRIPT}.out
		done
	else
		msg_box -c -p "List is empty - nothing to write|Press any key"
	fi
}

