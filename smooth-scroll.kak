declare-option -hidden str scroll_py %sh{printf "%s" "${kak_source%.kak}.py"}
declare-option -hidden bool scroll_fallback false
declare-option -hidden bool scroll_running false
declare-option -hidden str scroll_window "-100 0 0 0"
declare-option -hidden str-list scroll_selections
declare-option str-to-str-map scroll_options speed=0 duration=10

remove-hooks global scroll 
hook -group scroll global NormalIdle .* smooth-scroll
hook -group scroll global NormalKey .* smooth-scroll

define-command smooth-scroll -override %{
    evaluate-commands %sh{
        if [ "$kak_window_range" != "$kak_opt_scroll_window" -a "$kak_opt_scroll_running" = "false" ]; then
            printf '%s\n' "echo -debug $kak_window_range -> $kak_opt_scroll_window"
            printf '%s\n' "set-option window scroll_selections %val{selections_desc}"
            diff=$(( ${kak_window_range%% *} - ${kak_opt_scroll_window%% *} ))
            selections=$kak_selections_desc
            options=$kak_opt_scroll_options
            session=$kak_session
            client=$kak_client
            if [ "${diff#-}" -gt 10 ]; then
                printf '%s\n' "echo -debug -- $diff"
                printf '%s\n' "set-option global scroll_running true"
                python3 "$kak_opt_scroll_py" "$kak_opt_scroll_window" "$kak_window_range" >/dev/null 2>&1 </dev/null &
            fi
        fi
    }
    set-option window scroll_window %val{window_range}
}
