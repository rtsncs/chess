#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;

use lib '.';
use Chess;
foreach my $arg (@ARGV) {

}

#sub print_board {
#    my $board = shift;
#    for my $i (0..63) {
#        print $board >> (63 - $i) & 1;
#        if ($i % 8 == 7) {
#            print "\n";
#        }
#    }
#    print "\n";
#}
my $chess = Chess->from_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");

my $socket = new IO::Socket::INET(
    LocalHost => '0.0.0.0',
    LocalPort => '38519',
    Proto => 'tcp',
    Listen => 5,
    Reuse => 1,
    Blocking => 0,
) or die "cannot create socket: $!";
print "listening on port 38519\n";

my $select = new IO::Select;
$select->add($socket);

sub send_update {
    my $client = shift;
    my $update = $chess->to_fen() . "|" . join(" ", $chess->get_moves()) . "\n";
    $client->send($update);
}

sub broadcast_update {
    my $update = $chess->to_fen() . "|" . join(" ", $chess->get_moves()) . "\n";
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
            send_update($client);
        } else {
            my $count = $client->recv(my $data, 1024);
            unless (defined($count) && length $data) {
                $select->remove($client);
                close $client;
                print("client disconnected\n");
                next;
            }
            print("received: $data\n");
            if ($data =~ "^make_move") {
                my @data = split / /, $data;
                if ($chess->make_move($data[1])) {
                    broadcast_update();
                } else {
                    send_update($client);
                }
            }
        }
    }
}
