RESET="\033[m"
BOLD="\033[1m"
ITALIC="\033[3m"
UNDER="\033[4m"
REVERSE="\033[7m"
STRIKE="\033[9m"
OVERUND="\033[53m\033[4m"

BLACK_FG="\033[30m"
RED_FG="\033[31m"
GREEN_FG="\033[32m"
YELLOW_FG="\033[33m"
BLUE_FG="\033[34m"
MAGENTA_FG="\033[35m"
CYAN_FG="\033[36m"
WHITE_FG="\033[37m"

BLACK_BG="\033[40m"
RED_BG="\033[41m"
GREEN_BG="\033[42m"
YELLOW_BG="\033[43m"
BLUE_BG="\033[44m"
MAGENTA_BG="\033[45m"
CYAN_BG="\033[46m"
WHITE_BG="\033[47m"

WHITE_ON_GREY="\033[0m\033[0;1;37;100m"

E_BOLD=$(echo -n "\033[1m")
E_ITALIC=$(echo -n "\033[3m")
E_RESET=$(echo -n "\033[m")
E_REVERSE=$(echo -n "\033[7m")
E_STRIKE=$(echo -n "\033[9m")
E_UNDER=$(echo -n "\033[4m")

E_BLACK_FG=$(echo -n "\033[30m")
E_BLUE_FG=$(echo -n "\033[34m")
E_CYAN_FG=$(echo -n "\033[36m")
E_GREEN_FG=$(echo -n "\033[32m")
E_MAGENTA_FG=$(echo -n "\033[35m")
E_RED_FG=$(echo -n "\033[31m")
E_WHITE_FG=$(echo -n "\033[37m")
E_YELLOW_FG=$(echo -n "\033[33m")

E_BLACK_BG=$(echo -n "\033[40m")
E_BLUE_BG=$(echo -n "\033[44m")
E_CYAN_BG=$(echo -n "\033[46m")
E_GREEN_BG=$(echo -n "\033[42m")
E_MAGENTA_BG=$(echo -n "\033[45m")
E_RED_BG=$(echo -n "\033[41m")
E_WHITE_BG=$(echo -n "\033[47m")
E_YELLOW_BG=$(echo -n "\033[43m")

E_BLK_CSR=$(echo -n "\033[1 q")
E_DSH_CSR=$(echo -n "\033[3 q")
