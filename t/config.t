#! perl

use Test::More;
use Test::Exception;
use WWW::Fitbit::API;

dies_ok { WWW::Fitbit::API->new({ config => 'does/not/exist' })}
  'new() without config throws exception';

done_testing();
