# LIB Dependencies
_DEPS_+="DBG.zsh UTILS.zsh"

# LIB Vars
_DATE_LIB_DBG=5

date_diff () {
	local D1=$(date -d "$1" +%s)
	local D2=$(date -d "$2" +%s)
	local DIFF=$(( (D1 - D2) / 86400 ))

	# Expects: date +'%Y-%m-%d'
	[[ ${_DEBUG} -ge ${_DATE_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	echo ${DIFF} # Return the difference in days
}

date_since_today () {
	local D1=$(date -d "$1" +%s)
	local D2=$(date -d "$2" +%s)
	local DIFF=0

	[[ ${D1} -gt ${D2} ]] && DIFF=$(( (D1 - D2) / 86400 )) || DIFF=$(( (D2 - D1) / 86400 ))

	[[ ${DIFF} -eq 0 ]] && echo "today"
	[[ ${DIFF} -eq 1 ]] && echo "1 day ago"
	[[ ${DIFF} -gt 1 && ${DIFF} -le 7 ]] && echo "${DIFF} days ago"
	[[ ${DIFF} -gt 7 ]] && echo "over a week ago"
}

date_text () {
	local DATE_ARG=$1
	local TODAY YESTERDAY TEXT

	[[ ${_DEBUG} -ge ${_DATE_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	TODAY=$(date +'%m/%d/%y')
	YESTERDAY=$(date --date="${TODAY} -1 day" +'%m/%d/%y')

	if [[ ${DATE_ARG} == ${TODAY} ]];then
		TEXT='Today' 
	elif [[ ${DATE_ARG} == ${YESTERDAY} ]];then
		TEXT='Yesterday' 
	else
		TEXT=${DATE_ARG}

	fi

	echo ${TEXT}
}

file_date_diff () {
	local F1=${1}
	local F2=${2}
	local F1_EPOCH
	local F2_EPOCH
	
	[[ ${_DEBUG} -ge ${_DATE_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ! -e ${F1} ]] && return 1 # File not found
	[[ ! -e ${F2} ]] && return 1 # File not found

	F1_EPOCH=$(stat -c"%Y" ${F1})
	F2_EPOCH=$(stat -c"%Y" ${F2})

	[[ ${F1_EPOCH} -gt ${F2_EPOCH} ]] && echo ${F1} || echo ${F2} # Return the newest file

	return 0
}

time_diff_mins_fmod () {
	local FN=${1}
	local ACC_TM
	local MOD_TM
	local TIME_DIFF

	[[ ${_DEBUG} -ge ${_DATE_LIB_DBG} ]] && dbg "${functrace[1]} called ${0}:${LINENO}: ARGC:${#@}"

	[[ ! -e ${FN} ]] && echo "${0}: File:${FN} not found" >&2 && return 1

	local ACC_TM=$(stat -c"%X" ${FN})
	local MOD_TM=$(stat -c"%Y" ${FN})

	local TIME_DIFF=$(( (MOD_TM - ACC_TM) / 60.00 ))

	printf "%.2f\n" ${TIME_DIFF}

	return 0
}

