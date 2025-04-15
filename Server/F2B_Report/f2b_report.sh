clear

jails=$(sudo fail2ban-client status | sed -n 's/`- Jail list:[[:space:]]*//p' | tr ',' '\n' | tr -d ' ')
jails_array=()
IFS=$'\n' read -r -d '' -a jails_array < <(printf "%s" "$jails")

output=0

function set_full_output () {
	total_banned=0
	total_passed=0
	for jail in "${jails_array[@]}"; do
		currentjail=$(sudo fail2ban-client status "$jail")

		output+=$(echo -e "\n$currentjail" \
		| awk -v jail_name="$jail" '{gsub("jail: " jail_name, "\033[32m&\033[0m");gsub(/([0-9]{1,3}\.){3}[0-9]{1,3}/, "\033[31m&\033[0m");print}')
	done
}

function set_normal_output () {
	total_banned=0
	total_passed=0
	for jail in "${jails_array[@]}"; do
		currentjail=$(sudo fail2ban-client status "$jail")
		currentjail_jail=$(echo "$currentjail" | grep 'jail: ')
		currentjail_banned=$(echo "$currentjail" | grep 'Banned IP list:')
		output+=$(echo -e "\n$(tput setab 7)$(tput setaf 1) $currentjail_jail $(tput sgr 0)\n")
		output+=$(echo -e "\n$(tput setaf 1) $currentjail_banned $(tput sgr 0)\n")
	done
}

function show_stats () {
	total_banned=0
	total_passed=0
	for jail in "${jails_array[@]}"; do
		currentjail=$(sudo fail2ban-client status "$jail")

		totalbanned_line=$(echo "$currentjail" | grep ' |- Total banned: ' | awk -F'\t' '{print $2}')
		totalpassed_line=$(echo "$currentjail" | grep '|- Total failed: ' | awk -F'\t' '{print $2}')
		total_banned=$((totalbanned_line + 0 + total_banned))
		total_passed=$((totalpassed_line + 0 + total_passed))
	done

	printf '%.s─' $(seq 1 $(tput cols))
	echo -e '\nStats:'
	printf '%.s─' $(seq 1 $(tput cols))
	echo -e "|Banned: | $total_banned"
	echo -e "|Passed: | $total_passed"
}


if [[ "$option" == "n" ]] || [[ "$option" == "1" ]]; then
	echo "option 1"
	set_normal_output
	output+=$'\n'
	output+=$(show_stats)
	echo -e "$output" | less -R
elif [[ "$option" == "v" ]] || [[ "$option" == "2" ]]; then
	echo "option 2"
	set_full_output
	echo "$output" | less -R
elif [[ "$option" == "s" ]] || [[ "$option" == "3" ]]; then
	echo "option 3"
	show_stats
fi


