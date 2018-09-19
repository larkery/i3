#!/usr/bin/env bash

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

case $1 in
    view)
        view "$2"
        pack
        ;;
    pick)
        ST=$(i3-msg -t get_workspaces)
        NAME=$(echo "$ST" | jq -r '.[] | .name' | dmenu -p "workspace: ")
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
        xdotool getwindowfocus mousemove --polar --window %1 0 0
        ;;
    rename)
        NAME=$(dmenu -p "new name: ")
        [[ $? -gt 0 ]] && exit 0
        ST=$(i3-msg -t get_workspaces)
        FOCUSED_NUM=$(echo "$ST" | jq '.[] | select(.focused) | .num')
        i3m "rename workspace to \"${FOCUSED_NUM}${NAME:+: $NAME}\""
        ;;
    *)
        
esac
