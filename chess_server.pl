#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use Getopt::Long;
use Pod::Usage;

use lib '.';
use Chess;

my $fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
my $perft = 0;
my $undo = 0;
my $help = 0;
my $port = 38519;

GetOptions('port=i' => \$port, 'fen=s' => \$fen, 'perft=i' => \$perft, 'undo' => \$undo, 'help' => \$help) or pod2usage(2);
pod2usage(-exitval => 1, -verbose => 2) if $help;

my $chess = Chess->from_fen($fen);

if ($perft > 0) {
    print $chess->divided_perft($perft) . "\n";
    exit 0;
}


my $socket = new IO::Socket::INET(
    LocalHost => '0.0.0.0',
    LocalPort => $port,
    Proto => 'tcp',
    Listen => 5,
    Reuse => 1,
    Blocking => 0,
) or die "cannot create socket: $!";
print "listening on port $port\n";

my $select = new IO::Select;
$select->add($socket);

use sigtrap 'handler' => \&signal_handler, 'normal-signals';
sub signal_handler {
    foreach my $client ($select->can_write(1)) {
        if ($client != $socket) {
            $client->send("shutdown");
        }
    }
    exit;
}

sub send_update {
    my $client = shift;
    my $update = $chess->to_fen() . "|" . join(" ", $chess->get_move_strings()) . "\n";
    $client->send($update);
}

sub broadcast_update {
    my $update = $chess->to_fen() . "|" . join(" ", $chess->get_move_strings()) . "\n";
    foreach my $client ($select->can_write(1)) {
        if ($client != $socket) {
            $client->send($update);
        }
    }
}

while (1) {
    foreach my $client ($select->can_read(1)) {
        if ($client == $socket) {
            $client = $socket->accept();
            $select->add($client);
            print("client connected\n");
            send_update($client);
        } else {
            my $count = $client->recv(my $data, 1024);
            unless (defined($count) && length $data) {
                $select->remove($client);
                close $client;
                print("client disconnected\n");
                next;
            }
            print("received: $data");
            if ($data =~ "^make_move") {
                my @data = split / /, $data;
                if ($chess->parse_make_move($data[1])) {
                    broadcast_update();
                } else {
                    send_update($client);
                }
            } elsif ($data =~ "^undo" && $undo) {
                $chess->undo_move();
                $chess->generate_moves();
                broadcast_update();
            }
        }
    }
}

__END__

=head1 NAME

Chess TCP Server

=head1 SYNOPSIS

perl chess_server.pl [OPTIONS]

 Options:
   --port PORT        Specify the port on which the server will listen (default: 38519).
   --fen FEN          Set the starting position of the game using FEN notation.
   --perft N          Perform a perft test to depth N (for debugging).
   --undo             Allow undoing moves.
   --help             Display this help message.

=head1 DESCRIPTION

This program runs a TCP server that manages a chess game.
Clients can connect to the server and send commands to make moves or undo them.

=head1 EXAMPLES

  perl chess_server.pl --fen "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10" --undo
  perl chess_server.pl --perft 3

=cut
