NDX=0
for L in ${LIST};do
	((NDX++))
	tput cup 0 0; printf "\rProcessing line ${WHITE_FG}%d${RESET} of ${WHITE_FG}%d${RESET} lines ${WHITE_FG}%%${BOLD}${GREEN_FG}%.2f${RESET}" ${NDX} ${#LIST} $(( NDX * 100. / ${#LIST} ))
done
