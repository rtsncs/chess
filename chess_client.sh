#!/bin/bash

show_help() {
    cat << EOF
Usage:
    ./chess_client.sh [-a ADDRESS] [-p PORT]

OPTIONS
  -a ADDRESS  Address of the chess server (default: localhost).
  -p PORT     Port of the chess server (default: 38519).

DESCRIPTION
  This script is a text-based interface for playing chess, communicating with a
  chess server via TCP protocol. The chessboard and pieces are displayed in the
  terminal in a graphical style. The user can enter moves in long algebraic
  notation (e.g., 'e2e4'), and the script sends these moves to the server.

EXAMPLES
  ./chess_client.sh
      Starts the chess client with default settings (localhost, port 38519).
  
  ./chess_client.sh -a 192.168.1.100 -p 4000
      Connects to the chess server at address 192.168.1.100 and port 4000.

COMMANDS
  - Moves can be entered in long algebraic notation, e.g., 'e2e4'.
  - To promote a pawn, add the letter for the piece you want to promote to, e.g., 'e7e8=q' (promoting to a queen).
  - To quit the program, press 'w'.
EOF
    exit
}

piece_color="\e[30m"
black_color="\e[46m"
white_color="\e[107m"
from_color="\e[43m"
to_color="\e[105m"
possible_color="\e[102m"

TEMP=$(getopt -o "a:hp:" -l "help" -n "$0" -- "$@")
eval set -- "$TEMP"

ADDRESS=localhost
PORT=38519

while true; do
    case $1 in
        --help|-h)
            show_help
            ;;
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

board=()
moves=
move=
active=

parse_fen() {
    local fen_string="$1"
    IFS=' ' read -r fen_board active castling en_passant halfmove fullmove <<< "$fen_string"

    local j=0
    for ((i=0; i<${#fen_board}; i++)); do
        local char="${fen_board:$i:1}"
        
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

file_to_number() {
    case $1 in
        a) echo 0;;
        b) echo 1;;
        c) echo 2;;
        d) echo 3;;
        e) echo 4;;
        f) echo 5;;
        g) echo 6;;
        h) echo 7;;
    esac
}

piece_to_char() {
    case $1 in
        [K]) echo ♔ ;;
        [Q]) echo ♕ ;;
        [R]) echo ♖ ;;
        [B]) echo ♗ ;;
        [N]) echo ♘ ;;
        [P]) echo ♙ ;;
        [k]) echo ♚ ;;
        [q]) echo ♛ ;;
        [r]) echo ♜ ;;
        [b]) echo ♝ ;;
        [n]) echo ♞ ;;
        [p]) echo ♟ ;;
        ".") echo " ";;
    esac
}

draw_square() {
    local file=$(file_to_number ${1:0:1})
    local rank=$((8 - ${1:1:1}))
    local piece=$(piece_to_char ${board[((rank * 8 + file))]})

    local bg_col=$2
    
    if [[ -z $bg_col ]]; then
        if (((rank + file) % 2 == 0)); then
            bg_col=$white_color
        else
            bg_col=$black_color
        fi
    fi

    printf "\e[s\e[%s;%sH$piece_color$bg_col$piece \e[u\e[m" $((rank + 1)) $((file * 2 + 1))
}

draw() {
    local buffer='\e[2J\e[H'
    local rank=8
    local file=8
    for piece in ${board[@]}; do
        local bg_col=$black_color
        if (((rank + file) % 2 == 0)); then
            bg_col=$white_color
        fi

        piece=$(piece_to_char $piece)

        buffer="$buffer$bg_col$piece_color$piece "
        if ((--file < 1 )); then
            file=8
            buffer="$buffer\e[m $row\n"
            ((rank--))
        fi
    done

    buffer="${buffer}A B C D E F G H\n$move"
    printf "$buffer"
}

cleanup() {
    stty sane
    printf '\e[?1049l'
    local status=0
    if [[ -n "$1" ]]; then
        echo "$1"
    fi
    if [[ -n "$2" ]]; then
        status=$2
    fi
    exit $status
}

trap cleanup SIGTERM SIGINT

printf '\e[?1049h'
stty cbreak -echo -nl

if ( ! exec 3<>/dev/tcp/$ADDRESS/$PORT ); then
    cleanup "Error connecting to the server." 1
fi
exec 3<>/dev/tcp/$ADDRESS/$PORT
while true; do
    IFS="|" read -r -t0.01 fen moves_str <&3
    if [[ -n "$fen" ]]; then
        if [[ "$fen" == "shutdown" ]]; then
            cleanup "Server shutdown." 1
        fi;
        parse_fen "$fen"
        moves=($moves_str)
        draw
    fi

    IFS= read -r -N1 -t0.01 char
    case $char in
        w) break;;
        [a-h])
            if [[ ${#move} -eq 0 ]] || [[ ${#move} -eq 2 ]]; then
                move="$move$char"
                printf $char
            fi
            if [[ $char == "b" ]] && [[ ${#move} -eq 5 ]]; then
                move="$move$char"
                printf $char
            fi
            ;;
        [1-8])
            if [[ ${#move} -eq 1 ]] || [[ ${#move} -eq 3 ]]; then
                color=$from_color
                if [[ ${#move} -eq 3 ]]; then
                    color=$to_color
                fi
                move="$move$char"
                draw_square ${move: -2} $color
                printf $char
                if [[ ${#move} -eq 2 ]]; then
                    for m in "${moves[@]}"; do
                        if [[ "$m" == "$move"* ]]; then
                            draw_square ${m:2:2} $possible_color
                        fi
                    done
                fi
            fi
            ;;
        "=")
            if [[ ${#move} -eq 4 ]]; then
                move="$move$char"
                printf $char
            fi
            ;;
        [bnrq])
            if [[ ${#move} -eq 5 ]]; then
                move="$move$char"
                printf $char
            fi
            ;;
        $'\n') echo "make_move $move" 1>&3; move=;;
        $'\177')
            if [[ ${#move} -eq 2 ]] || [[ ${#move} -eq 4 ]]; then
                if [[ ${#move} -eq 2 ]]; then
                    for m in "${moves[@]}"; do
                        if [[ "$m" == "$move"* ]]; then
                            draw_square ${m:2:2}
                        fi
                    done
                fi
                square=${move: -2}
                move=${move::-1}
                printf "\e[D \e[D"
                draw_square $square
            elif [[ -n $move ]]; then
                move=${move::-1}
                printf "\e[D \e[D"
            fi
            ;;
        *) ;;
    esac
done

cleanup
