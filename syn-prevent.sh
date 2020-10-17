grand_total_good=0
grand_total_bad=0

cleanup() {
    echo
    echo

	kill -- "-$!"
	wait "$!" >/dev/null 2>&1

    echo "Total good packets: $grand_total_good"
    echo "Total bad packets: $grand_total_bad"
    echo

	iptables -F
	echo iptables entries cleared

	exit 0
}

trap "cleanup" INT EXIT

echo > blacklist
echo > syn_ip_buffer

set -m

sleep_interval="$1"

if [ -z "$sleep_interval" ]; then
	sleep_interval=10
fi

nohup /bin/bash ./tcpdump.sh 2>/dev/null &

echo

while true; do
	sleep "$sleep_interval" || exit 0

	total_good=0
	total_bad=0

	while read ip_count; do
		if [ -z "$ip_count" ]; then
			continue
		fi

		count=$(echo "$ip_count" | cut -d' ' -f1)
		ip=$(echo "$ip_count" | cut -d' ' -f2)

		if [ "$count" -gt 20 ]; then
			blacklisted=0
			while read existing_ip; do
				if [ "$existing_ip" = "$ip" ]; then
					blacklisted=1
				fi
			done <<< $(cat blacklist)

			if [ "$blacklisted" = 0 ]; then
				iptables -I INPUT -s "$ip" -p tcp -j REJECT --reject-with tcp-reset
				echo "$ip" >> blacklist
			fi

			total_bad=$(( "$total_bad" + "$count" ))
		else
			total_good=$(( "$total_good" + "$count" ))
		fi

	done <<< $(sort syn_ip_buffer | uniq -c | tr -s ' ' | xargs -n2 | sort -nr)

	good=$(( "$total_good" / "$sleep_interval"))
	bad=$(( "$total_bad" / "$sleep_interval"))
	echo -ne "\rGood: $good/s; Bad: $bad/s"

    grand_total_good=$(( "$grand_total_good" + "$total_good" ))
    grand_total_bad=$(( "$grand_total_bad" + "$total_bad" ))

	kill -- "-$!"
	wait "$!" >/dev/null 2>&1

	nohup /bin/bash ./tcpdump.sh 2>/dev/null &
done
