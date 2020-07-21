declare-option -hidden str scroll_py %sh{printf "%s" "${kak_source%.kak}.py"}
declare-option -hidden bool scroll_running false
declare-option -hidden str scroll_window
declare-option -hidden str scroll_client
declare-option -hidden str-list scroll_selections

# user-facing
declare-option str-to-str-map scroll_options speed=0 duration=10

define-command smooth-scroll-disable -override %{
    remove-hooks window scroll
    unset-face window PrimaryCursor
    unset-face window PrimaryCursorEol
}

define-command smooth-scroll-enable -override %{
    smooth-scroll-disable

    hook -group scroll window NormalIdle .* smooth-scroll
    # hook -group scroll window NormalKey .* smooth-scroll

    set-option window scroll_running false
    set-option window scroll_window %val{window_range}
    set-option window scroll_client %val{client}

    # hook -group scroll window WinSetOption scroll_selections=.* %{
    #     echo -debug "selections: %opt{scroll_selections}"
    # }
    # hook -group scroll window WinSetOption scroll_window=.* %{
    #     echo -debug "window: %opt{scroll_window}"
    # }

    hook -group scroll window WinSetOption scroll_running=true %{
        # make cursor invisible to make scroll less jarring
        set-face window PrimaryCursor @default
        set-face window PrimaryCursorEol @default"
    }

    hook -group scroll window WinSetOption scroll_running=false %{
        # restore cursor highlighting and original selection
        evaluate-commands -client %opt{scroll_client} %{
            select %opt{scroll_selections}
        }
        unset-face window PrimaryCursor
        unset-face window PrimaryCursorEol
    }
}

define-command smooth-scroll -hidden -override %{
    evaluate-commands %sh{
        # make these available to the python script
        # shellcheck disable=SC2034
        options=$kak_opt_scroll_options
        session=$kak_session
        client=$kak_client

        if [ "$kak_window_range" != "$kak_opt_scroll_window" ] && [ "$kak_opt_scroll_running" = "false" ]; then
            # printf '%s\n' "echo -debug $kak_window_range -> $kak_opt_scroll_window"
            diff=$(( ${kak_window_range%% *} - ${kak_opt_scroll_window%% *} ))
            abs_diff=${diff#-}
            if [ "$abs_diff" -gt 10 ]; then
                printf '%s\n' "set-option window scroll_selections %val{selections_desc}"
                printf '%s\n' "set-option window scroll_window %val{window_range}"
                printf '%s\n' "set-option window scroll_running true"

                # scroll back to original position
                printf '%s\n' "execute-keys <space>"
                if [ "$abs_diff" = "$diff" ]; then
                    printf '%s\n' "execute-keys ${abs_diff}k${abs_diff}vk"
                else
                    printf '%s\n' "execute-keys ${abs_diff}j${abs_diff}vj"
                fi

                # scroll to new position smoothly
                python3 "$kak_opt_scroll_py" "$diff" >/dev/null 2>&1 </dev/null &
                return
            fi
        fi
        printf '%s\n' "set-option window scroll_window %val{window_range}"
    }
}
