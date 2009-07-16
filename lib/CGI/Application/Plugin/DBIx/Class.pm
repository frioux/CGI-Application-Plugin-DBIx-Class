package CGI::Application::Plugin::DBIx::Class;

# ABSTRACT: Access a DBIx::Class Schema from a CGI::Application

use strict;
use warnings;
use vars qw($VERSION @EXPORT_OK);
use Readonly;
use Carp 'croak';
use Method::Signatures::Simple;

require Exporter;

use base qw(Exporter AutoLoader);

@EXPORT_OK = qw(&dbic_config &page_and_sort &schema &search &simple_search &simple_sort &sort &paginate &simple_deletion);

$VERSION = '0.0001';

method dbic_config($config) {
   my $ignored_params = $config->{ignored_params} ||
      [qw{limit start sort dir _dc rm xaction}];

   $self->{__dbic_ignored_params} = { map { $_ => 1 } @{$ignored_params} };

   $self->{__dbic_schema_class} = $config->{schema} or die 'you must pass a schema into dbic_config';
}

Readonly my $PAGES => 25;

method page_and_sort {
   my $rs = shift;
   $rs = $self->simple_sort($rs);
   return $self->paginate($rs);
}

method paginate {
   my $resultset = shift;
   # param names should be configurable
   my $rows = $self->query->param('limit') || $PAGES;
   my $page =
      $self->query->param('start')
      ? ( $self->query->param('start') / $rows + 1 )
      : 1;

   my $total = $resultset->count;

   my $paginated_rs = $resultset->search( undef, {
         rows => $rows,
         page => $page
      });

   # this is a workaround for MSSQL
   my $is_last_page =
      $total - $rows * ( $page - 1 ) < $rows
      ? 1
      : 0;

   my $skip = $rows - $total % $rows + 1;

   # this json stuff needs to be in a completely separate class
   my $data = { data => [], total => $total };

   TO_JSON:
   while ( my $row = $paginated_rs->next() ) {
      $skip--;
      next TO_JSON if $page != 1 and $is_last_page and ($skip > 0); # workaround
      push @{ $data->{data} }, $row->TO_JSON; # json stuff
   }

   return $self->json_body($data); # json stuff
}

method schema {
   if ( !$self->{schema} ) {
      $self->{schema} = $self->{__dbic_schema_class}->connect( sub { $self->dbh() } );
   }
   return $self->{schema};
}

method search($rs_name) {
   my %q       = $self->query->Vars;
   my $rs      = $self->schema->resultset($rs_name);
   return $rs->controller_search(\%q);
}

method sort($rs_name) {
   my %q       = $self->query->Vars;
   my $rs      = $self->schema->resultset($rs_name);
   return $rs->controller_sort(\%q);
}

method simple_deletion($params) {
   # param names should be configurable
   my @to_delete = $self->query->param('to_delete') or croak 'Required parameter (to_delete) undefined!';
   my $rs =
     $self->schema()->resultset( $params->{table} )
     ->search( { id => { -in => \@to_delete } }, {} );
   while ( my $record = $rs->next() ) {    ## no critic (AmbiguousNames)
      $record->delete();
   }
   return \@to_delete;
}

method simple_search($params) {
   my $table  = $params->{table};
   my %skips  = %{$self->{__dbic_ignored_params}};
   my $searches = {};
   foreach ( keys %{ $self->query->Vars } ) {
      if ( $self->query->param($_) and not $skips{$_} ) {
         # should be configurable
         $searches->{$_} = { like => q{%} . $self->query->param($_) . q{%} };
      }
   }

   my $rs_full = $self->schema()->resultset($table)->search($searches);

   return $self->page_and_sort($rs_full);
}

method simple_sort {
   # param names should be configurable
   my $rs = shift;
   my %order_by = ( order_by => [ $rs->result_source->primary_columns ] );
   if ( $self->query->param('sort') ) {
      %order_by =
        ( order_by => $self->query->param('sort') . q{ }
           . $self->query->param('dir') );
   }
   return $rs->search(undef, { %order_by });
}

"Sleepy time";

=pod

=head1 NAME

CGI::Application::Plugin::DBIx::Class - distribution builder; installer not included!

=head1 VERSION

version 0.0001

=head1 DESCRIPTION


=head1 METHODS

=head2 dbic_config

  $self->dbic_config({schema => MyApp::Schema->connect(@connection_data)});

Description

Valid arguments are:

  schema - Instance of DBIC Schema
  ignored_params - Params to ignore

=head2 page_and_sort

  my $resultset = $self->schema->resultset('Foo');
  my $result = $self->page_and_sort($resultset);

Description

=head2 paginate

  my $resultset = $self->schema->resultset('Foo');
  my $result = $self->paginate($resultset);

Description

Valid arguments are:

  resultset - DBIx::Class::ResultSet

=head2 paginate

  my $resultset = $self->schema->resultset('Foo');
  my $result = $self->paginate($resultset);

Description

=head2 schema

  my $schema = $self->schema;

Description

=head2 search

  my $resultset   = $self->schema->resultset('Foo');
  my $searched_rs = $self->search($resultset);

Description, uses $rs->controller_search

=head2 sort

  my $resultset = $self->schema->resultset('Foo');
  my $result = $self->sort($resultset);

Description, uses $rs->controller_sort

=head2 simple_deletion

  $self->simple_deletion({ table => 'Foo' });

Valid arguments are:

  table - source loaded into schema

=head2 simple_search

  my $searched_rs = $self->simple_search({ table => 'Foo' });

Valid arguments are:

  table - source loaded into schema

=head2 simple_sort

  my $resultset = $self->schema->resultset('Foo');
  my $sorted_rs = $self->simple_sort($resultset);

Valid arguments are:

  table - source loaded into schema

Description

=cut

__END__
