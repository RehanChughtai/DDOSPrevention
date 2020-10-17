self_ip=$(ip route get 1.1.1.1 | grep via | sed -E 's/.* src ([^ ]+) .*/\1/')
stdbuf -oL tcpdump -n -i any tcp and tcp[tcpflags] == tcp-syn and \(dst host "$self_ip" or dst host 127.0.0.1\) 2>/dev/null | stdbuf -oL cut -d' ' -f3 | stdbuf -oL sed -r 's/(.*)\.[0-9]+/\1/' > syn_ip_buffer
