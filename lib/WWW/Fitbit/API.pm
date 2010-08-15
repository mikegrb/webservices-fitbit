package WWW::Fitbit::API;
use Mouse;
use 5.010;

#
# Author:       Eric Blue - ericblue76@gmail.com
# Project:      Perl Fitbit API
# Url:          http://eric-blue.com/projects/fitbit
#

use Carp;
use HTTP::Cookies;
use LWP::UserAgent;
use Try::Tiny;
use XML::Simple;
use YAML            qw/ LoadFile /;

use vars qw( $VERSION );
$VERSION = '0.1';

has 'base_url' => (
  is      => 'ro' ,
  isa     => 'Str' ,
  default => 'http://www.fitbit.com/graph/getGraphData' ,
);

has 'sid' => (
  is       => 'ro' ,
  isa      => 'Str' ,
  required => 1 ,
);

has 'uid' => (
  is       => 'ro' ,
  isa      => 'Str' ,
  required => 1 ,
);

has 'user_id' => (
  is       => 'ro' ,
  isa      => 'Str' ,
  required => 1 ,
);

has '_browser' => (
  is       => 'ro' ,
  isa      => 'LWP::UserAgent' ,
  init_arg => '_set_browser',
  builder  => '_make_browser' ,
  handles  => [ 'get' , 'cookie_jar' ] ,
);

sub _make_browser {
  return LWP::UserAgent->new( agent => "FitBit Perl API/2.0" );
}

sub BUILDARGS {
  my( $class , $args ) = @_;

  my $config_file = $args->{config} || "$ENV{HOME}/.fitbit";

  die "Can't find config file!"
    unless -e $config_file;

  my $config = LoadFile( $config_file );

  %$args = ( %$config , %$args );
  return $args;
}

sub BUILD {
  my( $self , $args ) = @_;

  my $cookie_jar = HTTP::Cookies->new;
  foreach( qw/ sid uid /) {
    ### FIXME document magic values
    $cookie_jar->set_cookie(
      1 , $_ , $self->$_ , '/' , 'www.fitbit.com' ,
      80 , 0 , 0 , 3600 , 0
    );
  }
  $self->cookie_jar( $cookie_jar );
}

sub active_score {
  my( $self , $args ) = @_;
  $args //= {};

  my $data = $self->fetch_graph_data({
    type => 'activeScore',
    %$args ,
  });

  return $data->[0]{value}{content};
}

sub activities_breakdown {
  my( $self , $args ) = @_;
  $args //= {};

  # ask for raw so we can get the data out of a different
  # part of the returned data structure...
  my $data = $self->fetch_raw_graph_data({
    type => 'activitiesBreakdown' ,
    %$args ,
  });

  $data = $data->{data}{pie}{slice};

  return {
    sedentary => $data->[0]{content} ,
    lightly   => $data->[1]{content} ,
    fairly    => $data->[2]{content} ,
    very      => $data->[3]{content} ,
  };
}

sub build_fitbit_url {
  my( $self , $args ) = @_;

  $args->{date} //= _get_date();

  _check_date_format( $args->{date} );

  my %params = (
    userId  => $self->user_id,
    type    => $args->{type}    || 'stepsTaken' ,
    period  => $args->{period}  || '1d',
    version => $args->{version} || 'amchart',
    dateTo  => $args->{date} ,
  );

  my $query_string = join '&', map { "$_=$params{$_}" } keys %params;

  return $self->base_url . '?' . $query_string;
}

sub calories_in_out {
  my( $self , $args ) = @_;
  $args //= {};

  my $data = $self->fetch_graph_data({
    type => 'caloriesInOut' ,
    %$args ,
  });

  return {
    burned   => $data->[0]{value}{content} ,
    consumed => $data->[1]{value}{content} ,
  };

}

sub distance_from_steps {
  my( $self , $args ) = @_;
  $args //= {};

  my $data = $self->fetch_graph_data({
    type => 'distanceFromSteps' ,
    %$args ,
  });

  return $data->[0]{value}{content};
}

sub fetch_graph_data {
  my( $self , $args ) = @_;

  my $raw_graph_data = $self->fetch_raw_graph_data( $args );

  return $raw_graph_data->{data}{chart}{graphs}{graph};

}

sub fetch_raw_graph_data {
  my( $self , $args ) = @_;

  my $xml = $self->fetch_raw_xml( $args );

  my $raw_graph_data;
  try {
    $raw_graph_data = XMLin( $xml, KeyAttr => [] , ForceArray => [ 'graph' ] );
  }
  catch { confess "$$: XMLin() died: $_\n" };

  return $raw_graph_data;
}

sub fetch_raw_xml {
  my( $self , $args ) = @_;

  # TODO Add methods for sleep; need to solve day-boundary problem (see python
  # code)

  my $url = $self->build_fitbit_url( $args );

  # Note that user agent also uses cookie jar created on initialization
  my $response = $self->get($url);
  unless( $response->is_success ) {
    confess 'Failed to get graph data; reason = HTTP status ('.$response->status_line.')!';
  }
  my $xml = $response->content;
  # Strip leading whitespace for proper parsing
  $xml =~ s/^\s+//gm;

  return $xml;
}

sub intraday_active_score { return shift->intraday_log( 'intradayActiveScore' , @_ ) }

sub intraday_calories_burned { return shift->intraday_log( 'intradayCaloriesBurned' , @_ ) }

sub intraday_log {
  my( $self , $type , $args ) = @_;
  die "Need log type" unless $type;
  $args //= {};

  my $data = $self->fetch_graph_data({
    type => $type ,
    %$args ,
  });

  my @list = @{ $data->[0]{value} };
  pop @list;                    # get rid of the empty last element...

  my @return;

  foreach ( @list ) {
    ### FIXME interval size should be set via param
    my $time      = $_->{xid} * 5;
    my $hours     = int( $time / 60 );
    my $minutes   = $time % 60;
    my $timestamp = sprintf "%02d:%02d" , $hours , $minutes;

    push @return , { $timestamp => $_->{content} }
  }

  return @return;
}

sub intraday_sleep {
  my( $self , $args ) = @_;
  $args //= {};

  my $data = $self->fetch_raw_graph_data({
    type => 'intradaySleep' ,
    %$args ,
  });
  die "NOT DONE YET"
}

sub intraday_steps { return shift->intraday_log( 'intradaySteps' , @_ ) }

sub minutes_active {
  my( $self , $args ) = @_;
  $args //= {};

  my $data = $self->fetch_graph_data({
    type => 'minutesActive' ,
    %$args ,
  });

  return {
    lightly => $data->[0]{value}{content},
    fairly  => $data->[1]{value}{content},
    very    => $data->[2]{value}{content},
  };
}

sub steps_taken {
  my( $self , $args ) = @_;
  $args //= {};

  my $data = $self->fetch_graph_data({
    type => 'stepsTaken' ,
    %$args ,
  });

  return $data->[0]{value}{content};
}

sub time_asleep {
  my( $self , $args ) = @_;
  $args //= {};

  my $data = $self->fetch_graph_data({
    type => 'timeAsleep' ,
    %$args ,
  });

  return $data->[0]{value}{content} ,
}

sub times_woken_up {
  my( $self , $args ) = @_;
  $args //= {};

  my $data = $self->fetch_graph_data({
    type => 'timesWokenUp' ,
    %$args ,
  });

  return $data->[0]{value}{content},
}

sub weight {
  my( $self , $args ) = @_;
  $args //= {};

  my $data = $self->fetch_graph_data({
    type => 'weight' ,
    %$args ,
  });

  return $data->[0]{value}[0]{content};
}

sub _check_date_format {
  my( $date ) = @_;

  # Very basic regex to check date format
  if ( $date !~ /^(\d{4})-(\d{2})-(\d{2})$/ ) {
    confess "Invalid date format [$date].  Expected (YYYY-MM-DD)";
  }

  return 1;
}

sub _get_date {
  my @t = localtime;
  return sprintf "%04d-%02d-%02d" , $t[5]+1900,$t[4]+1,$t[3];
}

1;

__END__

=head1 NAME

WWW::Fitbit::API - OO Perl API used to fetch fitness data from fitbit.com

=head1 SYNOPSIS

Sample Usage:

    use WWW::Fitbit::API;

    my $fb = WWW::Fitbit::API->new(
        # Available from fitbit profile URL
        user_id => "XXXNSD",
        # Populated by cookie
        sid     => "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
        uid     => "12345",
        uis     => "XXX%3D"
    );

    OR

    my $fb = WWW::Fitbit::API->new(config => 'conf/fitbit.conf');

    # No date defaults to today
    my @log = $fb->get_calories_log();
    foreach (@log) {
        print "time = $_->{time} : calories = $_->{value}\n";
    }

    print "calories = " . $fb->total_calories("2010-05-03") . "\n";
    print "activescore = " . $fb->total_active_score("2010-05-03") . "\n";
    print "steps = " . $fb->total_steps("2010-05-03") . "\n";

=head1 DESCRIPTION


C<WWW::Fitbit::API> provides an OO API for fetching fitness data from fitbit.com.
Currently there is no official API, however data is retrieved using XML feeds
that populate the flash-based charts.

Intraday (5min and 1min intervals) logs are provide for:

 - calories burned
 - activity score
 - steps taken
 - sleep activity (every 1 min)

Historical (aggregate) info is provided for:

 - calories burned / consumed
 - activity score
 - steps taken
 - distance travels (miles)
 - sleep (total time in hours, and times awoken)

=head1 METHODS

See method comments for detailed API info:

Note that all detailed log methods (get_*) and historical (total_*)
accept a single data parameter (format = YYYY-MM-DD).  If no date
is supplied, today's date will be used.

=head1 EXAMPLE CODE

See test_client.pl and dump_csv.pl

=head1 KNOWN_ISSUES

At this time, if you attempt to tally the intraday (5min) logs for
the total daily number, this number will NOT match the number from
the total_*_ API call.  This is due to the way that FitBit feeds the
intraday values via XML to the flash-graph chart.  All numbers are
whole numbers, and this rounding issue causes the detailed log
tally to be between 10-100 points higher.

For example:

    # Calling total = 2122
    print "Total calories burned = " . $fb->total_calories()->{burned} . "\n";

    # Tallying total from log entries = 2157
    my $total = 0;
    $total += $_->{value} foreach ( $fb->get_calories_log($date) );

=head1 AUTHOR

Eric Blue <ericblue76@gmail.com> - http://eric-blue.com

=head1 COPYRIGHT

Copyright (c) 2010 Eric Blue. This program is free
software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut


