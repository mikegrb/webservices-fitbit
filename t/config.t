#! perl

use Test::More;
use Test::Exception;
use WebService::FitBit;

dies_ok { WebService::FitBit->new({ config => 'does/not/exist' })}
  'new() without config throws exception';

done_testing();
