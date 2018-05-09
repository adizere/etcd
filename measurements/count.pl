#!/usr/bin/env perl

use strict;
use warnings;

use IPC::Open2;
use IO::Handle;
use DateTime;
use DateTime::Format::Pg;
use Statistics::Basic qw( mean stddev );
use Data::Dumper;


# The bandwidth output
my $bwo = new IO::File "bandwidth", "w";
if ( ! defined $bwo) {
    die "Cannot open the file for bandwidth output!\n";
    undef $bwo;
}


# Obtain the absolute starting time..
# my $sline = `grep -m10 -h -E "(<-|FINISHED|PAXOS_ACCEPTED)" ./log_proposer* |
#     sort -g | head -n1`;
# my ($ssec, $susec) = ($sline =~ /(\d+).(\d+)/);
# my $startt = DateTime->from_epoch( epoch => "$ssec.$susec" );

# This will give us the sorted output from all nodes
my $cmd = qq(cat logs/* | cut -f2- -d' ' | sort -g);
my $rawout;
# We pipe the output from the above command into $rawout
open2($rawout, undef, $cmd);


# Now extract bandwidths etc., line by line
my $bwr = {};
my $last_started = 0;
my $pipeline = 0;

my $rawln;
while ($rawln = $rawout->getline())
{
    # Ignore iids smaller than 8 (first instances are for raft housekeeping)
    if ($rawln =~ /.*iid: (\d+).*/) {
        next unless ($1 > 8);
    }

    # Detect if an instance is just starting now..
    if ($rawln =~ /^(.+)\.(\d+).*iid: (\d+).*START/) {

        $bwr->{$3}->{start} = "$1.$2";

        $bwr->{$3}->{mcnt} = 1;
        $bwr->{$3}->{cmcnt} = 0;
        $bwr->{$3}->{end} = "";

        # We might have a pipeline of multiple started instances,
        # recall the first started instance only.
        if ($last_started == 0) {
            $pipeline = 1;
            $last_started = $3;
        }

    # Perhaps this line marks the end of an instance
    } elsif ($rawln =~ /^(.+)\.(\d+).*iid: (\d+).*END/) {
        # printf("found END for instance %d with starting time: '%s' '%s'\n",
        #     $3, $1, $2);
        $bwr->{$3}->{mcnt}++;
        $bwr->{$3}->{cmcnt}++;
        $bwr->{$3}->{end} = "$1.$2";

        # If we're in pipeline mode, simply advance the instance
        if ($pipeline == 1) {
            my $next = get_next_started($bwr);
            if ($next == 0) {
                $last_started++
            } else {
                $last_started = $next
            }

            if (!defined $bwr->{$last_started}->{mcnt}) {
                $bwr->{$last_started}->{mcnt} = 0;
            }
            if (!defined $bwr->{$last_started}->{cmcnt}) {
                $bwr->{$last_started}->{cmcnt} = 0;
            }
        } else {
            # If we're NOT in pipeline mode, the next raw output will tell us
            # which is going to be the next instance, so we can forget the
            # current one.
            $last_started = 0;
        }

    # Otherwise, check for any messages to count
    } else {
        $bwr->{$last_started}->{mcnt}++;
    }

    # Count messages for each consensus instance
    # Only count if the instance hasn't finished yet
    if ($rawln =~ /.*iid: (\d+).*/) {
        if ($bwr->{$1}->{end} eq "") {
            $bwr->{$1}->{cmcnt}++;
        }
    }

    # printf("trying line: '%s'\n", $rawln);
    # printf("Last: \t(last=%d)\n", $last_started);
    # foreach my $key (keys %$bwr) {
    #     printf("%d :\t%d\t(c: %d)\t\t(start=%s)\t\t(end=%s)\n",
    #         $key, $bwr->{$key}->{mcnt},
    #         $bwr->{$key}->{cmcnt},
    #         $bwr->{$key}->{start},
    #         $bwr->{$key}->{end},
    #         );
    # }
    # printf("\n");

    # if ($last_started > 12) {
    #     exit;
    # }
}


my @bw = ();
my @cbw = ();
# Print the bandwidth measurements
foreach my $iid (sort {$a <=> $b} keys %$bwr) {
    my $duration;

    if (defined $bwr->{$iid}->{end} && defined $bwr->{$iid}->{start} &&
        $bwr->{$iid}->{end} ne '' && $bwr->{$iid}->{start} ne '') {
        # printf("trying with '%s' '%s'\n", $bwr->{$iid}->{end}, $bwr->{$iid}->{start});
        $duration = DateTime::Format::Pg->parse_datetime(
                        $bwr->{$iid}->{end} )->subtract_datetime(
                    DateTime::Format::Pg->parse_datetime(
                        $bwr->{$iid}->{start} ))->in_units(
                    'nanoseconds') / 1000;
    } else {
        $duration = "?";
    }
    my $res = sprintf("iid: %5d, %10d, %10d, \t %10s\n",
        $iid,
        defined $bwr->{$iid}->{mcnt} ? $bwr->{$iid}->{mcnt} : 0,
        defined $bwr->{$iid}->{cmcnt} ? $bwr->{$iid}->{cmcnt} : 0,
        $duration);
    printf("%s", $res);
    print $bwo "$res";

    # Retain the per-instance bw, to create means & stddev
    defined $bwr->{$iid}->{mcnt} && push @bw, $bwr->{$iid}->{mcnt};

    # Retain the per-consensus bw
    defined $bwr->{$iid}->{cmcnt} && push @cbw, $bwr->{$iid}->{cmcnt};
}

# Compute the sums
my ($bws, $cbws) = (0, 0);
foreach my $nu (@bw) {
    $bws += $nu;
}

foreach my $nu (@cbw) {
    $cbws += $nu;
}

printf("\tSMR mean: %f ; \tstddev: %f ; tot: %d\n",
    mean(@bw), stddev(@bw), $bws);
printf("\tCns mean: %f ; \tstddev: %f ; tot: %d\n",
    mean(@cbw), stddev(@cbw), $cbws);
print $bwo "#\t SMR -- mean: " . mean(@bw) . " stddev: " . stddev(@bw) . "\n";
print $bwo "#\t Consensus -- mean: " . mean(@cbw) . " stddev: " . stddev(@cbw);

# Close the output file handles
# undef $tlo;
undef $bwo;

exit;



# finds the smallest instance which has not finished
sub get_next_started
{
    my $stats = shift();

    foreach my $iid (sort {$a <=> $b} keys %$stats) {
        if ($bwr->{$iid}->{end} eq "") {
            return $iid
        }
    }
    return 0
}
