declare-option -hidden str scroll_py %sh{printf "%s" "${kak_source%.kak}.py"}
declare-option -hidden bool scroll_fallback false

define-command smooth-scroll -params 3 -override -docstring "
    smooth-scroll <amount> <duration> <speed>: Scroll half or full screen towards given direction smoothly

    Args:
        amount:   number of lines to scroll as the fraction of a full screen
                  positive for down, negative for up, e.g. 1 for <c-f>, -0.5 for <c-u>
        duration: amount of time between each scroll tick, in milliseconds
        speed:    number of lines to scroll with each tick
    " %{
    evaluate-commands %sh{
        amount=$1
        duration=$2
        speed=$3
        # echo "echo -debug $kak_count"

        # try to run the python version
        if type python3 >/dev/null 2>&1 && [ -f "$kak_opt_scroll_py" ]; then
            python3 "$kak_opt_scroll_py" "$amount" "$duration" "$speed" >/dev/null 2>&1 </dev/null &
            return
        fi

        # fall back to pure sh
        if [ "$kak_opt_scroll_fallback" = "false" ]; then
            printf '%s\n' "set-option global scroll_fallback true"
            echo "echo -debug kakoune-smooth-scroll: WARNING -- cannot execute python version, falling back to pure sh"
        fi

        abs_amount=${amount#-}
        if [ "$kak_count" -eq 0 ]; then
            count=1
        else
            count=$kak_count
        fi
        if [ "$speed" -eq 0 ]; then
            speed=1
        fi
        if [ "$abs_amount" = "$amount" ]; then
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

        toscroll=$(echo "$count * $abs_amount * ($kak_window_height - 2) / 1" | bc)
        if [ "$maxscroll" -lt "$toscroll" ]; then
            toscroll=$maxscroll
        fi

        times=$(( toscroll / speed ))

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

# suggested mappings (python)
map global normal <c-d> ': smooth-scroll  0.5 20 0<ret>'
map global normal <c-u> ': smooth-scroll -0.5 20 0<ret>'
map global normal <c-f> ': smooth-scroll  1.0 10 0<ret>'
map global normal <c-b> ': smooth-scroll -1.0 10 0<ret>'

# suggested mappings (sh)
#map global normal <c-d> ': smooth-scroll  0.5 40 2<ret>'
#map global normal <c-u> ': smooth-scroll -0.5 40 2<ret>'
#map global normal <c-f> ': smooth-scroll  1.0 20 2<ret>'
#map global normal <c-b> ': smooth-scroll -1.0 20 2<ret>'
