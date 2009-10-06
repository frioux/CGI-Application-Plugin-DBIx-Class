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
   # name of method should be configurable
   return $rs->controller_search(\%q);
}

sub sort {
   my $self = shift;
   my $rs_name = shift or croak 'required param to sort rs_name was undefined';
   my %q       = $self->query->Vars;
   my $rs      = $self->schema->resultset($rs_name);
   # name of method should be configurable
   return $rs->controller_sort(\%q);
}

sub simple_deletion {
   my $self = shift;
   my $params = shift;
   # param names should be configurable
   my @to_delete = $self->query->param('to_delete') or croak 'Required parameter (to_delete) undefined!';
   my $rs =
     $self->schema->resultset( $params->{rs} )
     ->search({
           id => { -in => \@to_delete }
     })->delete;
   return \@to_delete;
}

sub simple_search {
   my $self = shift;
   my $params = shift;
   my $rs  = $params->{rs};
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

   my $rs_full = $self->schema()->resultset($rs)->search($searches);

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
            q{-}.$self->query->param('dir') => $self->query->param('sort')
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
      $self->dbic_config({schema => 'MyApp::Schema' });
  }

  sub person {
     my $self   = shift;
     my $id     = $self->query->param('id');
     my $person = $self->schema->resultset('People')->find($id);
     # ...
  }

  sub people {
     my $self   = shift;
     my $people = $self->page_and_sort(
         $self->simple_search(
            $self->schema->resultset('People')
         )
     );
  }


=head1 DESCRIPTION

This module basically helps you to map various L<DBIx::Class> features to CGI
parameters.  For the most part that means it will help you do searching,
sorting, and pagination with a minimum of effort and thought.  Currently the
connection is gotten from L<CGI::Application::Plugin::DBH>.

=head1 METHODS

=head2 dbic_config

  $self->dbic_config({schema => MyApp::Schema->connect(@connection_data)});

=head3 Description

You must run this method in setup or cgiapp_init to setup your schema.

=head3 Valid arguments are:

  schema - Required, Name of DBIC Schema
  ignored_params - Optional, Params to ignore when doing a simple search or sort,
     defaults to

  [qw{limit start sort dir _dc rm xaction}]

=head2 page_and_sort

  my $resultset = $self->schema->resultset('Foo');
  my $result = $self->page_and_sort($resultset);

=head3 Description

This is a helper method that will first sort your data and then paginate it.
Returns a resultset.

=head2 paginate

  my $resultset = $self->schema->resultset('Foo');
  my $result = $self->paginate($resultset);

=head3 Description

Paginates the passed in resultset based on the following CGI parameters:

  start - first row to display
  limit - amount of rows per page

Returns a resultset.

=head2 schema

  my $schema = $self->schema;

=head3 Description

This is just a basic accessor method for your schema

=head2 search

  my $resultset   = $self->schema->resultset('Foo');
  my $searched_rs = $self->search($resultset);

=head3 Description

Calls the controller_search method on the passed in resultset with all of the
CGI parameters.  I like to have this look something like the following:

   # Base search dispatcher, defined in MyApp::Schema::ResultSet
   sub _build_search {
      my $self           = shift;
      my $dispatch_table = shift;
      my $q              = shift;

      my %search = ();
      my %meta   = ();

      foreach ( keys %{$q} ) {
         if ( my $fn = $dispatch_table->{$_} and $q->{$_} ) {
            my ( $tmp_search, $tmp_meta ) = $fn->( $q->{$_} );
            %search = ( %search, %{$tmp_search} );
            %meta   = ( %meta,   %{$tmp_meta} );
         }
      }

      return $self->search(\%search, \%meta);
   }

   # search method in specific resultset
   sub controller_search {
      my $self   = shift;
      my $params = shift;
      return $self->_build_search({
            status => sub {
               return { 'repair_order_status' => shift }, {};
            },
            part_id => sub {
               return { 'lineitems.part_id' => { -like => q{%}.shift( @_ ).q{%} } }, { join => 'lineitems' };
            },
            serial => sub {
               return { 'lineitems.serial' => { -like => q{%}.shift( @_ ).q{%} } }, { join => 'lineitems' };
            },
            id => sub {
               return { 'id' => shift }, {};
            },
            customer_id => sub {
               return { 'customer_id' => shift }, {};
            },
            repair_order_id => sub {
               return { 'repair_order_id' => { -like => q{%}.shift( @_ ).q{%} } }, {};
            },
         },$params
      );
   }

=head2 sort

  my $resultset = $self->schema->resultset('Foo');
  my $result = $self->sort($resultset);

=head3 Description

Exactly the same as search, except calls controller_sort.  Here is how I use it:

   # Base sort dispatcher, defined in MyApp::Schema::ResultSet
   sub _build_sort {
      my $self = shift;
      my $dispatch_table = shift;
      my $default = shift;
      my $q = shift;

      my %search = ();
      my %meta   = ();

      my $direction = $q->{dir};
      my $sort      = $q->{sort};

      if ( my $fn = $dispatch_table->{$sort} ) {
         my ( $tmp_search, $tmp_meta ) = $fn->( $direction );
         %search = ( %search, %{$tmp_search} );
         %meta   = ( %meta,   %{$tmp_meta} );
      } elsif ( $sort && $direction ) {
         my ( $tmp_search, $tmp_meta ) = $default->( $sort, $direction );
         %search = ( %search, %{$tmp_search} );
         %meta   = ( %meta,   %{$tmp_meta} );
      }

      return $self->search(\%search, \%meta);
   }

   # sort method in specific resultset
   sub controller_sort {
      my $self = shift;
      my $params = shift;
      return $self->_build_sort({
           first_name => sub {
              my $direction = shift;
              return {}, {
                 order_by => { "-$direction" => [qw{last_name first_name}] },
              };
           },
         }, sub {
        my $param = shift;
        my $direction = shift;
        return {}, {
           order_by => { "-$direction" => $param },
        };
         },$params
      );
   }

=head2 simple_deletion

  $self->simple_deletion({ rs => 'Foo' });

=head3 Description

Deletes from the passed in resultset based on the following CGI parameter:

  to_delete - values of the ids of items to delete

=head3 Valid arguments are:

  rs - resultset loaded into schema

Note that this method uses the $rs->delete method, as opposed to $rs->delete_all

=head2 simple_search

  my $searched_rs = $self->simple_search({ rs => 'Foo' });

=head3 Valid arguments are:

  rs - source loaded into schema

=head2 simple_sort

  my $resultset = $self->schema->resultset('Foo');
  my $sorted_rs = $self->simple_sort($resultset);

=head3 Description

Sorts the passed in resultset based on the following CGI parameters:

  sort - field to sort by, defaults to primarky key
  dir  - direction to sort

=cut

__END__
