REGEX='^[0-9]+$'
for S in ${SIZES};do
	((SNDX++))
	echo "${WHITE_FG}${SNDX}${RESET}) ${S}"
done

SIZE=''
while true;do
	echo -n "Choose size or <ENTER> to ignore:"
	read RESPONSE
	[[ -z ${RESPONSE} ]] && break
	if [[ ${RESPONSE} =~ ${REGEX} && (${RESPONSE} -ge 1 && ${RESPONSE} -le ${#SIZES}) ]] ; then
		SIZE=${SIZES[${RESPONSE}]}
		break
	else
		echo "Invalid selection..."
	fi
done
echo
