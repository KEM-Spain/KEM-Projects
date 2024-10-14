typeset -A SEEN=()
for D in ${=_DEPS_};do
	[[ ${SEEN[${D}]} -eq 1 ]] && continue
	if [[ -e ${_LIB_DIR}/${D} ]];then
		source ${_LIB_DIR}/${D}
		SEEN[${D}]=1
	else
		echo "Cannot source:${_LIB_DIR}/${D} - not found"
		exit 1
	fi
done
