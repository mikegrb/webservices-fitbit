#!/usr/bin/perl

use strict;
use warnings;

#
# Author:       Eric Blue - ericblue76@gmail.com
# Project:      Perl Fitbit API - CSV export
# Url:          http://eric-blue.com/projects/fitbit
#

use WWW::Fitbit::API;
use POSIX;

my $fb = WWW::Fitbit::API->new();

my $day        = 86400;    # 1 day
my $total_days = 7;

system("mkdir export") if !-e "export";
open( TOTALS_CSV, ">export/totals.csv" ) or die "Can't open CSV file!";

# Weekly CSV header
print TOTALS_CSV
qq{DATE,BURNED,CONSUMED,SCORE,STEPS,DISTANCE,ACTIVE_VERY,ACTIVE_FAIR,ACTIVE_LIGHT,SLEEP_TIME,AWOKEN};
print TOTALS_CSV "\n";

for ( my $i = 0 ; $i < $total_days ; $i++ ) {
    my $previous_day = strftime( "%F", localtime( time - $day ) );
    print "Getting data for $previous_day ...\n";

    print TOTALS_CSV $previous_day . ",";
    print TOTALS_CSV $fb->calories_in_out({ date => $previous_day })->{burned} . ",";
    print TOTALS_CSV $fb->calories_in_out({ date => $previous_day })->{consumed} . ",";
    print TOTALS_CSV $fb->active_score({ date => $previous_day }) . ",";
    print TOTALS_CSV $fb->steps_taken({ date => $previous_day }) . ",";
    print TOTALS_CSV $fb->distance_from_steps({ date => $previous_day }) . ",";

    my $ah = $fb->minutes_active({ date => $previous_day });
    print TOTALS_CSV $ah->{very} . ",";
    print TOTALS_CSV $ah->{fairly} . ",";
    print TOTALS_CSV $ah->{lightly} . ",";

    print TOTALS_CSV $fb->time_asleep({ date => $previous_day }) .',';
    print TOTALS_CSV $fb->times_woken_up({ date => $previous_day });

    print TOTALS_CSV "\n";

    $day += 86400;

}

close(TOTALS_CSV);

# TODO CSV export for daily/intraday (5-minute) intervals
