#!/bin/bash

stty cbreak -echo -nl

board=( \
r b n q k n b r \
p p p p p p p p \
. . . . . . . . \
. . . . . . . . \
. . . . . . . . \
. . . . . . . . \
P P P P P P P P \
R B N Q K N B R \
)

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

move=


while true; do
    char=$(dd bs=1 count=1 2>/dev/null)

    case $char in
        q) break;;
        *) ;;
    esac
done

stty sane
