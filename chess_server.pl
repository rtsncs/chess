#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;

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

foreach my $arg (@ARGV) {

}

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
        pawns => 0,
        rooks => 0,
        bishops => 0,
        knights => 0,
        queens => 0,
        kings => 0,
        whites => 0,
        blacks => 0,
    };

    my $mask = 1 << 63;
    foreach my $char (split //, $fen_board) {
        if ($char =~ /[1-8]/) {
            $mask >>= $char;
        } elsif ($char =~ /\//) {
            next;
        } else {
            if ($char eq uc $char) {
                $board->{whites} |= $mask;
            } else {
                $board->{blacks} |= $mask;
            }
            if ($char =~ /p/i) {
                $board->{pawns} |= $mask;
            }
            elsif ($char =~ /r/i) {
                $board->{rooks} |= $mask;
            }
            elsif ($char =~ /b/i) {
                $board->{bishops} |= $mask;
            }
            elsif ($char =~ /n/i) {
                $board->{knights} |= $mask;
            }
            elsif ($char =~ /q/i) {
                $board->{queens} |= $mask;
            }
            elsif ($char =~ /k/i) {
                $board->{kings} |= $mask;
            }
            $mask >>= 1;
        }
    }
}

sub compose_fen {
    my $fen_board = "";

    my $all_pieces = all_pieces();
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
            if ($board->{pawns} & $mask) {
                $char = "p";
            } elsif ($board->{rooks} & $mask) {
                $char = "r";
            } elsif ($board->{bishops} & $mask) {
                $char = "b";
            } elsif ($board->{knights} & $mask) {
                $char = "n";
            } elsif ($board->{queens} & $mask) {
                $char = "q";
            } elsif ($board->{kings} & $mask) {
                $char = "k";
            }
            if ($board->{whites} & $mask) {
                $char = uc $char;
            }
            $fen_board .= $char;
        } else {
            $empty++;
        }
    }

    return join(" ",
        $fen_board,
        $board->{turn} ? "b" : "w",
        $board->{castling} == -1 ? "-" : "KQkq",
        $board->{en_passant} == -1 ? "-" : index_to_notation($board->{en_passant}),
        $board->{halfmove},
        $board->{fullmove},
    );
}

sub all_pieces {
    return $board->{whites} | $board->{blacks};
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

sub pawn_moves {
    my $bit_moves;
    my @moves;

    my $pawns = $board->{pawns} & ($board->{turn} ? $board->{blacks} : $board->{whites});
    if (!$board->{turn}) {
        $bit_moves = ($pawns << 8) & ~all_pieces();
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
        $bit_moves = ($pawns >> 8) & ~all_pieces();
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
        $bit_moves = ($pawns & RANK_2) << 16;
        $bit_moves &= ~all_pieces();
        $bit_moves &= ~(all_pieces() & RANK_3) << 8;
        for my $i (0..63) {
            my $mask = 1 << $i;
            if ($bit_moves & $mask) {
                push(@moves, 0 | (($i - 16) << 4) | ($i << 12));
            }
        }
    } else {
        $bit_moves = ($pawns & RANK_7) >> 16;
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

    my $king = $board->{kings} & ($board->{turn} ? $board->{blacks} : $board->{whites});
    $bit_moves = ($king & ~RANK_1) >> 8;
    $bit_moves |= ($king & ~RANK_8) << 8;
    $bit_moves |= ($king & ~FILE_A) << 1;
    $bit_moves |= ($king & ~FILE_H) >> 1;
    $bit_moves |= ($king & ~(RANK_1 | FILE_A)) >> 7;
    $bit_moves |= ($king & ~(RANK_1 | FILE_H)) >> 9;
    $bit_moves |= ($king & ~(RANK_8 | FILE_A)) << 9;
    $bit_moves |= ($king & ~(RANK_8 | FILE_H)) << 7;

    $bit_moves &= $board->{turn} ? ~$board->{blacks} : ~$board->{whites};

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

    my $knights = $board->{knights} & ($board->{turn} ? $board->{blacks} : $board->{whites});

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

            $bit_moves &= $board->{turn} ? ~$board->{blacks} : ~$board->{whites};

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
my @moves;
my $socket;
my $select;

sub make_move {
    my $move = parse_move(shift);
    if (grep(/^$move$/, @moves)) {
        print "$move is valid\n";
        my $from = ($move >> 4) & 63;
        my $to = ($move >> 12) & 63;
        my $promotion = $move & 15;

        my $from_mask = 1 << $from;
        my $to_mask = 1 << $to;

        for my $pieces ($board->{pawns}, $board->{rooks}, $board->{bishops}, $board->{knights}, $board->{queens}, $board->{kings}) {
            if ($pieces & $to_mask) {
                $pieces &= ~$to_mask;
            }
        }
        for my $pieces ($board->{pawns}, $board->{rooks}, $board->{bishops}, $board->{knights}, $board->{queens}, $board->{kings}) {
            if ($pieces & $from_mask) {
                $pieces &= ~$from_mask;
                $pieces |= $to_mask;
            }
        }
        $board->{whites} &= ~($from_mask | $to_mask);
        $board->{blacks} &= ~($from_mask | $to_mask);

        if ($board->{turn}) {
            $board->{blacks} |= $to_mask;
        } else {
            $board->{whites} |= $to_mask;
        }

        $board->{turn} = !$board->{turn};
        @moves = moves();

        my $update = compose_fen() . "|" . join(" ", map(move_to_string, @moves)) . "\n";

        foreach my $client ($select->can_write(1)) {
            if ($client != $socket) {
                $client->send($update);
            }
        }
    }
}

parse_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");

@moves = moves();

$socket = new IO::Socket::INET(
    LocalHost => '0.0.0.0',
    LocalPort => '38519',
    Proto => 'tcp',
    Listen => 5,
    Reuse => 1,
    Blocking => 0,
) or die "cannot create socket: $!";
print "listening on port 38519\n";

$select = new IO::Select;
$select->add($socket);

while (1) {
    foreach my $client ($select->can_read(1)) {
        if ($client == $socket) {
            $client = $socket->accept();
            $select->add($client);
            #setnonblock $client;
            my $update = compose_fen() . "|" . join(" ", map(move_to_string, @moves)) . "\n";
            $client->send($update);
        } else {
            my $count = $client->recv(my $data, 1024);
            unless (defined($count) && length $data) {
                $select->remove($client);
                close $client;
                print("client disconnected\n");
                next;
            }
            print("received: $data\n");
            if ($data =~ "get_moves") {
                foreach my $move (@moves) {
                    $client->send(move_to_string($move) . "\n");
                }
            } elsif ($data =~ "make_move") {
                my @data = split / /, $data;
                make_move($data[1]);
            }
        }
    }
}
