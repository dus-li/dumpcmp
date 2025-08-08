#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# SPDX-FileCopyrightText: Duszku

set -euo pipefail


################################################################################
# VARIABLES
################################################################################

WIDTH=""
START=""
TARGET=""
HAS_DESC=0
REGISTERS=()
DUMP1_LOCATION=""
DUMP2_LOCATION=""


################################################################################
# HELPER FUNCTIONS
################################################################################

err() {
	>&2 printf "\033[31mERROR\033[0m\t%s\n" "${@}"
	exit 1
}

pause() {
	read -rn1 -p "Press any key to continue..." discard
}

it() { printf "\033[3m%s\033[0m" "${@}"; }
bf() { printf "\033[1m%s\033[0m" "${@}"; }

usage() {
	cat <<EOF
$(bf Usage:) ${0} $(it DESCFILE)

Parameters:
  $(bf DESCFILE)  Register description file

Description:

  Make sure the board invokes a breakpoint instruction at a relevant location.
  The script will guide you through switching implementations and pressing reset 
  button.
EOF
}

run_gdb() {
	end=$(( ${START} + ${WIDTH} * ${#REGISTERS[@]} ))

gdb >/dev/null 2>&1 <<EOF
target ${TARGET}
continue

append binary memory ${1} ${START} $(printf "0x%x" "${end}")
exit
y
EOF
}


################################################################################
# ACTIONS
################################################################################


if [ ${#} -lt 1 ]; then
	usage
	exit 1
fi


# Locate header boundaries

mapfile -t DELIMITERS < <(grep -n -- --- "${1}" | cut -d: -f1)
if [ ${#DELIMITERS[@]} -ne 2 ]; then
	err "File contains too many section delimiters"
fi

DELIMITERS[0]=$(( ${DELIMITERS[0]} + 1))
DELIMITERS[1]=$(( ${DELIMITERS[1]} - 1))


# Process file header

getval() { echo "${1}" | cut -d: -f2-; }
while IFS="\n" read -r line; do
	case "${line}" in
		DESCRIPTION)
			HAS_DESC=1
			;;
		Width:*)
			WIDTH=$(getval "${line}")
			;;
		Start:*)
			START=$(getval "${line}")
			;;
		Target:*)
			TARGET=$(getval "${line}")
			;;
		*)
			err "Unrecognized header field"
	esac
done < <(head -n "${DELIMITERS[1]}" "${1}" | tail -n +"${DELIMITERS[0]}")


if [ "${HAS_DESC}" == "0" ]; then
	err "File does not not contain a proper header"
fi


# Get register list

LIST_OFFSET=$(( ${DELIMITERS[1]} + 2 ))
mapfile -t REGISTERS < <(tail -n +"${LIST_OFFSET}" "${1}")
if [ ${#REGISTERS[@]} -eq 0 ]; then
	err "No registers listed in file"
fi


# Create temporary files

DUMP1_LOCATION="$(mktemp)"
DUMP2_LOCATION="$(mktemp)"

# Collect first dump

echo "Please prepare the first implementation"
pause
run_gdb "${DUMP1_LOCATION}"


# Collect second dump

echo "Please prepare the second implementation"
pause
run_gdb "${DUMP2_LOCATION}"


# Compare files

LONGEST=0
for reg in ${REGISTERS[@]}; do
	if [ ${#reg} -gt ${LONGEST} ]; then
		LONGEST=${#reg}
	fi
done

gethex() { xxd -eg4 -c 4 "${1}" | awk '{print "0x" $2}'; }

echo
paste <(gethex "${DUMP1_LOCATION}")      \
      <(gethex "${DUMP2_LOCATION}")      \
      <(printf "%s\n" "${REGISTERS[@]}") \
| while IFS=$'\t' read -r val1 val2 name; do
	if [ "${val1}" != "${val2}" ]; then
		len=$(( ${LONGEST} - ${#name} + 1 ))
		printf "Value of ${name} differs:"
		printf "%${len}s" " " 
		printf "${val1} vs ${val2}\n"
	fi
done
