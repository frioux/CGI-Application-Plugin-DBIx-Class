#!perl
use strict;
use warnings;
use Test::More;
use UNIVERSAL;
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";
BEGIN { use_ok('CGI::Application::Plugin::DBH') };
BEGIN { use_ok('CAPDBICTest::Schema') };
BEGIN {
   $ENV{CGI_APP_RETURN_ONLY} = 1;
   use_ok('CAPDBICTest::CGIApp');;
};

my $t1_obj = CAPDBICTest::CGIApp->new();
my $t1_output = $t1_obj->run();

my $schema = CAPDBICTest::Schema->connect( $CAPDBICTest::CGIApp::CONNECT_STR );
$schema->deploy();

my @methods = qw{dbic_config paginate schema search sort simple_deletion simple_search sort};
foreach (@methods) {
   ok $t1_obj->can($_), "Can $_";
}

ok $t1_obj->schema->isa('DBIx::Class::Schema'), 'schema() method returns DBIx::Class schema';
ok $t1_obj->schema->resultset('Stations'), 'resultset correctly found';

my $paginated = $t1_obj->paginate($t1_obj->schema->resultset('Stations'));
is $paginated->{total} => 0, 'total from pagination correctly set';
ok $paginated->{data}->isa('DBIx::Class::ResultSet'), 'data from pagination correctly set';

my $paged_and_sorted = $t1_obj->page_and_sort($t1_obj->schema->resultset('Stations'));
is $paged_and_sorted->{total} => 0, 'total from page_and_sort correctly set';
ok $paged_and_sorted->{data}->isa('DBIx::Class::ResultSet'), 'data from page_and_sort correctly set';

END { unlink $CAPDBICTest::CGIApp::DBFILE };
done_testing;
