#! /usr/bin/env perl

use inc::Module::Install;

name 'WWW-Fitbit-API';
all_from 'lib/WWW/Fitbit/API.pm';

requires 'Carp';

requires 'File::Slurp';
requires 'HTTP::Cookies';
requires 'HTTP::Request';
requires 'LWP::UserAgent';
requires 'Mouse';
requires 'Try::Tiny';
requires 'XML::Simple';
requires 'YAML';

test_requires 'Test::MockObject::Extends';

install_script glob('script/*.pl');
auto_install;
WriteAll;
