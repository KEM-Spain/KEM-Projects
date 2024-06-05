# LIB Dependencies
_DEPS_+="ARRAY.zsh DBG.zsh STR.zsh TPUT.zsh UTILS.zsh"

# LIB Declarations
typeset -a _CONT_BUFFER=()
typeset -A _CONT_DATA=(BOX false COLS 0 HDRS 0 MAX 0 OUT 0 SCR 0 TOP 0 Y 0 W 0)

# LIB Vars
_MSG_KEY=''
_MSG_LIB_DBG=4
_PROC_MSG=false

msg_box () {
	local -a MSGS=()
	local -a MSG_HDRS=()
	local -a MSG_BODY=()
	local -a MSG_FOLD
	local -A CONT_COORDS

	local MAX_X_COORD=$((_MAX_ROWS-5)) # Not including frame 5 up from bottom, 4 with frame
	local MAX_Y_COORD=$((_MAX_COLS-10)) # Not including frame 10 from sides, 9 with frame
	local MIN_X_COORD=$(( (_MAX_ROWS-MAX_X_COORD)-1 )) # Vertical limit
	local MIN_Y_COORD=$((_MAX_COLS-MAX_Y_COORD)) # Horiz limit
	local USABLE_COLS=$((MAX_Y_COORD-MIN_Y_COORD)) # Horizontal space boundary
	local USABLE_ROWS=$((MAX_X_COORD-MIN_X_COORD)) # Vertical space boundary
	local MAX_LINE_WIDTH=$((USABLE_COLS-20))

	local NAV_BAR="<c>Navigation keys<N>: (<w>t<N>,<w>h<N>=top <w>b<N>,<w>l<N>=bottom <w>p<N>,<w>k<N>=up <w>n<N>,<w>j<N>=down, <w>Esc<N>=close)<N> Pages:<w>_MSG_PG<N>"
	local BOX_X_COORD=0
	local BOX_Y_COORD=0
	local DELIM='|'
	local DISPLAY_ROWS=0
	local DTL_NDX=0
	local GAP=0
	local GAP_NDX=0
	local KEY=''
	local MSG_COLS=0
	local MSG_COUNT=0
	local MSG_LEN=0
	local MSG_NDX=0
	local MSG_OUT=0
	local MSG_PAGES=0
	local MSG_PAGING=false
	local MSG_DTL=0
	local MSG_IS_LIST=false
	local MSG_STR=''
	local MSG_SEP=''
	local MSG_X_COORD=0
	local MSG_Y_COORD=0
	local OPTION=''
	local PARTIAL=0
	local PG_LINES=0
	local PROMPT_LINE=''
	local SCR_NDX=0
	local H K M T X 

	# OPTIONS
	local -a MSG=()
	local BOX_HEIGHT=0
	local FOLD_WIDTH=${MAX_LINE_WIDTH}
	local FRAME_COLOR=''
	local BOX_WIDTH=0
	local CLEAR_MSG=false
	local CONTINUOUS=false
	local DELIM_ARG=false
	local HDR_LINES=0
	local IGNORE_MARKUP=false
	local INLINE_LIST=false
	local MSG_DEBUG=false
	local MSG_X_COORD_ARG=-1
	local MSG_Y_COORD_ARG=-1
	local MSG_PROMPT=''
	local PROMPT_USER=false
	local QUIET=false
	local SAFE=true
	local SO=false
	local TEXT_STYLE=c # Default is center - Values:[(l)eft,(c)enter,(n)ormal] or style embeds:<L> list, <Z> blank, 
	local TIMEOUT=0

	local OPTSTR=":DH:P:O:CRcf:h:inpqruj:s:t:w:x:y:"
	OPTIND=0

	while getopts ${OPTSTR} OPTION;do
		case ${OPTION} in
			D) MSG_DEBUG=true;;
			H) HDR_LINES=${OPTARG};;
			C) CONTINUOUS=true;;
			O) FRAME_COLOR=${OPTARG};;
			P) MSG_PROMPT=${OPTARG};;
			R) _CONT_DATA[BOX]=false;;
			c) CLEAR_MSG=true;;
			f) FOLD_WIDTH=${OPTARG};;
			h) BOX_HEIGHT=${OPTARG};;
			i) IGNORE_MARKUP=true;;
			j) TEXT_STYLE=${OPTARG};;
			p) PROMPT_USER=true;;
			q) QUIET=true;;
			r) SO=true;;
			s) DELIM_ARG="${OPTARG}";;
			t) TIMEOUT="${OPTARG}";;
			u) SAFE=false;;
			w) BOX_WIDTH=${OPTARG};;
			x) MSG_X_COORD_ARG=${OPTARG};;
			y) MSG_Y_COORD_ARG=${OPTARG};;
			:) print -u2 " ${_SCRIPT}: ${0}: option: -${OPTARG} requires an argument" >&2;read ;;
			\?) print -u2 " ${_SCRIPT}: ${0}: unknown option -${OPTARG}" >&2; read;;
		esac
	done
	shift $((OPTIND -1))

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	# Hide cursor
	if [[ ${_CURSOR_STATE} == 'on' ]];then
		tput civis >&2
		_CURSOR_STATE=off
	fi

	[[ ${CLEAR_MSG} == 'true' ]] && msg_box_clear # Clear last msg?

	# Process MSG arguments
	MSG=(${@}) # MSG ARGS
	[[ -z ${MSG} ]] && return # If no MSG

	# Long messages display feedback while parsing
	MSG_LEN=${*}
	[[ ${#MSG_LEN} -gt 250 && ${QUIET} == 'false' ]] && _PROC_MSG=true
	
	# Append prompt to msgs
	if [[ -n ${MSG_PROMPT} ]];then
		case ${MSG_PROMPT} in
			B) MSG+="|<Z>|<w>Reboot? (y/n)<N>";;
			C) MSG+="|<Z>|<w>Continue? (y/n)<N>";;
			D) MSG+="|<Z>|<w>Delete? (y/n)<N>";;
			E) MSG+="|<Z>|<w>Edit? (y/n)<N>";;
			G) MSG+="|<Z>|<w>Download? (y/n)<N>";;
			I) MSG+="|<Z>|<w>Install? (y/n)<N>";;
			K) MSG+="|<Z>|<w>Press any key...<N>";;
			M) MSG+="|<Z>|<w>More? (y/n)<N>";;
			N) MSG+="|<Z>|<w>Next/Approve all? (y/n/a)<N>";;
			P) MSG+="|<Z>|<w>Proceed? (y/n)<N>";;
			Q) MSG+="|<Z>|<w>Queue? (y/n)<N>";;
			V) MSG+="|<Z>|<w>View? (y/n)<N>";;
			X) MSG+="|<Z>|<w>Kill? (y/n)<N>";;
			*) MSG+="|<Z>|<w>${MSG_PROMPT}<N>";;
		esac
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ADDED PROMPT:${MSG_PROMPT}"
	fi

	MSG=$(tr -d "\n" <<<${MSG}) # Convert to string - setup for cut
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG TO STRING:${MSG}"

	# Get message count
	[[ ${DELIM_ARG} != 'false' ]] && DELIM=${DELIM_ARG} # Assign delimiter
	MSG_COUNT=$(echo ${MSG} | grep --color=never -o "[${DELIM}]" | wc -l) # Slice MSG into fields and count
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG contains ${MSG_COUNT} lines"

	# Extract item by delim and fold any lines that exceed display
	DISPLAY_ROWS=0
	for (( X=1; X <= $((${MSG_COUNT}+1)); X++ ));do
		M=$(cut -d"${DELIM}" -f${X} <<<${MSG})
		K=$(tr -d '[:space:]' <<<${M})
		[[ -z ${K} ]] && continue
		if [[ ${#M} -gt ${MAX_LINE_WIDTH} ]];then
			MSG_FOLD=("${(f)$(fold -s -w${FOLD_WIDTH} <<<${M})}")
			for T in ${MSG_FOLD};do
				MSGS+=${T}
				((DISPLAY_ROWS++))
			done
		else
			MSGS+=${M}
			((DISPLAY_ROWS++))
		fi
	done
	[[ -n ${MSG_PROMPT} ]] && ((DISPLAY_ROWS++))

	[[ ${DISPLAY_ROWS} -gt ${USABLE_ROWS} ]] && DISPLAY_ROWS=${USABLE_ROWS} # Limit display lines
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: DISPLAY_ROWS:${DISPLAY_ROWS}"

	if [[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]];then
		dbg "${functrace[1]} called ${0}:${LINENO}: MAX ROWS:${WHITE_FG}${_MAX_ROWS}${RESET} MAX COLS:${WHITE_FG}${_MAX_COLS}${RESET}"
		dbg "${functrace[1]} called ${0}:${LINENO}: DISPLAY_ROWS:${WHITE_FG}${DISPLAY_ROWS}${RESET}"
		dbg "${functrace[1]} called ${0}:${LINENO}: USABLE_ROWS:${WHITE_FG}${USABLE_ROWS}${RESET} USABLE_COLS:${WHITE_FG}${USABLE_COLS}${RESET}"
		dbg "${functrace[1]} called ${0}:${LINENO}: MIN_XY_COORD:${WHITE_FG}(X:${MIN_X_COORD},Y:${MIN_Y_COORD})${RESET}"
		dbg "${functrace[1]} called ${0}:${LINENO}: MAX_XY_COORD:${WHITE_FG}(X:${MAX_X_COORD},Y:${MAX_Y_COORD})${RESET}"
		dbg "${functrace[1]} called ${0}:${LINENO}: MSG_LINES:${WHITE_FG}${#MSGS}${RESET}"
		dbg "${functrace[1]} called ${0}:${LINENO}: TEXT_STYLE:${WHITE_FG}${TEXT_STYLE}${RESET}"
	fi

	# Separate headers from body
	if [[ ${HDR_LINES} -ne 0 ]];then
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG HAS HEADERS"
		MSG_HDRS=(${MSGS[1,$((HDR_LINES))]})
		MSG_BODY=(${MSGS[HDR_LINES+1,-1]})
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG HEADER CONTAINS ${#MSG_HDRS} lines"
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG BODY CONTAINS ${#MSG_BODY} lines"
	else
		MSG_BODY=(${MSGS})
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG HAS ${RED_FG}NO${RESET} HEADERS"
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG BODY CONTAINS ${#MSG_BODY} lines"
	fi

	MSG_STR=$(arr_long_elem ${MSGS}) # Returns trimmed/no markup
	MSG_COLS=${#MSG_STR}
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: INITIAL MSG_COLS:${MSG_COLS}"

	[[ ${MSG_BODY} =~ '<L>' ]] && MSG_IS_LIST=true || MSG_IS_LIST=false # Check for list embeds
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG_IS_LIST:${MSG_IS_LIST}"

	# Handle paged messages
	if [[ ${#MSGS} -gt ${DISPLAY_ROWS} ]];then
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MESSAGE IS PAGED"
		# Expand paged MSG container to aoccomodate NAV,MSG_HDRS,SEP as needed
		if [[ $((${#MSGS} + 2 )) -gt $((DISPLAY_ROWS)) ]];then
			MSG_STR=$(msg_nomarkup ${NAV_BAR}) # Strip markup
			[[ ${MSG_COLS} -lt ${#MSG_STR} ]] && MSG_COLS=${#MSG_STR} # Accomodate NAV_BAR
			MSG_SEP=$(str_unicode_line $((MSG_COLS+4))) # Add separator

			((HDR_LINES+=2)) # Adding NAV and SEP
			PG_LINES=$(( DISPLAY_ROWS - HDR_LINES ))

			# Add page count to NAV_BAR
			MSG_PAGES=$(( ${#MSG_BODY}/PG_LINES ))
			PARTIAL=$((${#MSG_BODY} % PG_LINES))
			[[ ${PARTIAL} -ne 0 ]] && ((MSG_PAGES++))
			NAV_BAR=$(sed "s/_MSG_PG/${MSG_PAGES}/" <<< ${NAV_BAR})

			MSG_HDRS=(${NAV_BAR} ${MSG_HDRS} ${MSG_SEP})
		fi
	else
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MESSAGE IS ${RED_FG}NOT${RESET} PAGED"
		# Non-paged list messages
		if [[ ${MSG_IS_LIST} == 'true' ]];then
			[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MESSAGE CONTAINS A LIST"
			MSG_SEP=$(str_unicode_line $((MSG_COLS+4))) # Add separator
			MSG_HDRS=(${MSG_HDRS} ${MSG_SEP})
			((HDR_LINES++)) # Added separator
			PG_LINES=$(( DISPLAY_ROWS - HDR_LINES ))
		else
			[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MESSAGE DOES ${RED_FG}NOT${RESET} CONTAIN A LIST"
			# All other
			if [[ ${HDR_LINES} -ne 0 ]];then
				[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ADDING MESSAGE HEADER SEPARATOR"
				MSG_SEP=$(str_unicode_line $((MSG_COLS+4))) # Add separator
				MSG_HDRS=(${MSG_HDRS} ${MSG_SEP})
				PG_LINES=${#MSG_BODY}
			else
				[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: PLAIN MESSAGE - ${RED_FG}NO${RESET} HEADER - ${RED_FG}NO${RESET} LISTS"
				PG_LINES=${DISPLAY_ROWS}
				MSG_BODY=(${MSGS})
			fi
		fi
	fi
	((MSG_COLS+=2)) # Add gutter
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: FINAL MSG_COLS:${MSG_COLS}"

	# Center MSG unless coords were passed
	[[ ${MSG_X_COORD_ARG} -eq -1 ]] && MSG_X_COORD=$(( ( _MAX_ROWS-(DISPLAY_ROWS+2) )/2 )) || MSG_X_COORD=${MSG_X_COORD_ARG}
	[[ ${MSG_Y_COORD_ARG} -eq -1 ]] && MSG_Y_COORD=$(( (_MAX_COLS/2)-(MSG_COLS/2) )) || MSG_Y_COORD=${MSG_Y_COORD_ARG}

	if [[ ${SAFE} == 'true' ]];then
		# Sane coords - catch overruns
		[[ ${MSG_X_COORD} -lt ${MIN_X_COORD} ]] && MSG_X_COORD=${MIN_X_COORD}
		[[ ${MSG_X_COORD} -gt ${USABLE_ROWS} ]] && MSG_X_COORD=${USABLE_ROWS}
		[[ ${MSG_Y_COORD} -lt ${MIN_Y_COORD} ]] && MSG_Y_COORD=${MIN_Y_COORD}
		[[ ${MSG_Y_COORD} -gt ${USABLE_COLS} ]] && MSG_Y_COORD=${USABLE_COLS}
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: SANE COORD limits evaluated"
	fi

	# Set box coords
	BOX_X_COORD=$((MSG_X_COORD-1))
	BOX_Y_COORD=$((MSG_Y_COORD-1))
	[[ ${BOX_WIDTH} -eq 0 ]] && BOX_WIDTH=$((MSG_COLS+4)) # 1 char gutter per side
	[[ ${BOX_HEIGHT} -eq 0 ]] && BOX_HEIGHT=$((DISPLAY_ROWS+2))

	if [[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]];then
		dbg "${functrace[1]} called ${0}:${LINENO}:  BOX_XY_COORD:${WHITE_FG}(${BOX_X_COORD},${BOX_Y_COORD})${RESET}"
		dbg "${functrace[1]} called ${0}:${LINENO}:  BOX_HEIGHT:${WHITE_FG}${BOX_HEIGHT}${RESET}"
		dbg "${functrace[1]} called ${0}:${LINENO}:  BOX_WIDTH:${WHITE_FG}${BOX_WIDTH}${RESET}"
	fi

	# Save box coords
	box_coords_set MSG X ${BOX_X_COORD} Y ${BOX_Y_COORD} H ${BOX_HEIGHT} W ${BOX_WIDTH}
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  MSG_BOX_COORDS: $(box_coords_get MSG)"

	# Flash progress msg if set
	[[ ${_PROC_MSG} == 'true' ]] && msg_proc ${BOX_X_COORD} ${BOX_Y_COORD}

	# Prepare display
	[[ ${SO} == 'true' ]] && tput smso # Standout mode

	# Call once for CONTINUOUS
	if [[ ${CONTINUOUS} == 'true' ]];then
		if [[ ${_CONT_DATA[BOX]} == 'false' ]];then
			msg_unicode_box ${BOX_X_COORD} ${BOX_Y_COORD} ${BOX_WIDTH} ${BOX_HEIGHT} ${FRAME_COLOR}
			box_coords_set CONT X ${BOX_X_COORD} Y ${BOX_Y_COORD} H ${BOX_HEIGHT} W ${BOX_WIDTH}
			_CONT_DATA[W]=${BOX_WIDTH}
			_CONT_DATA[HDRS]=${HDR_LINES}
			_CONT_DATA[OUT]=0
			_CONT_BUFFER=()
			_CONT_DATA[BOX]=true
		fi
	else
		msg_unicode_box ${BOX_X_COORD} ${BOX_Y_COORD} ${BOX_WIDTH} ${BOX_HEIGHT} ${FRAME_COLOR}

		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSGS:${WHITE_FG}${#MSGS}${RESET} DISPLAY_ROWS:${WHITE_FG}${DISPLAY_ROWS}${RESET}"

		# Handle last page gap
		if [[ ${#MSG_BODY} -gt $((PG_LINES)) ]];then
			MSG_PAGING=true
			[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${CYAN_FG}MESSAGE PAGING TRIGGERED${RESET}"

			if [[ -n ${MSG_PROMPT} ]];then
				PROMPT_LINE=${MSG_BODY[-1]} # Save the prompt
				MSG_BODY[-1]=" " # Erase prompt
				[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: SAVED PROMPT_LINE:${PROMPT_LINE}"
			fi

			# Get the amount of padding necessary to break the page on even boundaries
			GAP=$(msg_calc_gap ${#MSG_BODY} ${PG_LINES})
			[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: LAST PAGE GAP:${WHITE_FG}${GAP}${RESET}"

			# Pad messages to break evenly across pages
			for ((GAP_NDX=1;GAP_NDX<=${GAP};GAP_NDX++));do
				MSG_BODY+=" "
			done
			[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: AFTER GAP PADDING: MSG_BODY LINES:${#MSG_BODY}"

			if [[ -n ${MSG_PROMPT} ]];then
				MSG_BODY[-1]=${PROMPT_LINE} # Move the prompt to the bottom
				[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MOVED PROMPT_LINE:${MSG_BODY[-1]}"
			fi
		else
			MSG_PAGING=false
		fi
	fi

	# Output MSG lines
	if [[ ${CONTINUOUS} == 'true' ]];then
		CONT_COORDS=($(box_coords_get CONT))
		_CONT_DATA[TOP]=${CONT_COORDS[X]} && ((_CONT_DATA[TOP]++))
		_CONT_DATA[Y]=${CONT_COORDS[Y]} && ((_CONT_DATA[Y]++))
		_CONT_DATA[MAX]=${CONT_COORDS[H]} && ((_CONT_DATA[MAX]-=2))
		_CONT_DATA[COLS]=${CONT_COORDS[W]} && ((_CONT_DATA[COLS]-=4))

		[[ ${_CONT_DATA[OUT]} -eq 0 ]] && _CONT_DATA[SCR]=${_CONT_DATA[TOP]}
		[[ ${_CONT_DATA[HDRS]} -gt 0 ]] && (( _CONT_DATA[TOP] += _CONT_DATA[HDRS] ))

		if [[ ${_CONT_DATA[OUT]} -ge ${_CONT_DATA[MAX]} ]];then
			shift _CONT_BUFFER
			_CONT_DATA[SCR]=${_CONT_DATA[TOP]}
			for M in ${_CONT_BUFFER};do
				tput cup ${_CONT_DATA[SCR]} ${_CONT_DATA[Y]} # Place cursor
				tput ech ${_CONT_DATA[COLS]} # Clear line
				echo -n "${M}" # Output buffer
				((_CONT_DATA[SCR]++))
				((_CONT_DATA[OUT]++))
			done
		fi

		MSG_OUT=$(msg_box_align ${_CONT_DATA[W]} ${TEXT_STYLE} ${MSGS[1]}) # Apply padding to both sides of msg
		MSG_OUT=$(msg_markup ${MSG_OUT}) # Apply markup

		tput cup ${_CONT_DATA[SCR]} ${_CONT_DATA[Y]} # Place cursor
		tput ech ${_CONT_DATA[COLS]} # Clear line
		echo -n "${MSG_OUT}" # Output line

		[[ ${_CONT_DATA[OUT]} -ge ${_CONT_DATA[HDRS]} ]] && _CONT_BUFFER+=${MSG_OUT}
		((_CONT_DATA[SCR]++))
		((_CONT_DATA[OUT]++))
	else
		# Headers
		if [[ ${#MSG_HDRS} -ne 0 ]];then
			[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${CYAN_FG}GENERATING HEADERS${RESET}"
			SCR_NDX=${BOX_X_COORD} 
			DTL_NDX=0
			for H in ${MSG_HDRS};do
				((SCR_NDX++))
				((DTL_NDX++))
				MSG_OUT=$(msg_box_align ${BOX_WIDTH} ${TEXT_STYLE} ${H}) # Apply justification
				MSG_OUT=$(msg_markup ${H}) # Apply markup
				tput cup ${SCR_NDX} ${MSG_Y_COORD} # Place cursor
				tput ech ${MSG_COLS} # Clear line
				echo -n "${MSG_OUT}"
			done
		fi

		# Body
		SCR_NDX=$(( BOX_X_COORD + ${#MSG_HDRS} )) # Move past headers
		DTL_NDX=0

		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${CYAN_FG}GENERATING BODY${RESET}"
		for ((MSG_NDX=1;MSG_NDX<=${#MSG_BODY};MSG_NDX++));do
			((SCR_NDX++))
			((DTL_NDX++))

			MSG_OUT=$(msg_box_align ${BOX_WIDTH} ${TEXT_STYLE} ${MSG_BODY[${MSG_NDX}]}) # Apply padding to both sides of msg
			MSG_OUT=$(msg_markup ${MSG_OUT}) # Apply markup
			tput cup ${SCR_NDX} ${MSG_Y_COORD} # Place cursor
			tput ech ${MSG_COLS} # Clear line
			echo -n "${MSG_OUT}"

			[[ ${SO} == 'true' ]] && tput smso # Invoke standout

			if [[ ${MSG_PAGING} == 'true' ]];then # Pause/pass key to msg_paging or exit
				[[ ${XDG_SESSION_TYPE:l} == 'x11' ]] && eval "xset ${_XSET_LOW_RATE}"
				if [[ $((DTL_NDX % PG_LINES)) -eq 0 ]];then # Page break
					_MSG_KEY=$(get_keys)
					case ${_MSG_KEY} in
						27) break;; # Esc - Exit
						q) exit_request;((MSG_NDX-=PG_LINES));; # No advance if declined
					esac
					MSG_NDX=$(msg_paging ${_MSG_KEY} ${MSG_NDX} ${#MSG_BODY} ${PG_LINES})
					DTL_NDX=0
					SCR_NDX=$(( BOX_X_COORD + ${#MSG_HDRS} ))
				fi
			fi
		done
		if [[ ${MSG_PAGING} == 'false' && ${PROMPT_USER} == "true" ]];then
			_MSG_KEY=$(get_keys)
		fi
	fi

	[[ ${TIMEOUT} -gt 0 ]] && sleep ${TIMEOUT} && msg_box_clear # Display MSG for limited time
	[[ ${SO} == 'true' ]] && tput rmso # Kill standout

	# Restore display
	tput rc # Restore cursor position
	tput cup ${_MAX_ROWS} ${_MAX_COLS}
}

msg_box_align () {
	local BOX_WIDTH=${1}
	local STYLE=${2}; shift 2
	local MSG=${@}
	local MSG_OUT
	local MSG_PAD_L
	local MSG_PAD_R
	local OFFSET=3

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}"

	# Justification: List,Left,Center,Normal
	if [[ ${MSG} =~ '<Z>' ]];then # Blank Line?
		MSG_OUT=" "
	elif [[ ${MSG} =~ '<L>' ]];then # List?
		MSG_OUT=$(sed 's/<L>//g' <<<${MSG})
		MSG_OUT=$(msg_nomarkup ${MSG_OUT})
		MSG_OUT=$(str_trim ${MSG_OUT})
		MSG_OUT=$(sed 's/^/\\u2022 /g' <<<${MSG_OUT})
		MSG_PAD_L=' '
		MSG_PAD_R=$(str_rep_char ' ' $(( BOX_WIDTH-(${#MSG_PAD_L}+${#MSG_OUT})-${OFFSET} )) )
	elif [[ ${STYLE} == 'l' ]];then # Left
		MSG_OUT=$(msg_nomarkup ${MSG_OUT})
		MSG_OUT=$(str_trim ${MSG})
		MSG_PAD_L=' '
		MSG_PAD_R=$(str_rep_char ' ' $(( BOX_WIDTH-(${#MSG_PAD_L}+${#MSG_OUT})-${OFFSET} )) )
	elif [[ ${STYLE} == 'c' ]];then # Center
		MSG_OUT=$(msg_nomarkup ${MSG_OUT})
		MSG_OUT=$(str_trim ${MSG})
		MSG_PAD_L=$(str_center_pad $((BOX_WIDTH-2)) $(msg_nomarkup ${MSG_OUT}))
		MSG_PAD_R=$(str_rep_char ' ' $(( ${#MSG_PAD_L}-1 )) )
	elif [[ ${STYLE} == 'n' ]];then # Normal
		MSG_OUT=${MSG}
		MSG_OUT=$(msg_nomarkup ${MSG_OUT})
		MSG_PAD_L=' '
		MSG_PAD_R=$(str_rep_char ' ' $(( BOX_WIDTH-(${#MSG_PAD_L}+${#MSG_OUT})-${OFFSET} )) )
	fi

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:${MSG_PAD_L}${MSG_OUT}${MSG_PAD_R}"

	echo "${MSG_PAD_L}${MSG_OUT}${MSG_PAD_R}"
}

msg_box_clear () {
	local -A MBOX_COORDS=($(box_coords_get MSG))
	local X_COORD_ARG=${1}
	local Y_COORD_ARG=${2}
	local H_COORD_ARG=${3}
	local W_COORD_ARG=${4}
	local X

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  MBOX_COORDS:${(kv)MBOX_COORDS}"
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  X_COORD_ARG:${X_COORD_ARG}  Y_COORD_ARG:${Y_COORD_ARG} H_COORD_ARG:${H_COORD_ARG} W_COORD_ARG:${W_COORD_ARG}"

	[[ -z ${MBOX_COORDS} ]] && return # No previously displayed window found

	#  Substitute value from arg or use history value if nothing passed
	[[ -z ${X_COORD_ARG} || ${X_COORD_ARG} == 'X' ]] && X_COORD_ARG=${MBOX_COORDS[X]}
	[[ -z ${Y_COORD_ARG} || ${Y_COORD_ARG} == 'Y' ]] && Y_COORD_ARG=${MBOX_COORDS[Y]}
	[[ -z ${H_COORD_ARG} || ${H_COORD_ARG} == 'H' ]] && H_COORD_ARG=${MBOX_COORDS[H]}
	[[ -z ${W_COORD_ARG} || ${W_COORD_ARG} == 'W' ]] && W_COORD_ARG=${MBOX_COORDS[W]}

	for ((X=X_COORD_ARG; X<=X_COORD_ARG+H_COORD_ARG-1; X++));do
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  X:${X}, X_COORD_ARG:${X_COORD_ARG}, W_COORD_ARG:${W_COORD_ARG}"
		tput cup ${X} ${Y_COORD_ARG}
		tput ech ${W_COORD_ARG}
	done
}

msg_calc_gap () {
	local MSG_ROWS=${1}
	local DISP_ROWS=${2}
	local DTL_LINES=0
	local TL_PAGES=0
	local PARTIAL
	local GAP=0
	local NEED

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  ARGS: MSG_ROWS:${MSG_ROWS},DISP_ROWS:${DISP_ROWS}"

	TL_PAGES=$(( MSG_ROWS / DISP_ROWS ))
	PARTIAL=$(( MSG_ROWS % DISP_ROWS ))

	[[ ${PARTIAL} -ne 0 ]] && ((TL_PAGES++))
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: TL_PAGES:${TL_PAGES}, PARTIAL:${PARTIAL}"

	GAP=$(( (TL_PAGES * DISP_ROWS) - MSG_ROWS ))
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: GAP:${GAP}"

	echo ${GAP}
}

msg_err () {
	local MSG=${@}

	if [[ -n ${MSG} ]];then
		[[ ${MSG} =~ ":" ]] && MSG=$(perl -p -e 's/:(\S+)\s/\e[m:\e[3;37m$1\e[m /g' <<<${MSG})
		echo "\\\n[${_SCRIPT}]:[${BOLD}${RED_FG}Error${RESET}]  ${MSG}\\\n"
	fi
}

msg_list () {
	local -a MSG=(${@})
	local L
	local DELIM='|'
	local NDX=0

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG COUNT:${#MSG}"

	for L in ${MSG};do
		((NDX++))
		echo -n "<L>${L}"
		[[ ${NDX} -lt ${#MSG} ]] && echo ${DELIM}
	done

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: Generated ${NDX} lines"
}

msg_markup () {
	local MSG=${@}

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	# Apply markup and print
	perl -pe 'BEGIN { 
	%ES=(
	"B"=>"[1m",
	"I"=>"[3m",
	"N"=>"[m",
	"O"=>"[9m",
	"R"=>"[7m",
	"S"=>"[9m",
	"U"=>"[4m",
	"b"=>"[34m",
	"c"=>"[36m",
	"g"=>"[32m",
	"h"=>"[0m\e[0;1;37;100m",
	"m"=>"[35m",
	"r"=>"[31m",
	"u"=>"[4m",
	"w"=>"[37m",
	"y"=>"[33m"
	) }; 
	{ s/<([BINORSUrughybmcw])>/\e$ES{$1}/g; }' <<<${MSG}
}

msg_nomarkup () {
	local MSG=${@}
	local MSG_OUT

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}"

	MSG_OUT=$(perl -pe 's/(<B>|<I>|<L>|<N>|<O>|<R>|<U>|<b>|<c>|<g>|<m>|<r>|<w>|<y>)//g' <<<${MSG})

	echo ${MSG_OUT}
}

msg_paging () {
	local KEY=${1}
	local NDX=${2}
	local LIST_ROWS=${3}
	local PG_LINES=${4}
	local PARTIAL=0
	local TL_PAGES=0
	local TOP=0
	local BOT=0
	local PGUP=0
	local PGDN=0

	TL_PAGES=$(( LIST_ROWS / PG_LINES ))
	PARTIAL=$(( LIST_ROWS % PG_LINES ))
	[[ ${PARTIAL} -ne 0 ]] && ((TL_PAGES++))
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  TL_PAGES:${TL_PAGES}, PARTIAL:${PARTIAL}"

	TOP=0
	BOT=$(( (TL_PAGES-1) * PG_LINES ))
	PGUP=$(( NDX - (PG_LINES*2) )); [[ ${PGUP} -lt 1 ]] && PGUP=0
	PGDN=${NDX}

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:   TOP RETURNS:${TOP}"
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:   BOT RETURNS:${BOT}"
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  PGUP RETURNS:${PGUP}"
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  PGDN RETURNS:${PGDN}"

	case ${KEY} in
		t|h) echo ${TOP};;
		b|l) echo ${BOT};;
		u|k|p) echo ${PGUP};;
		d|j|n) echo ${PGDN};;
	esac
}

msg_proc () {
	local BOX_X=${1}
	local BOX_Y=${2}
	local BOX_W=20
	local BOX_H=3

	msg_unicode_box ${BOX_X} ${BOX_Y} ${BOX_W} ${BOX_H}
	tput cup $((BOX_X+1)) $((BOX_Y+2));echo -n "${GREEN_FG}Processing...${RESET}"
	box_coords_set PROC X ${BOX_X} Y ${BOX_Y} W ${BOX_W} H ${BOX_H}
	_PROC_MSG=false
	sleep .5
}

msg_stream () {
	local -a CMD
	local -a MSG_LINES
	local DELIM='|'
	local STYLE=l
	local FOLD_WIDTH=120
	local FOLD
	local MSG
	local LINE_CNT
	local PAD
	local NDX

	local OPTION
	local OPTSTR=":f:lcn"
	OPTIND=0

	while getopts ${OPTSTR} OPTION;do
		case ${OPTION} in
			f) FOLD_WIDTH=${OPTARG};;
			l) STYLE=l;;
			c) STYLE=c;;
			n) STYLE=n;;
			:) print -u2 " ${_SCRIPT}: ${0}: option: -${OPTARG} requires an argument" >&2;read ;;
			\?) print -u2 " ${_SCRIPT}: ${0}: unknown option -${OPTARG}" >&2; read;;
		esac
	done
	shift $((OPTIND -1))

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	FOLD="| fold -s -w ${FOLD_WIDTH}"

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: OPTIONS:FOLD:${FOLD} STYLE:${STYLE}"

	CMD=(${@})
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: CMD:${CMD}"

	# Convert carriage returns to newlines and any '<' to similar unicode to avoid collision with markup
	coproc { eval "${CMD} ${FOLD}" | sed -e "s//\n/g" -e 's/</\xe2\x98\x87/g'; } 

	LINE_CNT=0
	while read -p ${COPROC[0]} MSG;do
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: COPROC READ MSG:${LINE_CNT}: [${MSG}] $(xxd <<<${MSG})"
		MSG_LINES+="<w>${MSG}<N>${DELIM}"
		((LINE_CNT++))
	done
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: TOTAL MSGS FROM COPROC:${LINE_CNT}"

	while true;do
		[[ ${MSG_LINES[-1]} == "<w><N>|" ]] && MSG_LINES[-1]=() || break
	done

	MSG_LINES[-1]=$(sed 's/|//g' <<< ${MSG_LINES[-1]}) # Remove DELIM on prompt

	[[ -z ${#MSG_LINES[1]} || ${MSG_LINES[1]:l} =~ 'unable to locate' ]] && return
	
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG COUNT with BLANK LINES REMOVED:${#MSG_LINES}"

	msg_box -P"<m>Last Page<N>" -pc -s${DELIM} -j${STYLE} ${MSG_LINES} # Display window
}

msg_unicode_box () {
	local BOX_X_COORD=${1}
	local BOX_Y_COORD=${2}
	local BOX_WIDTH=${3}
	local BOX_HEIGHT=${4}
	local BOX_COLOR=${5:=${RESET}}
	local TOP_LEFT 
	local TOP_RIGHT
	local BOT_LEFT 
	local BOT_RIGHT
	local HORIZ_BAR 
	local VERT_BAR
	local HEAVY
	local L_SPAN=$(( BOX_Y_COORD+1 ))
	local R_SPAN=$(( BOX_Y_COORD+BOX_WIDTH-2 ))
	local T_SPAN=$(( BOX_X_COORD+1 ))
	local B_SPAN=$(( BOX_X_COORD+BOX_HEIGHT-2 ))
	local X Y

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	HEAVY=false
	[[ ${1} == '-h' ]] && HEAVY=true && shift

	if [[ ${HEAVY} == 'false' ]];then
		BOT_LEFT="\\u2514%.0s"
		BOT_RIGHT="\\u2518%.0s"
		HORIZ_BAR="\\u2500%.0s"
		TOP_LEFT="\\u250C%.0s"
		TOP_RIGHT="\\u2510%.0s"
		VERT_BAR="\\u2502%.0s"
	else
		BOT_LEFT="\\u2517%.0s"
		BOT_RIGHT="\\u251B%.0s"
		HORIZ_BAR="\\u2501%.0s"
		TOP_LEFT="\\u250F%.0s"
		TOP_RIGHT="\\u2513%.0s"
		VERT_BAR="\\u2503%.0s"
	fi

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: TOP LEFT: BOX_X_COORD:${BOX_X_COORD} BOX_Y_COORD:${BOX_Y_COORD}"

	# Color
	echo -n ${BOX_COLOR}

	# Top left corner
	tput cup ${BOX_X_COORD} ${BOX_Y_COORD}
	printf ${TOP_LEFT}

	# Top border
	for (( Y=${L_SPAN}; Y<=${R_SPAN}; Y++ ));do
		tput cup ${BOX_X_COORD} ${Y}
		printf ${HORIZ_BAR}
	done

	# Top right corner
	printf ${TOP_RIGHT}

	# Sides
	for (( X=${T_SPAN}; X<=${B_SPAN}; X++ ));do
		tput cup ${X} ${BOX_Y_COORD}
		printf ${VERT_BAR}
		tput ech ${BOX_WIDTH} # Clear box area
		tput cup ${X} $(( R_SPAN + 1 ))
		printf ${VERT_BAR}
	done

	# Bottom left corner
	tput cup ${X} ${BOX_Y_COORD}
	printf ${BOT_LEFT}

	# Bottom border
	for (( Y=${L_SPAN}; Y<=${R_SPAN}; Y++ ));do
		tput cup ${X} ${Y}
		printf ${HORIZ_BAR}
	done

	# Bottom right corner
	tput cup ${X} ${Y}
	printf ${BOT_RIGHT}

	echo -n ${RESET}

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: BOTTOM RIGHT: BOX_X_COORD:${X} BOX_Y_COORD:${Y}"
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: BOX DIMENSIONS:$((X-BOX_X_COORD+1)) x $((Y-BOX_Y_COORD+1))"
}

msg_info () {
	local MSG=${@}

	if [[ -n ${MSG} ]];then
		[[ ${MSG} =~ ":" ]] && MSG=$(perl -p -e 's/:(\w+)/\e[m:\e[3;37m$1\e[m/g' <<<${MSG})
		echo "\\\n[${_SCRIPT}]:${BOLD}${CYAN_FG}${MSG}${RESET}\\\n"
	fi
}

msg_warn () {
	local MSG=${@}

	if [[ -n ${MSG} ]];then
		[[ ${MSG} =~ ":" ]] && MSG=$(perl -p -e 's/:(\w+)/\e[m:\e[3;37m$1\e[m/g' <<<${MSG})
		echo "\\\n[${_SCRIPT}]:${BOLD}${RED_FG}${MSG}${RESET}\\\n"
	fi
}

