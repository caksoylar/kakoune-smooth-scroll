#!/bin/sh

direction=$1
half=$2
count=$3
duration=$4
speed=$5

if [ "$direction" = "d" ]; then
    maxscroll=$(( kak_buf_line_count - kak_cursor_line ))
    keys="${speed}j${speed}vj"
else
    maxscroll=$(( kak_cursor_line - 1 ))
    keys="${speed}k${speed}vk"
fi
if [ $maxscroll -eq 0 ]; then
    return
fi
cmd="printf 'execute-keys -client %s %s\\n' ""$kak_client"" ""$keys"" | kak -p ""$kak_session"""

if [ "$count" -eq 0 ]; then
    count=1
fi
amount=$(( count * (kak_window_height - 2) / (1 + half) ))
if [ $maxscroll -lt $amount ]; then
    amount=$maxscroll
fi

times=$(( amount / speed ))

i=0
t1=$(date +%s.%N)
while [ $i -lt $times ]; do
    eval "$cmd"
    t2=$(date +%s.%N)
    sleep_for=$(printf 'scale=3; %f/1000 - (%f - %f)\n' "$duration" "$t2" "$t1" | bc)
    if [ "${sleep_for#-}" = "$sleep_for" ]; then
        sleep "$sleep_for"
    fi
    t1=$t2
    i=$(( i + 1 ))
done
