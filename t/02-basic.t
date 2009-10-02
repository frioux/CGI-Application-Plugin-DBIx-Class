#!perl
use strict;
use warnings;
use Test::More;
use Test::Deep;
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
$schema->populate(Stations => [
   [qw{id bill    ted       }],
   [qw{1  awesome bitchin   }],
   [qw{2  cool    bad       }],
   [qw{3  tubular righeous  }],
   [qw{4  rad     totally   }],
   [qw{5  sweet   beesknees }],
   [qw{6  gnarly  killer    }],
   [qw{7  hot     legit     }],
   [qw{8  groovy  station   }],
   [qw{9  wicked  out       }],
]);

my @methods = qw{dbic_config paginate schema search sort simple_deletion simple_search sort};
foreach (@methods) {
   ok $t1_obj->can($_), "Can $_";
}

ok $t1_obj->schema->isa('DBIx::Class::Schema'), 'schema() method returns DBIx::Class schema';
ok $t1_obj->schema->resultset('Stations'), 'resultset correctly found';

# page_and_sort
{
   my $paged_and_sorted = $t1_obj->page_and_sort($t1_obj->schema->resultset('Stations'));
   ok $paged_and_sorted->isa('DBIx::Class::ResultSet'), 'data from page_and_sort correctly set';
}

# paginate
{

   $t1_obj->query->param(limit => 3);
   my $paginated = $t1_obj->paginate($t1_obj->schema->resultset('Stations'));
   cmp_ok $paginated->count, '>=', 3,
      'paginate gave the correct amount of results';

   $t1_obj->query->param(start => 3);
   my $paginated_with_start =
      $t1_obj->paginate($t1_obj->schema->resultset('Stations'));
   my %hash;
   @hash{map $_->id, $paginated->all} = ();
   ok !grep({ exists $hash{$_} } map $_->id, $paginated_with_start->all ),
      'pages do not intersect';
}

# search
TODO:
{
   local $TODO = 'need real search test';
   my $searched = $t1_obj->search('Stations');
   ok $searched->isa('DBIx::Class::ResultSet'), 'data from search correctly set';
}

# sort
TODO:
{
   local $TODO = 'need real sort test';
   my $sort = $t1_obj->sort('Stations');
   ok $sort->isa('DBIx::Class::ResultSet'), 'data from sort correctly set';
}

# simple_search
{
   $t1_obj->query->param('bill', 'oo');
   my $simple_searched = $t1_obj->simple_search({ table => 'Stations' });
   is scalar(grep { $_->bill =~ m/oo/ } $simple_searched->all),
      scalar($simple_searched->all), 'simple search found the right results';
}

# simple_sort
{
   my $simple_sorted =
      $t1_obj->simple_sort($t1_obj->schema->resultset('Stations'));
   cmp_deeply [map $_->id, $simple_sorted->all], [1..9], 'default sort is id';

   $t1_obj->query->param(dir => 'asc');
   $t1_obj->query->param(sort => 'bill');
   $simple_sorted =
      $t1_obj->simple_sort($t1_obj->schema->resultset('Stations'));
   cmp_deeply [map $_->bill, $simple_sorted->all],
              [sort map $_->bill, $simple_sorted->all], 'alternate sort works';

   $t1_obj->query->param(dir => 'desc');
   $simple_sorted =
      $t1_obj->simple_sort($t1_obj->schema->resultset('Stations'));
   cmp_deeply [map $_->bill, $simple_sorted->all],
              [reverse sort map $_->bill, $simple_sorted->all],
	      'alternate sort works';
}

# simple_deletion
{
   $t1_obj->query->param('to_delete', 1, 2, 3);
   cmp_bag [map $_->id, $t1_obj->schema->resultset('Stations')->all] => [1..9], 'values are not deleted';
   my $simple_deletion = $t1_obj->simple_deletion({ table => 'Stations' });
   cmp_bag $simple_deletion => [1,2,3], 'values appear to be deleted';
   cmp_bag [map $_->id, $t1_obj->schema->resultset('Stations')->all] => [4..9], 'values are deleted';
   $t1_obj->query->delete('to_delete');
}

done_testing;
END { unlink $CAPDBICTest::CGIApp::DBFILE };
