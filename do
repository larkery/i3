#!/usr/bin/env bash

dmenu () {
    command dmenu -fn "Sans-16" -nb "#fee" -nf "#111" -sb "#a3a" "$@"
}

i3m () {
    i3-msg "$@" 2>&1 >/dev/null
}

view () {
    ST=$(i3-msg -t get_workspaces)
    WSN=$1
    FOCUSED_OUTPUT=$(echo "$ST" | jq '.[] | select(.focused) | .output')
    OWNER=$(echo "$ST" | jq '.[] |select(.visible)| select(.num == '$WSN') | .output')
    
    i3m "${OWNER:+move workspace to output $OWNER}; workspace number $WSN; move workspace to output $FOCUSED_OUTPUT; workspace number $WSN"
}

warp () {
    xdotool getactivewindow mousemove --polar --window %1 0 0
}

pack () {
    L=1
    i3-msg -t get_workspaces | jq -r 'sort_by(.num) |.[]| [.num, .name]|@sh' |
        {
            C="nop"
            while read -r num nam; do
                nam=$(eval "echo $nam")
                if [[ $num -ne $L ]]; then
                    C="$C; rename workspace \"$nam\" to \"${nam/$num/$L}\""
                fi
                L=$((L+1))
            done
            echo $C
            i3-msg "$C"
        }
    
}

dmenu_path () {
    cachedir=${XDG_CACHE_HOME:-"$HOME/.cache"}
    if [ -d "$cachedir" ]; then
        cache=$cachedir/dmenu_run
    else
        cache=$HOME/.dmenu_cache # if no xdg dir, fall back to dotfile in ~
    fi
    IFS=:
    if stest -dqr -n "$cache" $PATH; then
        stest -flx $PATH | sort -u | tee "$cache"
    else
        cat "$cache"
    fi
}

case $1 in
    view)
        view "$2"
        pack
        warp
        ;;
    pick)
        ST=$(i3-msg -t get_workspaces)
        NAME=$(echo "$ST" | jq -r 'sort_by(.num) | .[] | .name' | dmenu -p "workspace: ")
        [[ $? -gt 0 ]] && exit 0
        INDEX=$(echo "$ST" | jq -r '.[] | select(.name == "'$NAME'") | .num')
        if [[ -z "$INDEX" ]]; then
            MAX_INDEX=$(echo "$ST" | jq -r 'map(.num) | max')
            i3m "workspace $(( MAX_INDEX + 1)): $NAME"
        else
            view "$INDEX"
        fi
        pack
        ;;
    pack)
        pack
        ;;
    warp)
        warp
        ;;
    rename)
        NAME=$(dmenu -p "new name: ")
        [[ $? -gt 0 ]] && exit 0
        ST=$(i3-msg -t get_workspaces)
        FOCUSED_NUM=$(echo "$ST" | jq '.[] | select(.focused) | .num')
        i3m "rename workspace to \"${FOCUSED_NUM}${NAME:+: $NAME}\""
        ;;
    run)
        # version of dmenu_run which replaces itself
        exec $(dmenu_path | dmenu -p "run: ")
        ;;
    power)
        COM=$(dmenu -p "systemctl: " <<EOF
hibernate
suspend
reboot
poweroff
EOF
              )
        [[ -n $COM ]] && systemctl $COM
        ;;
    swap-outputs)
        i3m $(i3-msg -t get_workspaces |
                  jq -r '.[] | "workspace \"" + .name + "\", move workspace to output right, "') nop
        ;;
    *)
        
esac
