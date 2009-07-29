package CAPDBICTest::Schema::ResultSet::Stations;
use parent 'DBIx::Class::ResultSet';
use strict;
use warnings;

sub controller_search {
   my $self = shift;
   return $self->search;
}

sub controller_sort {
   my $self = shift;
   return $self->search;
}

1;
