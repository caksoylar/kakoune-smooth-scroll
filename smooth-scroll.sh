#!/bin/sh

kak_session=$1
kak_client=$2
kak_cursor_line=$3
kak_buf_line_count=$4
kak_window_height=$5
direction=$6
half=$7
duration=$8
speed=$9

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

amount=$(( (kak_window_height - 2) / (1 + half) ))
if [ $maxscroll -lt $amount ]; then
    amount=$maxscroll
fi

times=$(( amount / speed ))

i=0
t1=$(date +%s.%N)
while [ $i -lt $times ]; do
    eval "$cmd"
    t2=$(date +%s.%N)
    sleep_for=$(printf 'scale=3; %f - (%f - %f)\n' "$duration" "$t2" "$t1" | bc)
    if [ "${sleep_for#-}" = "$sleep_for" ]; then
        sleep "$sleep_for"
    fi
    t1=$t2
    i=$(( i + 1 ))
done
