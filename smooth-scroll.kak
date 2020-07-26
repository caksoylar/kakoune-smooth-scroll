# user-facing
declare-option str-to-str-map scroll_options speed=0 interval=10 max_duration=1000
declare-option str-list scroll_keys_normal <c-f> <c-b> <c-d> <c-u> <pageup> <pagedown> ( ) m M <a-semicolon> <percent> n <a-n> N <a-N>
declare-option str-list scroll_keys_goto g j k e .
declare-option str-list scroll_keys_view v c m t
declare-option str-list scroll_keys_object p i B { }

# internal
declare-option -hidden str scroll_py %sh{printf "%s" "${kak_source%.kak}.py"}
declare-option -hidden bool scroll_fallback false
declare-option -hidden bool scroll_running false
declare-option -hidden str scroll_window
declare-option -hidden str scroll_client
declare-option -hidden str scroll_mode
declare-option -hidden str-list scroll_selections

define-command smooth-scroll-disable -override %{
    evaluate-commands %sh{
        eval "set -- $kak_quoted_opt_scroll_keys_normal"
        for key; do
            printf 'unmap window normal %s\n' "$key"
        done

        eval "set -- $kak_quoted_opt_scroll_keys_goto"
        for key; do
            printf 'unmap window goto %s\n' "$key"
        done

        eval "set -- $kak_quoted_opt_scroll_keys_view"
        for key; do
            printf 'unmap window view %s\n' "$key"
        done

        eval "set -- $kak_quoted_opt_scroll_keys_object"
        for key; do
            printf 'unmap window object %s\n' "$key"
        done
    }
    unset-face window PrimaryCursor
    unset-face window PrimaryCursorEol
}

define-command smooth-scroll-enable -override %{
    smooth-scroll-disable

    evaluate-commands %sh{
        eval "set -- $kak_quoted_opt_scroll_keys_normal"
        mode="''"
        for key; do
            rhs=$(echo "$key" | sed -e 's/^</<lt>/' -e 's/>$/<gt>/')
            printf 'map window normal %s ": smooth-scroll-do-key %s %s<ret>"\n' "$key" "$rhs" "$mode"
        done

        mode="%%opt{scroll_mode}"
        eval "set -- $kak_quoted_opt_scroll_keys_goto"
        for key; do
            rhs=$(echo "$key" | sed -e 's/^</<lt>/' -e 's/>$/<gt>/')
            printf 'map window goto %s "<esc>: smooth-scroll-do-key %s %s<ret>"\n' "$key" "$rhs" "$mode"
        done

        eval "set -- $kak_quoted_opt_scroll_keys_view"
        for key; do
            rhs=$(echo "$key" | sed -e 's/^</<lt>/' -e 's/>$/<gt>/')
            printf 'map window view %s "<esc>: smooth-scroll-do-key %s %s<ret>"\n' "$key" "$rhs" "$mode"
        done

        eval "set -- $kak_quoted_opt_scroll_keys_object"
        for key; do
            rhs=$(echo "$key" | sed -e 's/^</<lt>/' -e 's/>$/<gt>/')
            printf 'map window object %s "<esc>: smooth-scroll-do-key %s %s<ret>"\n' "$key" "$rhs" "$mode"
        done
    }

    set-option window scroll_running false
    set-option window scroll_client %val{client}

    # hook -group scroll window WinSetOption scroll_selections=.* %{
    #     echo -debug "selections: %opt{scroll_selections}"
    # }
    # hook -group scroll window WinSetOption scroll_window=.* %{
    #     echo -debug "window: %opt{scroll_window}"
    # }

    hook -group scroll window NormalKey [gGvV[\]{}]|<a-a>|<a-i> %{
        # echo -debug "got key: %val{hook_param}"
        set-option window scroll_mode %val{hook_param}
    }

    hook -group scroll window WinSetOption scroll_running=true %{
        # make cursor invisible to make scroll less jarring
        set-face window PrimaryCursor @default
        set-face window PrimaryCursorEol @default
        set-face window LineNumberCursor @LineNumbers
    }

    hook -group scroll window WinSetOption scroll_running=false %{
        # restore cursor highlighting and original selection
        evaluate-commands -client %opt{scroll_client} %{
            select %opt{scroll_selections}
        }
        unset-face window PrimaryCursor
        unset-face window PrimaryCursorEol
        unset-face window LineNumberCursor
    }
}

define-command smooth-scroll-do-key -params 2 -hidden -override %{
    # echo -debug "triggered %arg{1} %arg{2}"
    evaluate-commands -draft %{
        execute-keys %arg{2} %arg{1}
        set-option window scroll_window %val{window_range}
        set-option window scroll_selections %val{selections_desc}
    }
    # echo -debug "%val{window_range} -> %opt{scroll_window}"
    evaluate-commands %sh{
        if [ "$kak_window_range" != "$kak_opt_scroll_window" ] && [ "$kak_opt_scroll_running" = "false" ]; then
            # printf '%s\n' "echo -debug $kak_opt_scroll_window -> $kak_window_range"
            diff=$(( ${kak_opt_scroll_window%% *} - ${kak_window_range%% *} ))
            abs_diff=${diff#-}
            if [ "$abs_diff" -gt 1 ]; then
                # printf '%s\n' "echo -debug diff: $diff"

                printf '%s\n' "set-option window scroll_running true"
                printf '%s\n' "execute-keys <space>"

                # scroll to new position smoothly
                printf '%s\n' "smooth-scroll-move $diff"
                return
            fi
        fi
        printf '%s\n' "select $kak_opt_scroll_selections"
    }
}

define-command smooth-scroll-move -params 1 -hidden -override %{
    evaluate-commands %sh{
        amount=$1
        # try to run the python version
        if type python3 >/dev/null 2>&1 && [ -f "$kak_opt_scroll_py" ]; then
            python3 "$kak_opt_scroll_py" "$amount" >/dev/null 2>&1 </dev/null &
            return
        fi

        # fall back to pure sh
        if [ "$kak_opt_scroll_fallback" = "false" ]; then
            printf '%s\n' "set-option global scroll_fallback true"
            echo "echo -debug kakoune-smooth-scroll: WARNING -- cannot execute python version, falling back to pure sh"
        fi

        eval "$kak_opt_scroll_options"
        speed=${speed:-0}
        interval=${interval:-10}
        max_duration=${max_duration:-1000}
        if [ "$speed" -eq 0 ]; then
            speed=1
        fi

        abs_amount=${amount#-}
        if [ "$abs_amount" = "$amount" ]; then
            keys="${speed}j${speed}vj"
        else
            keys="${speed}k${speed}vk"
        fi
        cmd="printf 'execute-keys -client %s %s\\n' ""$kak_client"" ""$keys"" | kak -p ""$kak_session"""

        times=$(( abs_amount / speed ))
        if [ $(( times * interval )) -gt "$max_duration" ]; then
            interval=0
        fi
        (
            i=0
            t1=$(date +%s.%N)
            while [ $i -lt $times ]; do
                eval "$cmd"
                if [ "$interval" -gt 0 ]; then
                    t2=$(date +%s.%N)
                    sleep_for=$(printf 'scale=3; %f/1000 - (%f - %f)\n' "$interval" "$t2" "$t1" | bc)
                    if [ "$sleep_for" -gt 0 ]; then
                        sleep "$sleep_for"
                    fi
                    t1=$t2
                fi
                i=$(( i + 1 ))
            done
            printf "eval -client %s '%s'\\n" "$kak_client" "set-option window scroll_running false" | kak -p "$kak_session" 
        ) >/dev/null 2>&1 </dev/null &
    }
}
