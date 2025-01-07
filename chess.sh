#!/bin/bash

TEMP=$(getopt -o "a:p:" -n "$0" -- "$@")
eval set -- "$TEMP"

ADDRESS=localhost
PORT=38519

while true; do
    case $1 in
        -a)
            ADDRESS=$2
            shift 2;;
        -p)
            PORT=$2
            shift 2;;
        --)
            shift
            break;;
    esac
done

printf '\e[?1049h'
stty cbreak -echo -nl

board=()
moves=
move=
active=

parse_fen() {
    fen_string="$1"
    IFS=' ' read -r fen_board active castling en_passant halfmove fullmove <<< "$fen_string"

    j=0
    for ((i=0; i<${#fen_board}; i++)); do
        char="${fen_board:$i:1}"
        
        case $char in
            [a-zA-Z]) board[j]=$char; ((j++));;
            [1-8]) 
                for ((k=0; k<$char; k++)) {
                    board[j]="."
                    ((j++))
                }
                ;;

        esac
    done
}

compose_fen() {
    fen_board=""
    empty_count=0
    file_count=0
    for piece in ${board[@]}; do
        if (( $file_count >= 8)); then
            if (( $empty_count > 0)); then
                fen_board+="$empty_count"
                empty_count=0
            fi
            file_count=0
            fen_board+="/"
        fi

        if [[ $piece = "." ]]; then
            ((empty_count++))
        else
            if (( $empty_count > 0)); then
                fen_board+="$empty_count"
                empty_count=0
            fi
            fen_board+=$piece
        fi
        ((file_count++))
    done

    echo "$fen_board"
}

draw() {
    printf '\e[2J\e[H'
    row=8
    col=8
    for piece in ${board[@]}; do
        fg_col="\e[30m" # black
        bg_col="\e[46m" # cyan
        if (((row + col) % 2 == 0)); then
            bg_col="\e[107m" #bright white
        fi

        case $piece in
            [K]) piece=♔ ;;
            [Q]) piece=♕ ;;
            [R]) piece=♖ ;;
            [B]) piece=♗ ;;
            [N]) piece=♘ ;;
            [P]) piece=♙ ;;
            [k]) piece=♚ ;;
            [q]) piece=♛ ;;
            [r]) piece=♜ ;;
            [b]) piece=♝ ;;
            [n]) piece=♞ ;;
            [p]) piece=♟ ;;
            ".") piece=" ";;
        esac

        printf "$bg_col$fg_col$piece "
        if ((--col < 1 )); then
            col=8
            printf "\e[m $row\n"
            ((row--))
        fi
    done

    printf "A B C D E F G H\n"
    printf "$move";
}

exec 3<>/dev/tcp/$ADDRESS/$PORT
while true; do
    IFS="|" read -r -t0.01 fen moves <&3
    if [[ -n "$fen" ]]; then
        parse_fen "$fen"
        draw
    fi

    IFS= read -r -N1 -t0.01 char
    case $char in
        q) break;;
        [a-h1-8]) move="$move$char"; printf $char;;
        $'\n') echo "make_move $move" 1>&3; move=;;
        $'\177') 
            if [[ -n "$move" ]]; then
                move=${move::-1}
                printf "\e[D \e[D"
            fi
            ;;
        *) ;;
    esac
done

stty sane

printf '\e[?1049l'
