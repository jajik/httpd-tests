package Apache::TestSort;

use strict;
use warnings FATAL => 'all';
use Apache::TestTrace;

sub repeat {
    my($list, $times) = @_;
    # a, a, b, b
    @$list = map { ($_) x $times } @$list;
}

sub rotate {
    my($list, $times) = @_;
    # a, b, a, b
    @$list = (@$list) x $times;
}

sub random {
    my($list, $times) = @_;

    rotate($list, $times); #XXX: allow random,repeat

    my $seed = $ENV{APACHE_TEST_SEED} || '';
    my $info = "";

    if ($seed) {
        $info = " (from APACHE_TEST_SEED env var)";
        # so we could reproduce the order
    }
    else {
        $seed = time ^ ($$ + ($$ << 15));
    }

    warning "Using random number seed: $seed" . $info;

    srand($seed);

    #from perlfaq4.pod
    for (my $i = @$list; --$i; ) {
	my $j = int rand ($i+1);
	next if $i == $j;
	@$list[$i,$j] = @$list[$j,$i];
    }
}

sub run {
    my($self, $list, $args) = @_;

    my $times = $args->{times} || 1;
    my $order = $args->{order} || 'rotate';
    if ($order =~ /^\d+$/) {
        #dont want an explicit -seed option but env var can be a pain
        #so if -order is number assume it is the random seed
        $ENV{APACHE_TEST_SEED} = $order;
        $order = 'random';
    }
    my $sort = \&{$order};

    # re-shuffle the list according to the requested order
    if (defined &$sort) {
        $sort->($list, $times);
    }
    else {
        error "unknown order '$order'";
    }

}

1;
