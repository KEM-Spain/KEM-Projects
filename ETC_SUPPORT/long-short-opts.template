#!/usr/bin/zsh

die() { echo "$*" >&2; exit 2; }  # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }

while getopts ab:c:-: OPT; do
	if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
		OPT="${OPTARG%%=*}"       # extract long option name
		OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
		OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
	fi
	case "$OPT" in
		a | alpha )    alpha=true ;;
		b | bravo )    needs_arg; bravo="$OPTARG" ;;
		c | charlie )  needs_arg; charlie="$OPTARG" ;;
		??* )          die "Illegal option --$OPT" ;;  # bad long option
		? )            exit 2 ;;  # bad short option (error reported via getopts)
	esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list
