package Chess;
use strict;
use warnings;
our $VERSION = "1.0";

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

sub from_fen {
    my $class = shift;
    my ($fen_board, $turn, $castling, $en_passant, $halfmove, $fullmove) = split / /, shift;

    my $self = bless({
        turn => $turn eq 'w' ? 0 : 1,
        halfmove => $halfmove,
        fullmove => $fullmove,
        en_passant => $en_passant eq "-" ? -1 : notation_to_index($en_passant),
        castling => -1,
        pawns => 0,
        rooks => 0,
        bishops => 0,
        knights => 0,
        queens => 0,
        kings => 0,
        whites => 0,
        blacks => 0,
    }, $class);

    my $mask = 1 << 63;
    foreach my $char (split //, $fen_board) {
        if ($char =~ /[1-8]/) {
            $mask >>= $char;
        } elsif ($char =~ /\//) {
            next;
        } else {
            if ($char eq uc $char) {
                $self->{whites} |= $mask;
            } else {
                $self->{blacks} |= $mask;
            }
            if ($char =~ /p/i) {
                $self->{pawns} |= $mask;
            }
            elsif ($char =~ /r/i) {
                $self->{rooks} |= $mask;
            }
            elsif ($char =~ /b/i) {
                $self->{bishops} |= $mask;
            }
            elsif ($char =~ /n/i) {
                $self->{knights} |= $mask;
            }
            elsif ($char =~ /q/i) {
                $self->{queens} |= $mask;
            }
            elsif ($char =~ /k/i) {
                $self->{kings} |= $mask;
            }
            $mask >>= 1;
        }
    }

    $self->generate_moves();
    return $self;
}

sub to_fen {
    my $self = shift;
    my $fen_board = "";

    my $all_pieces = $self->all_pieces();
    my $empty = 0;
    for (my $i = 63; $i >= 0; $i--) {
        my $mask = 1 << $i;
        if ($i != 63 && $i % 8 == 7) {
            if ($empty) {
                $fen_board .= $empty;
                $empty = 0;
            }
            $fen_board .= "/";
        }
        if ($all_pieces & $mask) {
            if ($empty) {
                $fen_board .= $empty;
                $empty = 0;
            }
            my $char = "";
            if ($self->{pawns} & $mask) {
                $char = "p";
            } elsif ($self->{rooks} & $mask) {
                $char = "r";
            } elsif ($self->{bishops} & $mask) {
                $char = "b";
            } elsif ($self->{knights} & $mask) {
                $char = "n";
            } elsif ($self->{queens} & $mask) {
                $char = "q";
            } elsif ($self->{kings} & $mask) {
                $char = "k";
            }
            if ($self->{whites} & $mask) {
                $char = uc $char;
            }
            $fen_board .= $char;
        } else {
            $empty++;
        }
    }

    return join(" ",
        $fen_board,
        $self->{turn} ? "b" : "w",
        $self->{castling} == -1 ? "-" : "KQkq",
        $self->{en_passant} == -1 ? "-" : index_to_notation($self->{en_passant}),
        $self->{halfmove},
        $self->{fullmove},
    );
}

sub all_pieces {
    my $self = shift;
    return $self->{whites} | $self->{blacks};
}

sub allied_pieces {
    my $self = shift;
    return ($self->{turn} ? $self->{blacks} : $self->{whites});
}

sub enemy_pieces {
    my $self = shift;
    return ($self->{turn} ? $self->{whites} : $self->{blacks});
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
sub pawn_moves {
    my $self = shift;
    my $bit_moves;
    my @moves;

    my $pawns = $self->{pawns} & $self->allied_pieces();
    if (!$self->{turn}) {
        $bit_moves = ($pawns << 8) & ~$self->all_pieces();
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
        $bit_moves = ($pawns >> 8) & ~$self->all_pieces();
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

    if (!$self->{turn}) {
        $bit_moves = ($pawns & RANK_2) << 16;
        $bit_moves &= ~$self->all_pieces();
        $bit_moves &= ~($self->all_pieces() & RANK_3) << 8;
        for my $i (0..63) {
            my $mask = 1 << $i;
            if ($bit_moves & $mask) {
                push(@moves, 0 | (($i - 16) << 4) | ($i << 12));
            }
        }
    } else {
        $bit_moves = ($pawns & RANK_7) >> 16;
        $bit_moves &= ~$self->all_pieces();
        $bit_moves &= ~($self->all_pieces() & RANK_6) >> 8;
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
    my $self = shift;
    my $bit_moves;
    my @moves;

    my $king = $self->{kings} & $self->allied_pieces();
    $bit_moves = ($king & ~RANK_1) >> 8;
    $bit_moves |= ($king & ~RANK_8) << 8;
    $bit_moves |= ($king & ~FILE_A) << 1;
    $bit_moves |= ($king & ~FILE_H) >> 1;
    $bit_moves |= ($king & ~(RANK_1 | FILE_A)) >> 7;
    $bit_moves |= ($king & ~(RANK_1 | FILE_H)) >> 9;
    $bit_moves |= ($king & ~(RANK_8 | FILE_A)) << 9;
    $bit_moves |= ($king & ~(RANK_8 | FILE_H)) << 7;

    $bit_moves &= ~$self->allied_pieces();

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

sub knight_moves() {
    my $self = shift;
    my $bit_moves;
    my @moves;

    my $knights = $self->{knights} & $self->allied_pieces();

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

            $bit_moves &= ~$self->allied_pieces();

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

sub sliding_moves {
    my $self = shift;
    my @moves;

    my $ortho_pieces = ($self->{rooks} | $self->{queens}) & $self->allied_pieces();
    my $diag_pieces = ($self->{bishops} | $self->{queens}) & $self->allied_pieces();

    my @directions = (
        { shift => 8, mask => ~RANK_8, pieces => $ortho_pieces },
        { shift => -8, mask => ~RANK_1, pieces => $ortho_pieces },
        { shift => 1, mask => ~FILE_A, pieces => $ortho_pieces },
        { shift => -1, mask => ~FILE_H, pieces => $ortho_pieces },
        { shift => 9, mask => ~(RANK_8 | FILE_A), pieces => $diag_pieces },
        { shift => 7, mask => ~(RANK_8 | FILE_H), pieces => $diag_pieces },
        { shift => -7, mask => ~(RANK_1 | FILE_A), pieces => $diag_pieces },
        { shift => -9, mask => ~(RANK_1 | FILE_H), pieces => $diag_pieces },
    );
    
    foreach my $dir (@directions) {
        my $bit_moves = $dir->{pieces};
        my $distance = 0;
        while ($bit_moves) {
            $distance += $dir->{shift};
            $bit_moves &= $dir->{mask};
            $bit_moves <<= $dir->{shift};
            $bit_moves &= ~$self->allied_pieces();
            for my $i (0..63) {
                my $mask = 1 << $i;
                if ($bit_moves & $mask) {
                    push(@moves, 0 | (($i - $distance) << 4) | ($i << 12));
                }
            }
            $bit_moves &= ~$self->enemy_pieces();
        }
    }
    return @moves;
}

sub generate_moves {
    my $self = shift;
    my @moves = ($self->pawn_moves(), $self->king_moves(), $self->knight_moves(), $self->sliding_moves());
    $self->{moves} = \@moves;
}

sub parse_move {
    my $move = shift;
    if ($move !~ /[a-h][1-8][a-h][1-8]/i) {
        return 0;
    }
    my $from = substr($move, 0, 2);
    my $to = substr($move, 2, 2);
    return 0 | (notation_to_index($from) << 4) | (notation_to_index($to) << 12);
}

sub move_to_string {
    my $move = $_;
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

sub make_move {
    my $self = shift;
    my $move = parse_move(shift);
    if (grep(/^$move$/, @{$self->{moves}})) {
        print "$move is valid\n";
        my $from = ($move >> 4) & 63;
        my $to = ($move >> 12) & 63;
        my $promotion = $move & 15;

        my $from_mask = 1 << $from;
        my $to_mask = 1 << $to;

        $self->{halfmove}++;

        for my $pieces ($self->{pawns}, $self->{rooks}, $self->{bishops}, $self->{knights}, $self->{queens}, $self->{kings}) {
            if ($pieces & $to_mask) {
                $pieces &= ~$to_mask;
                $self->{halfmove} = 0;
                last;
            }
        }
        for my $pieces ($self->{pawns}, $self->{rooks}, $self->{bishops}, $self->{knights}, $self->{queens}, $self->{kings}) {
            if ($pieces & $from_mask) {
                if ($pieces == $self->{pawns}) {
                    $self->{halfmove} = 0;
                }

                $pieces &= ~$from_mask;
                $pieces |= $to_mask;
                last;
            }
        }
        $self->{whites} &= ~($from_mask | $to_mask);
        $self->{blacks} &= ~($from_mask | $to_mask);

        if ($self->{turn}) {
            $self->{blacks} |= $to_mask;
            $self->{fullmove}++;
        } else {
            $self->{whites} |= $to_mask;
        }

        $self->{turn} = !$self->{turn};
        $self->generate_moves();

        return 1;
    }
    return 0;
}

sub get_moves {
    my $self = shift;
    return map(move_to_string, @{$self->{moves}});
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

1;
