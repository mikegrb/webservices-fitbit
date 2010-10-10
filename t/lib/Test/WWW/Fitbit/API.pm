package Test::WWW::Fitbit::API;
use strict;
use warnings;

use base qw/ Test::Class /;

use Test::More;
use Test::Exception;

use File::Slurp;
use FindBin;
use LWP::UserAgent;
use Test::MockObject::Extends;

use WWW::Fitbit::API;

sub setup_fitbit_object :Test(setup) {
  my $test = shift;

  my $browser = LWP::UserAgent->new();
  my $mock_browser = Test::MockObject::Extends->new( $browser );

  $mock_browser->mock( 'get' , sub {
    my( $self , $url ) = @_;
    my( $type ) = $url =~ /type=([^&]+)&/ or die $url;

    my $file = "$FindBin::Bin/data/$type.xml";
    die "Can't find $file" unless -e $file;

    my $text = read_file( $file );
    my $response = HTTP::Response->new();
    my $mock_response = Test::MockObject::Extends->new( $response );
    $mock_response->mock( 'content' , sub { return $text } )
                  ->mock( 'is_success' , sub { return 1 } );
    return $mock_response;
  });

  $test->{fb} = WWW::Fitbit::API->new({ _set_browser => $mock_browser });

  # most of the API tests will get run twice, once without any args and once
  # with a date. this just lets us do that in a loop more easily.
  $test->{different_args} = [ undef , { date => '2001-01-01' } ];
}

sub active_score :Test(2) {
  my $test = shift;

  foreach my $args ( @{ $test->{different_args} } ) {
    is( $test->{fb}->active_score( $args ) , '52.0' );
  }
}

sub activities_breakdown :Test(3) {
  my $test = shift;

  foreach my $args ( @{ $test->{different_args} } ) {
    is_deeply(
      $test->{fb}->activities_breakdown($args) ,
      {
        sedentary => '62.75' ,
        lightly   => '26.249998' ,
        fairly    => '10.0' ,
        very      => '1.0'  ,
      } ,
    );
  }

  throws_ok { $test->{fb}->activities_breakdown({ date => '2020' }) }
    qr/Invalid date format/ , 'bad dates are bad';

}

sub bad_response :Test {

}

sub calories_in_out :Test(2) {
  my $test = shift;

  foreach my $args ( @{ $test->{different_args} } ) {
    is_deeply(
      $test->{fb}->calories_in_out( $args ) ,
      {
        burned   => '506.0' ,
        consumed => '0.0' ,
      }
    );
  }
}

sub distance_from_steps :Test(2) {
  my $test = shift;

  foreach my $args ( @{ $test->{different_args} } ) {
    is( $test->{fb}->distance_from_steps($args) , '0.11383521' );
  }

}

sub intraday_active_score :Test(6) {
  my $test = shift;

  foreach my $args ( @{ $test->{different_args} } ) {
    my @active_scores = $test->{fb}->intraday_active_score($args);

    is_deeply( $active_scores[5]  , { '00:25' => '0.0' } );
    is_deeply( $active_scores[10] , { '00:50' => '1.0' } );
    is_deeply( $active_scores[15] , { '01:15' => '0.0' } );
  }

}

sub intraday_calories_burned :Test(6) {
  my $test = shift;

  foreach my $args ( @{ $test->{different_args} } ) {
    my @calories_burned = $test->{fb}->intraday_calories_burned($args);

    is_deeply( $calories_burned[5]  , { '00:25' => '6.0' } );
    is_deeply( $calories_burned[10] , { '00:50' => '8.0' } );
    is_deeply( $calories_burned[15] , { '01:15' => '6.0' } );
  }
}

sub intraday_log :Test(2) {
  my $test = shift;

  throws_ok { $test->{fb}->intraday_log() }
    qr/Need log type/ , 'intraday_log needs a type';

  my $browser = LWP::UserAgent->new();
  my $mock_browser = Test::MockObject::Extends->new( $browser );

  $mock_browser->mock( 'get' , sub {
    my $response = HTTP::Response->new();
    my $mock_response = Test::MockObject::Extends->new( $response );
    $mock_response->mock( 'is_success' , sub { return 0 } );
    return $mock_response;
  });

  my $fb = WWW::Fitbit::API->new({ _set_browser => $mock_browser });
  throws_ok { $fb->intraday_log({ type => 'foo' })}
    qr/Failed to get graph data/ , 'see proper response on fetch failure';
}

sub intraday_steps :Test(6) {
  my $test = shift;

  foreach my $args ( @{ $test->{different_args} } ) {
    my @steps = $test->{fb}->intraday_steps($args);

    is_deeply( $steps[5]  , { '00:25' => '0.0' } );
    is_deeply( $steps[10] , { '00:50' => '0.0' } );
    is_deeply( $steps[15] , { '01:15' => '0.0' } );
  }
}

sub intraday_sleep :Test(2) {
  my $test = shift;

 TODO: {
    local $TODO = 'intraday_sleep not done yet...';

    eval {
      foreach my $args ( @{ $test->{different_args} } ) {
        is_deeply( $test->{fb}->intraday_sleep($args) , [] );
      }
    }
  }
}

sub isa_fitbit :Test(3) {
  my $test = shift;

  isa_ok( $test->{fb} , 'WWW::Fitbit::API' );

  local $ENV{HOME} = '/dont/exist';
  throws_ok { WWW::Fitbit::API->new() } qr/Can't find config file/ ,
    'constructor should throw exception when config file is missing';

  my $fb = WWW::Fitbit::API->new({ config => 't/fitbit.conf'} );
  isa_ok( $fb , 'WWW::Fitbit::API' );
}

sub minutes_active :Test(2) {
  my $test = shift;

  foreach my $args ( @{ $test->{different_args} } ) {
    is_deeply(
      $test->{fb}->minutes_active($args) ,
      {
        lightly => '0.35' ,
        fairly  => '0.13' ,
        very    => '0.0' ,
      } ,
    );
  }
}


sub steps_taken :Test(2) {
  my $test = shift;

  foreach my $args ( @{ $test->{different_args} } ) {
    is( $test->{fb}->steps_taken( $args ) , '252.0' );
  }
}

sub time_asleep :Test(2) {
  my $test = shift;

  foreach my $args ( @{ $test->{different_args} } ) {
    is( $test->{fb}->time_asleep($args) , '5.4333334' );
  }
}

sub times_woken_up :Test(2) {
  my $test = shift;

  foreach my $args ( @{ $test->{different_args} } ) {
    is( $test->{fb}->times_woken_up($args) , '10.0' );
  }
}

sub weight :Test(2) {
  my $test = shift;

  foreach my $args ( @{ $test->{different_args} } ) {
    is( $test->{fb}->weight($args) , '195.6' );
  }
}

1;
