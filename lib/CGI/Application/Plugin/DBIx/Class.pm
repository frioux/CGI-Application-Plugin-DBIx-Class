package CGI::Application::Plugin::DBIx::Class;

# ABSTRACT: Access a DBIx::Class Schema from a CGI::Application

use strict;
use warnings;
use Readonly;
use Carp 'croak';

require Exporter;

use base qw(Exporter AutoLoader);

our @EXPORT_OK   = qw(&dbic_config &page_and_sort &schema &search &simple_search &simple_sort &sort &paginate &simple_deletion);
our %EXPORT_TAGS = (all => [@EXPORT_OK]);
our $VERSION     = '0.0001';

Readonly my $PAGES => 25;

sub dbic_config {
   my $self = shift;
   my $config = shift;
   my $ignored_params = $config->{ignored_params} ||
      [qw{limit start sort dir _dc rm xaction}];

   $self->{__dbic_ignored_params} = { map { $_ => 1 } @{$ignored_params} };

   $self->{__dbic_schema_class} = $config->{schema} or croak 'you must pass a schema into dbic_config';
}

sub page_and_sort {
   my $self = shift;
   my $rs = shift;
   $rs = $self->simple_sort($rs);
   return $self->paginate($rs);
}

sub paginate {
   my $self     = shift;
   my $resultset = shift;
   # param names should be configurable
   my $rows = $self->query->param('limit') || $PAGES;
   my $page =
      $self->query->param('start')
      ? ( $self->query->param('start') / $rows + 1 )
      : 1;

   return $resultset->search_rs( undef, {
      rows => $rows,
      page => $page
   });
}

sub schema {
   my $self = shift;
   if ( !$self->{schema} ) {
      $self->{schema} = $self->{__dbic_schema_class}->connect( sub { $self->dbh() } );
   }
   return $self->{schema};
}

sub search {
   my $self = shift;
   my $rs_name = shift or croak 'required parameter rs_name for search was undefined';
   my %q       = $self->query->Vars;
   my $rs      = $self->schema->resultset($rs_name);
   return $rs->controller_search(\%q);
}

sub sort {
   my $self = shift;
   my $rs_name = shift or croak 'required param to sort rs_name was undefined';
   my %q       = $self->query->Vars;
   my $rs      = $self->schema->resultset($rs_name);
   return $rs->controller_sort(\%q);
}

sub simple_deletion {
   my $self = shift;
   my $params = shift;
   # param names should be configurable
   my @to_delete = $self->query->param('to_delete') or croak 'Required parameter (to_delete) undefined!';
   my $rs =
     $self->schema->resultset( $params->{table} )
     ->search({
           id => { -in => \@to_delete }
     })->delete;
   return \@to_delete;
}

sub simple_search {
   my $self = shift;
   my $params = shift;
   my $table  = $params->{table};
   my %skips  = %{$self->{__dbic_ignored_params}};
   my $searches = {};
   foreach ( keys %{ $self->query->Vars } ) {
      # we use '' here because it's conceivable that someone
      # would want to search with a 0, whereas '' is always
      # going to imply null for a user
      if ( $self->query->param($_) ne '' and not $skips{$_} ) {
         # should be configurable
         $searches->{$_} = { like => q{%} . $self->query->param($_) . q{%} };
      }
   }

   my $rs_full = $self->schema()->resultset($table)->search($searches);

   return $self->page_and_sort($rs_full);
}

sub simple_sort {
   my $self = shift;
   # param names should be configurable
   my $rs = shift or croak 'required parameter rs for simple_sort not defined';
   my %order_by = ( order_by => [ $rs->result_source->primary_columns ] );
   if ( $self->query->param('sort') ) {
      %order_by = (
         order_by => {
            q{-}.$self->request->params->{dir} => $self->request->params->{sort}
         }
      );
   }
   return $rs->search(undef, { %order_by });
}

1;

=pod

=head1 SYNOPSIS

  use CGI::Application::Plugin::DBH (qw/dbh_config dbh/);
  use CGI::Application::Plugin::DBIx::Class ':all';

  sub cgiapp_init  {
      my $self = shift;

      # see docs for L<CGI::Application::Plugin::DBH>
      $self->dbh_config($data_source, $username, $auth, \%attr);
  }

  sub my_run_mode {
     my $self = shift;

     my $date = $self->dbh->selectrow_array("SELECT CURRENT_DATE");
     # again with a named handle
     $date = $self->dbh('my_handle')->selectrow_array("SELECT CURRENT_DATE");

  }




=head1 DESCRIPTION

=head1 METHODS

=head2 dbic_config

  $self->dbic_config({schema => MyApp::Schema->connect(@connection_data)});

Description

You must run this method in setup or cgiapp_init to setup your schema.

Valid arguments are:

  schema - Required, Instance of DBIC Schema
  ignored_params - Optional, Params to ignore when doing a simple search or sort,
     defaults to

  [qw{limit start sort dir _dc rm xaction}]

=head2 page_and_sort

  my $resultset = $self->schema->resultset('Foo');
  my $result = $self->page_and_sort($resultset);

Description

This is a helper method that will first sort your data and then paginate it.
Returns data the way paginate does.

=head2 paginate

  my $resultset = $self->schema->resultset('Foo');
  my $result = $self->paginate($resultset);

Description

Paginates the passed in schema by the following CGI parameters:

  start - page to show
  limit - amount of rows per page

Returns data has a hashref containing:

  data  => $paginated_rs,
  total => $total_rows,

=head2 schema

  my $schema = $self->schema;

Description

This is just a basic accesor method for your schema

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
