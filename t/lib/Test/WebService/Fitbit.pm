package Test::WebService::FitBit;
use strict;
use warnings;

use base qw/ Test::Class /;

use Test::More;

use File::Slurp;
use FindBin;
use LWP::UserAgent;
use Test::MockObject::Extends;

use WebService::FitBit;

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

  $test->{fb} = WebService::FitBit->new({ _set_browser => $mock_browser });
}

sub isa_fitbit :Test(1) {
  my $test = shift;

  isa_ok( $test->{fb} , 'WebService::FitBit' );
}

sub active_score :Test(1) {
  my $test = shift;

  is( $test->{fb}->active_score , '52.0' );
}

sub weight :Test(1) {
  my $test = shift;

  is( $test->{fb}->weight , '195.6' );
}

1;
