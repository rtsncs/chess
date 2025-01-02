#!/usr/bin/perl
use strict;
use warnings;

if (scalar(@ARGV) == 0) {
    printf "invalid\n";
}

my $move = $ARGV[0];

my @board = (
"R", "B", "N", "Q", "K", "N", "B", "R",
"P", "P", "P", "P", "P", "P", "P", "P",
".", ".", ".", ".", ".", ".", ".", ".",
".", ".", ".", ".", ".", ".", ".", ".",
".", ".", ".", ".", ".", ".", ".", ".",
".", ".", ".", ".", ".", ".", ".", ".",
"p", "p", "p", "p", "p", "p", "p", "p",
"r", "b", "n", "q", "k", "n", "b", "r",
);

if (scalar(@ARGV) > 1) {
    @board = split(" ", $ARGV[1]);
}

sub notation_to_index {
    my $square = shift;
    my $col = ord(substr($square, 0, 1)) - ord("a");
    my $row = substr($square, 1, 1) - 1;
    return $row * 8 + $col;
}

sub parse_move {
    if ($move !~ /[a-h][1-8][a-h][1-8]/i) {
        print "Invalid move\n";
        exit 1;
    }
    my $from = substr($move, 0, 2);
    my $to = substr($move, 2, 2);
    return (notation_to_index($from), notation_to_index($to));
}

sub generate_w_pawn_moves {

}

sub is_legal {
    my ($from, $to) = @_;
    if ($board[$from] eq ".") {
        return 0;
    }

    my $piece = $board[$from];

    if (($piece eq "P" && $to != $from + 8) || ($piece eq "p" && $to != $from - 8)) {
        return 0;
    }
    if ($piece eq )

    return 1;
}

my @parsed_move = parse_move();
if (is_legal(@parsed_move) == 0) {
    print "Illegal move\n";
    exit 1
}
