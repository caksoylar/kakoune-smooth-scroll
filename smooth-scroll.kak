declare-option -hidden str src_dir %sh{printf "%s" "${kak_source%/*}"}

define-command smooth-scroll -params 4 -override %{
    echo -debug %sh{
        echo "$kak_source"
        direction=$1
        half=$2
        duration=$3
        speed=$4

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
        echo $duration

        (
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
        ) >/dev/null 2>&1 </dev/null &
    }
}

map global normal <c-d> ': smooth-scroll d 1 0.05 1<ret>'
map global normal <c-u> ': smooth-scroll u 1 0.05 1<ret>'
map global normal <c-f> ': smooth-scroll d 0 0.05 1<ret>'
map global normal <c-b> ': smooth-scroll u 0 0.05 1<ret>'
