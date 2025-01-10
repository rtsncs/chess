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

    my @move_history;
    my $self = bless({
        turn => $turn,
        halfmove => $halfmove,
        fullmove => $fullmove,
        en_passant => $en_passant eq "-" ? 64 : notation_to_index($en_passant),
        castling => $castling,
        pawns => 0,
        rooks => 0,
        bishops => 0,
        knights => 0,
        queens => 0,
        kings => 0,
        whites => 0,
        blacks => 0,
        move_history => \@move_history,
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
        $self->{turn},
        $self->{castling},
        $self->{en_passant} == 64 ? "-" : index_to_notation($self->{en_passant}),
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
    return ($self->{turn} eq 'b' ? $self->{blacks} : $self->{whites});
}

sub enemy_pieces {
    my $self = shift;
    return ($self->{turn} eq 'b' ? $self->{whites} : $self->{blacks});
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

# funkcja generująca ruchy pionów
sub pawn_moves {
    my $self = shift;
    my @moves;
    my $pawns = $self->{pawns} & $self->allied_pieces();

    # ruchy pojedyncze
    my $shift = $self->{turn} eq 'w' ? 8 : -8;
    my $bit_moves = ($pawns << $shift) & ~$self->all_pieces();
    for my $i (0..63) {
        my $mask = 1 << $i;
        if ($bit_moves & $mask) {
            if (($self->{turn} eq 'w' && $i >= 56) || $self->{turn} eq 'b' && $i < 8) {
                for my $j (1..4) {
                    push(@moves, { from => $i - $shift, to => $i, promotion => $j});
                }
            } else {
                push(@moves, { from => $i - $shift, to => $i, promotion => 0});
            }
        }
    }

    # ruchy podwójne
    my $double_shift = $self->{turn} eq 'w' ? 16 : -16;
    my $start_rank = $self->{turn} eq 'w' ? RANK_2 : RANK_7;
    my $block_rank = $self->{turn} eq 'w' ? RANK_3 : RANK_6;
    $bit_moves = ($pawns & $start_rank) << $double_shift;
    $bit_moves &= ~$self->all_pieces();
    $bit_moves &= ~($self->all_pieces() & $block_rank) << $shift;
    for my $i (0..63) {
        my $mask = 1 << $i;
        if ($bit_moves & $mask) {
            push(@moves, { from => $i - $double_shift, to => $i, promotion => 0, en_passant => $i - $shift });
        }
    }

    # bicia
    my @directions = $self->{turn} eq 'w' ? (
        { shift => 9, mask => ~(RANK_8 | FILE_A) },
        { shift => 7, mask => ~(RANK_8 | FILE_H) },
    ) : (
        { shift => -7, mask => ~(RANK_1 | FILE_A) },
        { shift => -9, mask => ~(RANK_1 | FILE_H) },
    );
    for my $dir (@directions) {
        $bit_moves = (($pawns & $dir->{mask}) << $dir->{shift}) & ($self->enemy_pieces() | (1 << $self->{en_passant}));
        for my $i (0..63) {
            my $mask = 1 << $i;
            if ($bit_moves & $mask) {
                if (($self->{turn} eq 'w' && $i >= 56) || $self->{turn} eq 'b' && $i < 8) {
                    for my $j (1..4) {
                        push(@moves, { from => $i - $dir->{shift}, to => $i, promotion => $j});
                    }
                } else {
                    push(@moves, { from => $i - $dir->{shift}, to => $i, promotion => 0});
                }
            }
        }
    }

    return @moves;
}

# funkcja generująca ruchy królów
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
            push(@moves, { from => $from, to => $i, promotion => 0});
        }
    }

    return @moves;
}

# funkcja generująca ruchy skoczków
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
                    push(@moves, { from => $i, to => $j, promotion => 0});
                }
            }
        }
    }
    return @moves;
}

# funkcja generująca ruchy gońców, wież i hetmanów
sub sliding_moves {
    my $self = shift;
    my @moves;

    my $ortho_pieces = ($self->{rooks} | $self->{queens}) & $self->allied_pieces();
    my $diag_pieces = ($self->{bishops} | $self->{queens}) & $self->allied_pieces();

    my @directions = (
        { shift => 8, mask => ~RANK_8, pieces => $ortho_pieces }, # góra
        { shift => -8, mask => ~RANK_1, pieces => $ortho_pieces }, # dół
        { shift => 1, mask => ~FILE_A, pieces => $ortho_pieces }, # lewo
        { shift => -1, mask => ~FILE_H, pieces => $ortho_pieces }, # prawo
        { shift => 9, mask => ~(RANK_8 | FILE_A), pieces => $diag_pieces }, # lewo góra
        { shift => 7, mask => ~(RANK_8 | FILE_H), pieces => $diag_pieces }, # prawo góra
        { shift => -7, mask => ~(RANK_1 | FILE_A), pieces => $diag_pieces }, # lewo dół
        { shift => -9, mask => ~(RANK_1 | FILE_H), pieces => $diag_pieces }, # prawo dół
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
                    push(@moves, { from => $i - $distance, to => $i, promotion => 0});
                }
            }
            $bit_moves &= ~$self->enemy_pieces();
        }
    }
    return @moves;
}

sub pseudo_legal_moves() {
    my $self = shift;
    my @moves = ($self->pawn_moves(), $self->king_moves(), $self->knight_moves(), $self->sliding_moves());
    return @moves;
}

sub generate_moves {
    my $self = shift;
    my @moves = $self->pseudo_legal_moves();
    my @legal_moves;

    for my $move (@moves) {
        $self->make_move($move);
        if (!$self->is_square_attacked($self->{kings} & $self->enemy_pieces())) {
            push(@legal_moves, $move);
        }
        $self->undo_move();
    }

    $self->{moves} = \@legal_moves;
}

sub is_square_attacked {
    my $self = shift;
    my $square = shift;

    for my $i (0..63) {
        my $mask = 1 << $i;
        if ($square & $mask) {
            $square = $i;
            last;
        }
    }

    my @moves = $self->pseudo_legal_moves();
    for my $move (@moves) {
        if ($move->{to} == $square) {
            return 1;
        }
    }
    
    return 0;
}

sub parse_move {
    my $move = shift;
    if ($move !~ /[a-h][1-8][a-h][1-8]/i) {
        return 0;
    }
    my $from = substr($move, 0, 2);
    my $to = substr($move, 2, 2);
    return { from => notation_to_index($from), to => notation_to_index($to), promotion => 0};
}

sub move_to_string {
    my $move = shift;
    my $promotion_string = "";
    return index_to_notation($move->{from}) . index_to_notation($move->{to}) . $promotion_string;
}

sub parse_make_move {
    my $self = shift;
    my $move = parse_move(shift);

    foreach my $m (@{$self->{moves}}) {
        if ($m->{from} == $move->{from} && $m->{to} == $move->{to} && $m->{promotion} == $move->{promotion}) {
            $self->make_move($m);
            $self->generate_moves();
            return 1;
        }
    }
    return 0;
}

sub make_move {
    my ($self, $move) = @_;
    my $from_mask = 1 << $move->{from};
    my $to_mask = 1 << $move->{to};

    $move->{castling} = $self->{castling};
    $move->{halfmove} = $self->{halfmove};
    $move->{captured_piece} = "";

    $self->{halfmove}++;

    # bicie
    for my $piece_type ("pawns", "rooks", "bishops", "knights", "queens", "kings") {
        if ($self->{$piece_type} & $to_mask) {
            $self->{$piece_type} &= ~$to_mask;
            $self->{halfmove} = 0;
            $move->{captured_piece} = $piece_type;
            last;
        }
    }

    # ruch bierką
    for my $piece_type ("pawns", "rooks", "bishops", "knights", "queens", "kings") {
        if ($self->{$piece_type} & $from_mask) {
            $self->{$piece_type} &= ~$from_mask;
            $self->{$piece_type} |= $to_mask;

            if ($piece_type eq "pawns") {
                $self->{halfmove} = 0;

                if ($move->{to} == $self->{en_passant}) {
                    my $shift = $self->{turn} eq 'w' ? -8 : 8;
                    my $captured_square = 1 << ($move->{to} + $shift);
                    $self->{pawns} &= ~($captured_square);
                    $self->{whites} &= ~($captured_square);
                    $self->{blacks} &= ~($captured_square);
                }
            }
            last;
        }
    }
    $self->{whites} &= ~($from_mask | $to_mask);
    $self->{blacks} &= ~($from_mask | $to_mask);

    if ($self->{turn} eq 'b') {
        $self->{turn} = 'w'; 
        $self->{blacks} |= $to_mask;
        $self->{fullmove}++;
    } else {
        $self->{turn} = 'b'; 
        $self->{whites} |= $to_mask;
    }

    my $prev_en_passant = $self->{en_passant};
    if (defined $move->{en_passant}) {
        $self->{en_passant} = $move->{en_passant};
    } else {
        $self->{en_passant} = 64;
    }
    $move->{en_passant} = $prev_en_passant;
    push(@{$self->{move_history}}, $move);
}

sub undo_move {
    my $self = shift;
    my $move = pop(@{$self->{move_history}});
    my $from_mask = 1 << $move->{from};
    my $to_mask = 1 << $move->{to};

    $self->{castling} = $move->{castling};
    $self->{halfmove} = $move->{halfmove};
    my $temp = $self->{en_passant};
    $self->{en_passant} = $move->{en_passant};
    $move->{en_passant} = $temp;

    for my $piece_type ("pawns", "rooks", "bishops", "knights", "queens", "kings") {
        if ($self->{$piece_type} & $to_mask) {
            $self->{$piece_type} &= ~$to_mask;
            $self->{$piece_type} |= $from_mask;
        }
        if ($move->{captured_piece} eq $piece_type) {
            $self->{$piece_type} |= $to_mask;
        }
    }

    if ($self->{en_passant} == $move->{to}) {
        my $shift = $self->{turn} eq 'w' ? -8 : 8;
        my $captured_square = 1 << ($move->{to} - $shift);
        $self->{pawns} |= $captured_square;
        if ($self->{turn} eq 'w') {
            $self->{whites} |= $captured_square;
        } else {
            $self->{blacks} |= $captured_square;
        }
    }

    $self->{whites} &= ~($from_mask | $to_mask);
    $self->{blacks} &= ~($from_mask | $to_mask);

    if ($self->{turn} eq 'b') {
        $self->{turn} = 'w'; 
        $self->{whites} |= $from_mask;
        if (!$move->{captured_piece} eq "") {
            $self->{blacks} |= $to_mask;
        }
    } else {
        $self->{turn} = 'b'; 
        $self->{blacks} |= $from_mask;
        if (!$move->{captured_piece} eq "") {
            $self->{whites} |= $to_mask;
        }
        $self->{fullmove}--;
    }
}

sub get_move_strings {
    my $self = shift;
    my @moves;
    foreach my $move (@{$self->{moves}}) {
        push(@moves, move_to_string($move));
    }
    return @moves;
}

sub perft {
    my $self = shift;
    my $depth = shift;
    if ($depth == 0) { 
        return 1;
    }
    my @moves = $self->pseudo_legal_moves();

    my $move_count = 0;
    foreach my $move (@moves) {
        $self->make_move($move);
        if (!$self->is_square_attacked($self->{kings} & $self->enemy_pieces())) {
            $move_count += $self->perft($depth - 1);
        }
        $self->undo_move();
    }
    return $move_count;
}

sub divided_perft {
    my $self = shift;
    my $depth = shift;

    my $move_count = 0;
    foreach my $move (@{$self->{moves}}) {
        $self->make_move($move);
        my $result = $self->perft($depth - 1);
        $move_count += $result;
        print move_to_string($move) . ": $result\n";
        $self->undo_move();
    }
    print "Total: $move_count ";
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
