declare-option -hidden str scroll_py %sh{printf "%s" "${kak_source%.kak}.py"}

define-command smooth-scroll -params 4 -override -docstring "
    smooth-scroll <direction> <half> <duration> <speed>: Scroll half or full screen towards given direction smoothly

    Args:
        direction: 'd' for down or 'u' for up
        half:      0 for full screen scroll (<c-f>/<c-b>), 1 for half (<c-d>/<c-u>)
        duration:  amount of time between each scroll tick, in milliseconds
        speed:     number of lines scroll with each tick
    " %{
    echo -debug %sh{
        direction=$1
        half=$2
        duration=$3
        speed=$4

        # try to run the python version
        if type python3 >/dev/null 2>&1 && [ -f "$kak_opt_scroll_py" ]; then
            python3 "$kak_opt_scroll_py" "$direction" "$half" "$duration" "$speed" >/dev/null 2>&1 </dev/null &
            return
        fi
        echo "kakoune-smooth-scroll: WARNING -- cannot execute python version, falling back to pure sh"

        # fall back to pure sh
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

        (
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
        ) >/dev/null 2>&1 </dev/null &
    }
}

# suggested mappings
map global normal <c-d> ': smooth-scroll d 1 10 1<ret>'
map global normal <c-u> ': smooth-scroll u 1 10 1<ret>'
map global normal <c-f> ': smooth-scroll d 0  5 1<ret>'
map global normal <c-b> ': smooth-scroll u 0  5 1<ret>'
