#!/usr/bin/perl
use strict;
use warnings;

use constant {
        RANK_1 => 0xFF << (8 * 0),
        RANK_2 => 0xFF << (8 * 1),
        RANK_3 => 0xFF << (8 * 2),
        RANK_4 => 0xFF << (8 * 3),
        RANK_5 => 0xFF << (8 * 4),
        RANK_6 => 0xFF << (8 * 5),
        RANK_7 => 0xFF << (8 * 6),
        RANK_8 => 0xFF << (8 * 7),
        FILE_A => 72340172838076673 << 7,
        FILE_B => 72340172838076673 << 6,
        FILE_C => 72340172838076673 << 5,
        FILE_D => 72340172838076673 << 4,
        FILE_E => 72340172838076673 << 3,
        FILE_F => 72340172838076673 << 2,
        FILE_G => 72340172838076673 << 1,
        FILE_H => 72340172838076673,
};

my $board = {};

sub parse_fen {
    my ($fen) = @_;
    my ($fen_board, $turn, $castling, $en_passant, $halfmove, $fullmove) = split / /, $fen;

    $board = {
        turn => $turn eq 'w' ? 0 : 1,
        halfmove => $halfmove,
        fullmove => $fullmove,
        en_passant => $en_passant eq "-" ? -1 : notation_to_index($en_passant),
        castling => -1,
        pieces => {
            P => 0,
            R => 0,
            B => 0,
            N => 0,
            Q => 0,
            K => 0,
            p => 0,
            r => 0,
            b => 0,
            n => 0,
            q => 0,
            k => 0,
        }
    };

    my $mask = 1 << 63;
    foreach my $char (split //, $fen_board) {
        if ($char =~ /[rbnqkp]/i) {
            $board->{pieces}->{$char} |= $mask;
            $mask >>= 1;
        } elsif ($char =~ /[1-8]/) {
            $mask >>= $char;
        }
    }
}

sub white_pieces {
    return $board->{pieces}->{P} | $board->{pieces}->{R} | $board->{pieces}->{B}
        | $board->{pieces}->{N} | $board->{pieces}->{Q} | $board->{pieces}->{K};
}

sub black_pieces {
    return $board->{pieces}->{p} | $board->{pieces}->{r} | $board->{pieces}->{b}
        | $board->{pieces}->{n} | $board->{pieces}->{q} | $board->{pieces}->{k};
}

sub all_pieces {
    return white_pieces() | black_pieces();
}

sub notation_to_index {
    my $square = shift;
    my $col = ord("h") - ord(substr($square, 0, 1));
    my $row = substr($square, 1, 1) - 1;
    return $row * 8 + $col;
}

sub index_to_notation {
    my $square = shift;
    my $col = $square % 8;
    my $row = int($square / 8) + 1;
    return chr(ord("h") - $col) . $row;
}

#sub parse_move {
#    my $move = 
#    if ($move !~ /[a-h][1-8][a-h][1-8]/i) {
#        print "Invalid move\n";
#        exit 1;
#    }
#    my $from = substr($move, 0, 2);
#    my $to = substr($move, 2, 2);
#    return (notation_to_index($from), notation_to_index($to));
#}

sub move_to_string {
    my $move = shift;
    my $from = ($move >> 4) & 63;
    my $to = ($move >> 12) & 63;
    my $promotion = $move & 15;
    my $promotion_string = "";
    if ($promotion eq 1) {
        $promotion_string = "=r"
    } elsif ($promotion eq 2) {
        $promotion_string = "=n"
    } elsif ($promotion eq 3) {
        $promotion_string = "=b"
    } elsif ($promotion eq 4) {
        $promotion_string = "=q"
    }
    return index_to_notation($from) . index_to_notation($to) . $promotion_string;
}

sub pawn_moves {
    my $bit_moves;
    my @moves;

    if (!$board->{turn}) {
        $bit_moves = ($board->{pieces}->{P} << 8) & (~all_pieces());
        for my $i (0..63) {
            my $mask = 1 << $i;
            if ($bit_moves & $mask) {
                if ($i >= 56) {
                    for my $j (1..4) {
                        push(@moves, $j | (($i - 8) << 4) | ($i << 12));
                    }
                } else {
                    push(@moves, 0 | (($i - 8) << 4) | ($i << 12));
                }
            }
        }
    } else {
        $bit_moves = ($board->{pieces}->{p} >> 8) & (~all_pieces());
        for my $i (0..63) {
            my $mask = 1 << $i;
            if ($bit_moves & $mask) {
                if ($i < 8) {
                    for my $j (1..4) {
                        push(@moves, $j | (($i + 8) << 4) | ($i << 12));
                    }
                } else {
                    push(@moves, 0 | (($i + 8) << 4) | ($i << 12));
                }
            }
        }
    }

    if (!$board->{turn}) {
        $bit_moves = ($board->{pieces}->{P} & RANK_2) << 16;
        $bit_moves &= ~all_pieces();
        $bit_moves &= ~(all_pieces() & RANK_3) << 8;
        for my $i (0..63) {
            my $mask = 1 << $i;
            if ($bit_moves & $mask) {
                push(@moves, 0 | (($i - 16) << 4) | ($i << 12));
            }
        }
    } else {
        $bit_moves = ($board->{pieces}->{p} & RANK_7) >> 16;
        $bit_moves &= ~all_pieces();
        $bit_moves &= ~(all_pieces() & RANK_6) >> 8;
        for my $i (0..63) {
            my $mask = 1 << $i;
            if ($bit_moves & $mask) {
                push(@moves, 0 | (($i + 16) << 4) | ($i << 12));
            }
        }
    }
    return @moves;
}

sub king_moves {
    my $bit_moves;
    my @moves;

    my $king = $board->{turn} ? $board->{pieces}->{k} : $board->{pieces}->{K};
    $bit_moves = ($king & ~RANK_1) >> 8;
    $bit_moves |= ($king & ~RANK_8) << 8;
    $bit_moves |= ($king & ~FILE_A) << 1;
    $bit_moves |= ($king & ~FILE_H) >> 1;
    $bit_moves |= ($king & ~(RANK_1 | FILE_A)) >> 7;
    $bit_moves |= ($king & ~(RANK_1 | FILE_H)) >> 9;
    $bit_moves |= ($king & ~(RANK_8 | FILE_A)) << 9;
    $bit_moves |= ($king & ~(RANK_8 | FILE_H)) << 7;

    $bit_moves &= $board->{turn} ? ~black_pieces() : ~white_pieces();

    my $from;

    for my $i (0..63) {
        my $mask = 1 << $i;
        if ($king & $mask) {
            $from = $i;
            last;
        }
    }

    for my $i (0..63) {
        my $mask = 1 << $i;
        if ($bit_moves & $mask) {
            push(@moves, 0 | ($from << 4) | ($i << 12));
        }
    }

    return @moves;
}

# northwest    north   northeast
#noWe         nort         noEa
#        +9    +8    +7
#            \  |  /
#west    +1 <-  0 -> -1    east
#            /  |  \
#        -7    -8    -9
#soWe         sout         soEa
#southwest    south   southeast

sub knight_moves() {
    my $bit_moves;
    my @moves;

    my $knights = $board->{turn} ? $board->{pieces}->{n} : $board->{pieces}->{N};

    for my $i (0..63) {
        my $mask = 1 << $i;
        if ($knights & $mask) {
            my $current_knight = $mask;
            $bit_moves = ($current_knight & ~(RANK_8 | FILE_A | FILE_B)) << 10;
            $bit_moves |= ($current_knight & ~(RANK_8 | FILE_G | FILE_H)) << 6;
            $bit_moves |= ($current_knight & ~(RANK_1 | FILE_A | FILE_B)) >> 6;
            $bit_moves |= ($current_knight & ~(RANK_1 | FILE_G | FILE_H)) >> 10;
            $bit_moves |= ($current_knight & ~(RANK_8 | RANK_7 | FILE_A)) << 17;
            $bit_moves |= ($current_knight & ~(RANK_8 | RANK_7 | FILE_H)) << 15;
            $bit_moves |= ($current_knight & ~(RANK_1 | RANK_2 | FILE_A)) >> 15;
            $bit_moves |= ($current_knight & ~(RANK_1 | RANK_2 | FILE_H)) >> 17;

            $bit_moves &= $board->{turn} ? ~black_pieces() : ~white_pieces();

            for my $j (0..63) {
                my $move_mask = 1 << $j;
                if ($bit_moves & $move_mask) {
                    push(@moves, 0 | ($i << 4) | ($j << 12));
                }
            }
        }
    }
    return @moves;
}

sub moves {
    return (pawn_moves(), king_moves(), knight_moves());
}

sub print_board {
    my $board = shift;
    for my $i (0..63) {
        print $board >> (63 - $i) & 1;
        if ($i % 8 == 7) {
            print "\n";
        }
    }
    print "\n";
}

parse_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");

my @moves = moves();
print scalar @moves, "\n";
foreach my $move (@moves) {
    print move_to_string($move), "\n";
}
