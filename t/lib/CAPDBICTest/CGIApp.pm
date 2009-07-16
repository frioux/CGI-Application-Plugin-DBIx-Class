package CAPDBICTest::CGIApp;
use strict;
use warnings;

use parent 'CGI::Application';

use CAPDBICTest::Schema;

use CGI::Application::Plugin::DBIx::Class ':all';

sub cgiapp_init {
  my $self = shift;
}

sub setup {
    my $self = shift;

    $self->start_mode('test_mode');

    $self->run_modes(test_mode => 'test_mode' );
}

sub test_mode {
  my $self = shift;
  return 1;
}


1;
