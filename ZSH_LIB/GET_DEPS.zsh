for D in ${=_DEPS_};do
	if [[ -e ${_LIB_DIR}/${D} ]];then
		source ${_LIB_DIR}/${D}
	else
		echo "Cannot source:${_LIB_DIR}/${D} - not found"
		exit 1
	fi
done
