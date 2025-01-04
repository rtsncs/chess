#!/bin/bash

stty cbreak -echo -nl

board=()
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
}

parse_fen "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
# parse_fen "rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2"
draw
compose_fen

move=

while true; do
    char=$(dd bs=1 count=1 2>/dev/null)

    case $char in
        q) break;;
        *) ;;
    esac
done

stty sane
