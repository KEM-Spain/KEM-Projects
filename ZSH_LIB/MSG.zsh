# LIB Dependencies
_DEPS_+="ARRAY.zsh DBG.zsh STR.zsh TPUT.zsh UTILS.zsh"

# LIB Declarations
typeset -a _CONT_BUFFER=()
typeset -A _CONT_DATA=(BOX false COLS 0 HDRS 0 MAX 0 OUT 0 SCR 0 TOP 0 Y 0 W 0)
typeset -A _BOX_COORDS
typeset -a _BOX_TEXT

# LIB Vars
_MSG_KEY=''
_MSG_LIB_DBG=4
_PROC_MSG=false

msg_box () {
	local -a MSGS=()
	local -a MSG_HDRS=()
	local -a MSG_BODY=()
	local -a MSG_FOLD=()
	local -A CONT_COORDS=()

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
	local DELIM_COUNT=0
	local DTL_NDX=0
	local GAP=0
	local GAP_NDX=0
	local KEY=''
	local MSG_COLS=0
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
	local SEP_LEN=0
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
	local TAG=MSG
	local TEXT_STYLE=c # Default is center - Values:[(l)eft,(c)enter,(n)ormal] or style embeds:<L> list, <Z> blank, 
	local TIMEOUT=0

	local OPTSTR=":DH:P:O:CRT:cf:h:inpqruj:s:t:w:x:y:"
	OPTIND=0

	while getopts ${OPTSTR} OPTION;do
		case ${OPTION} in
			D) MSG_DEBUG=true;;
			H) HDR_LINES=${OPTARG};;
			C) CONTINUOUS=true;;
			O) FRAME_COLOR=${OPTARG};;
			P) MSG_PROMPT=${OPTARG};;
			R) _CONT_DATA[BOX]=false;;
			T) TAG=${OPTARG};;
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
			N) MSG+="|<Z>|<w>(y)es,(s)kip,(a)ll?";;
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
	[[ ${#DELIM} -gt 1 ]] && exit_leave $(msg_err "${functrace[1]} called ${0}:${LINENO}: Invalid delimiter:${DELIM}")

	MSG=$(sed -E "s/[\\\][${DELIM}]/_DELIM_/g" <<<${MSG}) # handle (skip) escaped delimiters
	DELIM_COUNT=$(grep --color=never -o "[${DELIM}]" <<<${MSG} | wc -l) # Slice MSG into fields and count
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG contains ${WHITE_FG}${DELIM_COUNT}${RESET} delimiters"

	# Extract item by delim and fold any lines that exceed display
	for (( X=1; X <= $((${DELIM_COUNT}+1)); X++ ));do
		M=$(cut -d"${DELIM}" -f${X} <<<${MSG})
	 	M=$(sed "s/_DELIM_/${DELIM}/g" <<<${M}) # Restore escaped delimiters
		K=$(tr -d '[:space:]' <<<${M})
		[[ -z ${K} ]] && continue
		if [[ ${#M} -gt ${MAX_LINE_WIDTH} ]];then
			MSG_FOLD=("${(f)$(fold -s -w${FOLD_WIDTH} <<<${M})}")
			for T in ${MSG_FOLD};do
				MSGS+=$(str_trim ${T})
			done
		else
			MSGS+=${M}
		fi
	done
	
	# Separate headers from body
	if [[ ${HDR_LINES} -ne 0 ]];then
		MSG_HDRS=(${MSGS[1,$((HDR_LINES))]})
		MSG_BODY=(${MSGS[HDR_LINES+1,-1]})
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG HAS HEADERS"
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG HEADER CONTAINS ${#MSG_HDRS} lines"
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG BODY CONTAINS ${#MSG_BODY} lines"
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG_HDRS:\n---\n$(for M in ${MSG_HDRS};do echo ${M};done)\n---\n"
	else
		MSG_BODY=(${MSGS})
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG HAS ${RED_FG}NO${RESET} HEADERS"
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG BODY CONTAINS ${#MSG_BODY} lines"
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG_BODY:\n---\n$(for M in ${MSG_BODY};do echo ${M};done)\n---\n"
	fi


	if [[ ${#MSGS} -gt ${USABLE_ROWS} ]];then
		MSG_PAGING=true
		PG_LINES=$(( USABLE_ROWS - ${#MSG_HDRS} ))
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${CYAN_FG}MESSAGE PAGING TRIGGERED${RESET}"
	else
		PG_LINES=${#MSG_BODY}
	fi

	if [[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]];then
		dbg "${functrace[1]} called ${0}:${LINENO}:  --- DISPLAY LIMITS ---"
		dbg "${functrace[1]} called ${0}:${LINENO}: MAX ROWS:${WHITE_FG}${_MAX_ROWS}${RESET} MAX COLS:${WHITE_FG}${_MAX_COLS}${RESET}"
		dbg "${functrace[1]} called ${0}:${LINENO}: USABLE_ROWS:${WHITE_FG}${USABLE_ROWS}${RESET} USABLE_COLS:${WHITE_FG}${USABLE_COLS}${RESET}"
		dbg "${functrace[1]} called ${0}:${LINENO}: MIN_XY_COORD:${WHITE_FG}(X:${MIN_X_COORD},Y:${MIN_Y_COORD})${RESET}"
		dbg "${functrace[1]} called ${0}:${LINENO}: MAX_XY_COORD:${WHITE_FG}(X:${MAX_X_COORD},Y:${MAX_Y_COORD})${RESET}"
	fi

	MSG_STR=$(arr_long_elem ${MSGS}) # Returns trimmed/no markup
	MSG_COLS=$(( ${#MSG_STR} +1 ))
	MSG_SEP="<SEP>"

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG_STR:${MSG_STR} = INITIAL MSG_COLS:${MSG_COLS}"

	# Process various message types
	if [[ ${MSG_PAGING}  == 'true' ]];then
		MSG_STR=$(msg_nomarkup ${NAV_BAR}) # Strip markup

		# Adding header lines reduces paging area (PG_LINES)
		[[ -n ${MSG_HDRS} ]] && ((PG_LINES-=2)) || ((PG_LINES--)) # With headers add BAR,HDR,SEP else add BAR,SEP only

		# Replace page count token in NAV_BAR
		MSG_PAGES=$(( ${#MSG_BODY} / PG_LINES ))
		PARTIAL=$((${#MSG_BODY} % PG_LINES))
		[[ ${PARTIAL} -ne 0 ]] && ((MSG_PAGES++))
		NAV_BAR=$(sed "s/_MSG_PG/${MSG_PAGES}/" <<< ${NAV_BAR})

		if [[ -n ${MSG_HDRS} ]];then # Has headers
			MSG_HDRS=(${MSG_HDRS} ${NAV_BAR} ${MSG_SEP}) # Add BAR,HDR,SEP
			[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: FORMAT PAGING HEADER w/BAR,HDR,SEP"
		else # No headers
			MSG_HDRS=(${NAV_BAR} ${MSG_SEP}) # Add BAR,SEP
			[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: FORMAT PAGING HEADER w/BAR,SEP"
		fi
		MSG_COLS=$(( ${#MSG_STR} +1 )) # Clean NAV_BAR
	elif [[ -n ${MSG_HDRS} ]];then # Non-paged w/headers
		MSG_HDRS=(${MSG_HDRS} ${MSG_SEP}) # Add separator
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: FORMAT NORMAL HEADER W/ HDRS and SEP"
	fi

	((MSG_COLS+=2)) # Add gutter
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: FINAL MSG_COLS:${MSG_COLS}"

	if [[ ${SAFE} == 'true' ]];then
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: CATCHING ANY DISPLAY OVERRUNS"
		[[ ${MSG_X_COORD} -lt ${MIN_X_COORD} ]] && MSG_X_COORD=${MIN_X_COORD}
		[[ ${MSG_X_COORD} -gt ${USABLE_ROWS} ]] && MSG_X_COORD=${USABLE_ROWS}
		[[ ${MSG_Y_COORD} -lt ${MIN_Y_COORD} ]] && MSG_Y_COORD=${MIN_Y_COORD}
		[[ ${MSG_Y_COORD} -gt ${USABLE_COLS} ]] && MSG_Y_COORD=${USABLE_COLS}
	fi

	# Set box coords
	[[ ${BOX_WIDTH} -eq 0 ]] && BOX_WIDTH=$((MSG_COLS+4)) # 1 char gutter per side
	[[ ${BOX_HEIGHT} -eq 0 ]] && BOX_HEIGHT=$(( PG_LINES + ${#MSG_HDRS} + 2 ))

	# Set separator
	if [[ -n ${MSG_HDRS} ]];then
		SEP_LEN=$(str_unicode_line $((BOX_WIDTH-4)))
		MSG_HDRS[-1]=$(sed "s/<SEP>/${SEP_LEN}/" <<<${MSG_HDRS[-1]})
	fi

	# Center MSG unless coords were passed
	[[ ${MSG_X_COORD_ARG} -eq -1 ]] && MSG_X_COORD=$(( ((_MAX_ROWS-BOX_HEIGHT) / 2) + 1)) || MSG_X_COORD=${MSG_X_COORD_ARG}
	[[ ${MSG_Y_COORD_ARG} -eq -1 ]] && MSG_Y_COORD=$(( (_MAX_COLS/2)-(MSG_COLS/2) )) || MSG_Y_COORD=${MSG_Y_COORD_ARG}

	# Set box coords - compensate for frame
	BOX_X_COORD=$((MSG_X_COORD-1))
	BOX_Y_COORD=$((MSG_Y_COORD-1))

	# Flash progress msg if requested
	[[ ${_PROC_MSG} == 'true' ]] && msg_proc ${BOX_X_COORD} ${BOX_Y_COORD}

	if [[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]];then
		dbg "${functrace[1]} called ${0}:${LINENO}:  --- BOX COORDS ---"
		dbg "${functrace[1]} called ${0}:${LINENO}:  BOX_XY_COORD:${WHITE_FG}(${BOX_X_COORD},${BOX_Y_COORD})${RESET}"
		dbg "${functrace[1]} called ${0}:${LINENO}:  BOX_HEIGHT:${WHITE_FG}${BOX_HEIGHT}${RESET}"
		dbg "${functrace[1]} called ${0}:${LINENO}:  BOX_WIDTH:${WHITE_FG}${BOX_WIDTH}${RESET}"
	fi

#echo  "BOX COORDS ---"
#echo  "(final) PG_LINES:${WHITE_FG}${PG_LINES}${RESET}"
#echo  "(final) MSG_HDRS:${WHITE_FG}${#MSG_HDRS}${RESET}"
#echo  "(final) BOX_HEIGHT:${WHITE_FG}${BOX_HEIGHT}${RESET} PG_LINES + ${#MSG_HDRS} + 2"
#echo  "(final) BOX_XY_COORD:${WHITE_FG}(${BOX_X_COORD},${BOX_Y_COORD})${RESET}"
#echo  "(final) BOX_WIDTH:${WHITE_FG}${BOX_WIDTH}${RESET}"
#echo  "(final) MSG_BODY:${WHITE_FG}${#MSG_BODY}${RESET}"
#echo -n "Waiting...";read

	# Save box coords
	box_coords_set ${TAG} X ${BOX_X_COORD} Y ${BOX_Y_COORD} H ${BOX_HEIGHT} W ${BOX_WIDTH} S ${TEXT_STYLE}
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:  SAVED MSG_BOX_COORDS: $(box_coords_get ${TAG})"

	# Prepare display
	[[ ${SO} == 'true' ]] && tput smso # Standout mode

	# Call once for CONTINUOUS messages
	if [[ ${CONTINUOUS} == 'true' ]];then
		if [[ ${_CONT_DATA[BOX]} == 'false' ]];then
			msg_unicode_box ${BOX_X_COORD} ${BOX_Y_COORD} ${BOX_WIDTH} ${BOX_HEIGHT} ${FRAME_COLOR}
			box_coords_set CONT X ${BOX_X_COORD} Y ${BOX_Y_COORD} H ${BOX_HEIGHT} W ${BOX_WIDTH} S ${TEXT_STYLE}
			_CONT_DATA[W]=${BOX_WIDTH}
			_CONT_DATA[HDRS]=${HDR_LINES}
			_CONT_DATA[OUT]=0
			_CONT_BUFFER=()
			_CONT_DATA[BOX]=true
		fi
	else
		msg_unicode_box ${BOX_X_COORD} ${BOX_Y_COORD} ${BOX_WIDTH} ${BOX_HEIGHT} ${FRAME_COLOR}

		# Handle last page gap
		if [[ ${MSG_PAGING} == 'true' ]];then
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
		
		box_coords_upd CONT S ${TEXT_STYLE}
		MSG_OUT=$(msg_box_align CONT ${MSGS[1]}) # Apply padding to both sides of msg

		tput cup ${_CONT_DATA[SCR]} ${_CONT_DATA[Y]} # Place cursor
		tput ech ${_CONT_DATA[COLS]} # Clear line
		echo -n "${MSG_OUT}" # Output line

		[[ ${_CONT_DATA[OUT]} -ge ${_CONT_DATA[HDRS]} ]] && _CONT_BUFFER+=${MSG_OUT}
		((_CONT_DATA[SCR]++))
		((_CONT_DATA[OUT]++))
	else
		# Headers
		if [[ -n ${MSG_HDRS} ]];then
			[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${CYAN_FG}GENERATING HEADERS${RESET}"
			SCR_NDX=${BOX_X_COORD} 
			DTL_NDX=0
			for H in ${MSG_HDRS};do
				((SCR_NDX++))
				((DTL_NDX++))
				MSG_OUT=$(msg_box_align ${TAG} ${H}) # Apply justification
				tput cup ${SCR_NDX} ${MSG_Y_COORD} # Place cursor
				tput ech ${MSG_COLS} # Clear line
				echo -n "${MSG_OUT}"
				_BOX_TEXT+="${TAG}|${SCR_NDX}|${MSG_Y_COORD}|${MSG_OUT}|"
				[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG_OUT:${MSG_OUT}"
			done
		fi

		SCR_NDX=$(( BOX_X_COORD + ${#MSG_HDRS} )) # Move past headers
		DTL_NDX=0

		# Body
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ${CYAN_FG}GENERATING BODY${RESET}"
		for ((MSG_NDX=1;MSG_NDX<=${#MSG_BODY};MSG_NDX++));do
			((SCR_NDX++))
			((DTL_NDX++))
			MSG_OUT=$(msg_box_align ${TAG} ${MSG_BODY[${MSG_NDX}]}) # Apply padding to both sides of msg
			tput cup ${SCR_NDX} ${MSG_Y_COORD} # Place cursor
			tput ech ${MSG_COLS} # Clear line
			echo -n "${MSG_OUT}"
			_BOX_TEXT+="${TAG}|${SCR_NDX}|${MSG_Y_COORD}|${MSG_OUT}|"
			[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: MSG_OUT:${MSG_OUT}"

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
		if [[ ${PROMPT_USER} == "true" ]];then
			_MSG_KEY=$(get_keys)
		fi
	fi

	[[ ${TIMEOUT} -gt 0 ]] && sleep ${TIMEOUT} && msg_box_clear # Display MSG for limited time
	[[ ${SO} == 'true' ]] && tput rmso # Kill standout

	# Restore display
	tput rc # Restore cursor position
	tput cup ${_MAX_ROWS} ${_MAX_COLS} # Drop cursor to bottom right corner
}

msg_box_align () {
	local TAG=${1};shift
	local MSG=${@}
	local -A BOX_COORDS=($(box_coords_get ${TAG}))
	local BOX_WIDTH=${BOX_COORDS[W]}
	local BOX_STYLE=${BOX_COORDS[S]}
	local TEXT_PAD_L=''
	local TEXT_PAD_R=''
	local MSG_OUT=''
	local OFFSET=3
	local TEXT=''

	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}"

	# Justification: List,Left,Center
	if [[ ${MSG} =~ '<Z>' ]];then # Blank Line?
		MSG=" "
		[[ ${_DEBUG} -ge ${_TEXT_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO} Added blank line"

	elif [[ ${MSG} =~ '<L>' ]];then # List?
		MSG=$(sed -e 's/<L>/\\u2022 /' <<<${MSG}) # Add bullet and space
		TEXT=${MSG}
		TEXT=$(msg_nomarkup ${TEXT})
		TEXT=$(str_trim ${TEXT})
		TEXT_PAD_L=' '
		TEXT_PAD_R=$(str_rep_char ' ' $(( BOX_WIDTH - (${#TEXT_PAD_L}+${#TEXT}) - OFFSET -1 )) ) # compensate for bullet/space
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO} List item text"

	elif [[ ${BOX_STYLE:l} == 'l' ]];then # Left
		TEXT=$(msg_nomarkup ${MSG})
		TEXT=$(str_trim ${TEXT})
		TEXT_PAD_L=' '
		TEXT_PAD_R=$(str_rep_char ' ' $(( BOX_WIDTH - (${#TEXT_PAD_L}+${#TEXT}) - OFFSET )) )
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO} Left justifed text"

	elif [[ ${BOX_STYLE:l} == 'c' ]];then # Center
		TEXT=$(msg_nomarkup ${MSG})
		TEXT=$(str_trim ${TEXT})
		TEXT_PAD_L=$(str_center_pad $(( BOX_WIDTH-2 )) $(msg_nomarkup ${TEXT} ))
		TEXT_PAD_R=$(str_rep_char ' ' $(( ${#TEXT_PAD_L}-1 )) )
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO} Left justifed text"
		[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO} Centered text"
	fi

	MSG_OUT=$(msg_markup ${MSG}) # Apply markup
	[[ ${_DEBUG} -ge ${_MSG_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}:${TEXT_PAD_L}${MSG_OUT}${TEXT_PAD_R}"

	echo "${TEXT_PAD_L}${MSG_OUT}${TEXT_PAD_R}"
}

msg_box_clear () {
	local -A MBOX_COORDS=()
	local TAG
	local X_COORD_ARG
	local Y_COORD_ARG
	local H_COORD_ARG
	local W_COORD_ARG
	local X

	if [[ ${#} -eq 4 ]];then
		X_COORD_ARG=${1}
		Y_COORD_ARG=${2}
		H_COORD_ARG=${3}
		W_COORD_ARG=${4}
	else
		TAG=${1:=MSG}
		MBOX_COORDS=($(box_coords_get ${TAG:=MSG}))
		X_COORD_ARG=${MBOX_COORDS[X]}
		Y_COORD_ARG=${MBOX_COORDS[Y]}
		H_COORD_ARG=${MBOX_COORDS[H]}
		W_COORD_ARG=${MBOX_COORDS[W]}
	fi

	for ((X=X_COORD_ARG; X <= X_COORD_ARG + H_COORD_ARG - 1; X++));do
		tput cup ${X} ${Y_COORD_ARG}
		tput ech ${W_COORD_ARG}
	done

	list_repaint ${TAG}
	box_coords_del ${TAG}
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

list_repaint () {
	local TAG=${1}
	local -a TEXT=()
	local BA_X1=0
	local BA_X2=0
	local BA_Y1=0
	local BA_Y2=0
	local BB_X1=0
	local BB_X2=0
	local BB_Y1=0
	local BB_Y2=0
	local X5 X6 X7 Y5 Y6 Y7
	local -A TARGET_COORDS
	local -a LIST=(${(k)_BOX_COORDS})
	local -a MSG_LIST=()
	local -A BOX_B_COORDS
	local K X
	local NDX=0
	local OTAG=''

	for K in ${LIST};do
		[[ ${K} == ${TAG} ]] && continue
		BOX_B_COORDS=($(box_coords_get ${K}))
		MSG_LIST+="${BOX_B_COORDS[T]}|${K}" # time|tag
	done
	
	TARGET_COORDS=($(box_coords_get ${TAG}))
	BA_X1=${TARGET_COORDS[X]}
	BA_X2=$(( TARGET_COORDS[X] + TARGET_COORDS[H] - 1 ))
	BA_Y1=${TARGET_COORDS[Y]}
	BA_Y2=$(( TARGET_COORDS[Y] + TARGET_COORDS[W] - 1 ))

	# Compare others with TARGET
	for K in ${(On)MSG_LIST};do # sorted by time desc
		OTAG=$(cut -d '|' -f2 <<<${K})

		BOX_B_COORDS=($(box_coords_get ${OTAG}))

		BB_X1=${BOX_B_COORDS[X]}
		BB_X2=$(( BOX_B_COORDS[X] + BOX_B_COORDS[H] - 1 ))
		BB_Y1=${BOX_B_COORDS[Y]}
		BB_Y2=$(( BOX_B_COORDS[Y] + BOX_B_COORDS[W] - 1 ))

		X5=$(max ${BA_X1} ${BB_X1}) # Target top vs Other top
		Y5=$(max ${BA_Y1} ${BB_Y1}) # Target height vs Other height
		X6=$(min ${BA_X2} ${BB_X2}) # Target left vs Other left
		Y6=$(min ${BA_Y2} ${BB_Y2}) # Target width vs Other width

#		tput cup ${BA_X1} ${BA_Y1};echo -n "${REVERSE}${GREEN_FG}T${RESET}" # Target 
#		tput cup ${BA_X2} ${BA_Y2};echo -n "${REVERSE}${GREEN_FG}T${RESET}" # Target 
#		tput cup ${BB_X1} ${BB_Y1};echo -n "${BOLD}${GREEN_FG}+${RESET}" # Other
#		tput cup ${BB_X2} ${BB_Y2};echo -n "${BOLD}${GREEN_FG}+${RESET}" # Other
#
#		tput cup ${X5} ${Y6};echo -n "${BOLD}${WHITE_ON_GREY}!${CYAN_FG}${MSG2}${RESET}" # Top right
#		tput cup ${X6} ${Y5};echo -n "${BOLD}${WHITE_ON_GREY}!${CYAN_FG}${MSG2}${RESET}" # Bottom left
#		tput cup 0 0;tput el;echo -n "                    ${X5} -gt  ${X6}      ||     ${Y5}     -gt   ${Y6}"
#		tput cup 1 0;tput el;echo -n "${TAG} vs ${OTAG} - max top -gt min left || max height -gt min width"
#		read -s

		if [[ ${X5} -gt ${X6} || ${Y5} -gt ${Y6} ]];then
			#tput cup 2 0;tput el;echo -n "No intersection with TARGET:${TAG}"
			return
		else
			msg_unicode_box ${BOX_B_COORDS[X]} ${BOX_B_COORDS[Y]} ${BOX_B_COORDS[W]} ${BOX_B_COORDS[H]}
			TEXT=("${(f)$(msg_get_text ${OTAG})}")
			NDX=0
			for ((X=$((BOX_B_COORDS[X]+1));X<$((BOX_B_COORDS[X]+BOX_B_COORDS[H]-1)); X++));do
				((NDX++))
				tput cup ${X} $((BOX_B_COORDS[Y]+1));echo -n ${TEXT[${NDX}]}
			done
		fi
	done
}

msg_get_text () {
	local TAG=${1}
	local -a TEXT
	local K
	local MT
	local MX
	local MY
	local MM

	for K in ${_BOX_TEXT};do
		MT=$(cut -d'|' -f1 <<<${K})
		MX=$(cut -d'|' -f2 <<<${K})
		MY=$(cut -d'|' -f3 <<<${K})
		MM=$(cut -d'|' -f4 <<<${K})
		if [[ ${MT} == ${TAG} ]];then
			echo "${MM}"
		fi
	done
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

	# Apply markup
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
	local FOLD_WIDTH=110
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

	# Convert carriage returns to newlines, kill excess spaces, any '<' to unicode, '|' to 'or' and trim, and fold
	coproc { eval ${CMD} | \
		sed -e 's// /g'  \
		-e 's/  */ /g'  \
		-e 's/</\xe2\x98\x87/g'  \
		-e 's/|/or/g'  \
		-e 's/^[[:blank:]]*//;s/[[:blank:]]*$//' | \
		fold -s -w ${FOLD_WIDTH}  \
	}

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

	msg_box -y20 -w$((FOLD_WIDTH+4)) -P"<m>Last Page<N>" -pc -s${DELIM} -j${STYLE} ${MSG_LINES} # Display window
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

