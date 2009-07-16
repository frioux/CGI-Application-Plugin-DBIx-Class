use Test::More tests => 9;
BEGIN { use_ok('CGI::Application::Plugin::DBH') };

use lib './t/lib';
use strict;

$ENV{CGI_APP_RETURN_ONLY} = 1;
my $dbfile = 't/test.db';
use CAPDBICTest::CGIApp;
use CAPDBICTest::Schema;
my $schema = CAPDBICTest::Schema->connect( "dbi:SQLite:dbname=$dbfile" );
$schema->deploy();

my $t1_obj = CAPDBICTest::CGIApp->new();
my $t1_output = $t1_obj->run();

# ensure that methods got imported correctly
my @methods = qw{dbic_config paginate schema search sort simple_deletion simple_search sort};
foreach (@methods) {
   ok($t1_obj->can($_), "Can $_");
}

unlink $dbfile;
