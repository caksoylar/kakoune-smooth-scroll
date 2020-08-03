# user-facing options
declare-option -docstring %{
    space-separated list of <key>=<value> pairs that specify the behavior of
    smooth scroll.

    Following keys are accepted:
        speed:        number of lines to scroll per tick, 0 for inertial
                      scrolling (default: 0)
        interval:     average milliseconds between each scroll (default: 10)
        max_duration: maximum duration of a scroll in milliseconds (default: 500)
} str-to-str-map scroll_options speed=0 interval=10 max_duration=500

declare-option -docstring %{
    list of keys to apply smooth scrolling in normal mode. Specify only keys
    that do not modify the buffer. If source and destination mappings are different,
    specify them in the format <src>=<dst>. Existing mappings for source keys will
    be overridden.

    Default:
        <c-f> <c-b> <c-d> <c-u> <pageup> <pagedown> ( ) m M <a-semicolon>
        <percent> n <a-n> N <a-N>
} str-list scroll_keys_normal <c-f> <c-b> <c-d> <c-u> <pageup> <pagedown> ( ) m M <a-semicolon> <percent> n <a-n> N <a-N>

declare-option -docstring %{
    list of keys to apply smooth scrolling in goto mode. If source and
    destination mappings are different, specify them in the format <src>=<dst>.
    Existing mappings for source keys will be overridden.

    Default:
        g j k e .
} str-list scroll_keys_goto g j k e .

declare-option -docstring %{
    list of keys to apply smooth scrolling in object mode. If source and
    destination mappings are different, specify them in the format <src>=<dst>.
    Existing mappings for source keys will be overridden.

    Default:
        p i B { }
} str-list scroll_keys_object p i B { }

# declare-option -docstring %{
#     list of keys to apply smooth scrolling in view mode. If source and
#     destination mappings are different, specify them in the format <src>=<dst>.
#     Existing mappings for source keys will be overridden.

#     Default:
#         v c m t
# } str-list scroll_keys_view v c m t

# internal
declare-option -hidden str scroll_py %sh{printf "%s" "${kak_source%.kak}.py"}  # python script path
declare-option -hidden bool scroll_fallback false  # remember if we fell back to sh impl
declare-option -hidden str scroll_running ""       # pid of scroll process if it running
declare-option -hidden str scroll_window           # new location after a key press
declare-option -hidden str-list scroll_selections  # new selections after a key press
declare-option -hidden str scroll_client           # store for WinSetOption hook which runs in draft context
declare-option -hidden str scroll_mode             # key we used to enter a mode so we can replicate it

define-command smooth-scroll-enable -docstring "enable smooth scrolling for window" %{
    smooth-scroll-disable

    # map the list of keys to smoothly scroll for given by the scroll_keys_* options
    evaluate-commands %sh{
        # $kak_quoted_opt_scroll_keys_normal, $kak_quoted_opt_scroll_keys_goto, $kak_quoted_opt_scroll_keys_object
        for mode in normal goto object; do
            eval option="\$kak_quoted_opt_scroll_keys_$mode"
            eval "set -- $option"
            for key; do
                # in case both sides of the mapping were given with lhs=rhs, split
                lhs=${key%%=*}
                rhs=${key#*=}
                printf 'smooth-scroll-map-key %s %s %s\n' "$mode" "$lhs" "$rhs"
            done
        done
    }

    set-option window scroll_running ""
    set-option window scroll_client %val{client}

    # remember what key we used to enter a mode so we can replicate it
    hook -group scroll window NormalKey [gGvV[\]{}]|<a-[ai]> %{
        set-option window scroll_mode %val{hook_param}
    }

    # when we exit normal mode, kill the scrolling process if it is currently running
    hook -group scroll window ModeChange push:normal:.* %{
        evaluate-commands %sh{
            if [ -n "$kak_opt_scroll_running" ]; then
                kill "$kak_opt_scroll_running"
                printf 'set-option window scroll_running ""\n'
            fi
        }
    }

    # started scrolling, make cursor invisible to make it less jarring
    hook -group scroll window WinSetOption scroll_running=\d+ %{
        set-face window PrimaryCursor @default
        set-face window PrimaryCursorEol @default
        set-face window LineNumberCursor @LineNumbers
    }

    # done scrolling, so restore cursor highlighting and original selection
    hook -group scroll window WinSetOption scroll_running= %{
        evaluate-commands -client %opt{scroll_client} %{
            try %{ select %opt{scroll_selections} }
        }
        unset-face window PrimaryCursor
        unset-face window PrimaryCursorEol
        unset-face window LineNumberCursor
    }
}

define-command smooth-scroll-disable -docstring "disable smooth scrolling for window" %{
    # undo window-level mappings
    evaluate-commands %sh{
        # $kak_quoted_opt_scroll_keys_normal, $kak_quoted_opt_scroll_keys_goto, $kak_quoted_opt_scroll_keys_object
        for mode in normal goto object; do
            eval option="\$kak_quoted_opt_scroll_keys_$mode"
            eval "set -- $option"
            for key; do
                lhs=${key%%=*}
                printf 'unmap window %s %s\n' "$mode" "$lhs"
            done
        done
    }
    # remove our hooks
    remove-hooks window scroll

    # restore faces if we somehow didn't before
    unset-face window PrimaryCursor
    unset-face window PrimaryCursorEol
}

define-command smooth-scroll-map-key -params 3 -docstring %{
    smooth-scroll-map-key <mode> <lhs> <rhs>: map key <lhs> to key <rhs> for
    mode <mode> and enable smooth scrolling for that operation
} %{
    evaluate-commands %sh{
        mode="$1"
        if [ "$mode" = "normal" ]; then
            prefix="''"
            esc=""
        else
            prefix="%%opt{scroll_mode}"
            esc="<esc>"
        fi
        lhs=$2
        rhs=$(echo "$3" | sed -e 's/^</<lt>/' -e 's/>$/<gt>/')
        printf 'map window %s %s "%s: smooth-scroll-do-key %s %s<ret>"\n' "$mode" "$lhs" "$esc" "$rhs" "$prefix"
    }
}

define-command smooth-scroll-do-key -params 2 -hidden %{
    # execute key in draft context to figure out the final selection and window_range
    evaluate-commands -draft %{
        execute-keys %val{count} %arg{2} %arg{1}
        set-option window scroll_window %val{window_range}
        set-option window scroll_selections %val{selections_desc}
    }

    # check if we moved the viewport, then smoothly scroll there if we did
    evaluate-commands %sh{
        if [ "$kak_window_range" != "$kak_opt_scroll_window" ] && [ -z "$kak_opt_scroll_running" ]; then
            diff=$(( ${kak_opt_scroll_window%% *} - ${kak_window_range%% *} ))
            abs_diff=${diff#-}
            if [ "$abs_diff" -gt 1 ]; then  # we moved the viewport by at least 2
                # scroll to new position smoothly (selection will be restored when done)
                printf 'execute-keys <space>\n'
                printf 'smooth-scroll-move %s\n' "$diff"
                exit 0
            fi
        fi
        # we haven't moved the viewport enough so just apply selection 
        printf 'select %s\n' "$kak_opt_scroll_selections"
    }
}

define-command smooth-scroll-move -params 1 -hidden %{
    evaluate-commands %sh{
        amount=$1
        # try to run the python version
        if type python3 >/dev/null 2>&1 && [ -f "$kak_opt_scroll_py" ]; then
            python3 "$kak_opt_scroll_py" "$amount" >/dev/null 2>&1 </dev/null &
            printf 'set-option window scroll_running %s\n' "$!"
            exit 0
        fi

        # fall back to pure sh
        if [ "$kak_opt_scroll_fallback" = "false" ]; then
            printf 'set-option global scroll_fallback true\n'
            printf 'echo -debug kakoune-smooth-scroll: WARNING -- cannot execute python version, falling back to pure sh\n'
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
            printf "eval -client %s '%s'\\n" "$kak_client" 'set-option window scroll_running ""' | kak -p "$kak_session" 
        ) >/dev/null 2>&1 </dev/null &
        printf 'set-option window scroll_running %s\n' "$!"
    }
}
