package Device::SDM3055;


use 5.032001;
use strict;
use warnings;

our $VERSION = '0.01';

use Carp;
use Lab::VXI11;

sub new
{
  my ( $class, $addr ) = @_;
  my $self = {};
  bless( $self , $class );

  $self->{addr} = $addr;

  $self->{dev} = Lab::VXI11->new( $addr, DEVICE_CORE, DEVICE_CORE_VERSION, 'tcp' )
       || croak "Can't connect to VXI device at $addr: $!\n";

  my ( $error, $lid, $abortPort, $maxRecvSize ) = $self->{dev}->create_link( 0, 0, 0, 'inst0' );
  if( $error != 0 ) {
    croak "Fail to create VXI link, error= $error";
  }
  $self->{lid}         = $lid;
  $self->{abortPort}   = $abortPort;
  $self->{maxRecvSize} = $maxRecvSize;
  $self->{timeout}     = 3000;
  $self->{error}       = 0;
  $self->{reason}      = 0;
  $self->{data}        = '';
  $self->{size}        = 0;
  $self->{debug}       = 0;

  return $self;
}

sub getDev
{
  my $self = shift;
  return $self->{dev};
}

sub getLid
{
  my $self = shift;
  return $self->{lid};
}

sub getData
{
  my $self = shift;
  return $self->{data};
}

sub getError
{
  my $self = shift;
  return $self->{error};
}

sub sendCmd
{
  my( $self, $cmd ) = @_;
  my $need_repl = substr( $cmd, -1, 1 ) eq '?';

  if( $self->{debug} > 1 ) {
    carp( "VXI  cmd=\"" . $cmd . "\"" );
  }

  ( $self->{error}, $self->{size} ) = $self->{dev}->device_write( $self->{lid}, $self->{timeout}, 0, 0x08, $cmd );
  if( $self->{error} != 0 ) {
    carp( "Fail to write VXI cmd. error= " . $self->{error} . " cmd=\"" . $cmd . "\"" );
    return 0;
  }

  if( !$need_repl ) {
    return 1;
  }

  $self->{data} = '';
  ( $self->{error}, $self->{reason}, $self->{data} )
   = $self->{dev}->device_read( $self->{lid}, $self->{maxRecvSize}, $self->{timeout}, 0, 0, 0 );

  if( $self->{error} != 0 ) {
    carp( "Fail to read VXI data: error= " . $self->{error} . " cmd=\"" . $cmd . "\"" );
    return 0;
  }

  chomp $self->{data};

  if( $self->{debug} > 1 ) {
    carp( "VXI  repl=\"" . $self->{data} . "\"" );
  }

  my @datas = split( ',', $self->{data} );
  foreach my $cdat ( @datas ) {
    $cdat = ( 0.0 + $cdat );
  }

  return @datas;
}

sub getNextDatas
{
  my( $self, $xxx ) = @_;
  my $cmd = "INIT;FETCH?";
  return $self->sendCmd( $cmd );
}

my %measure_name = (
    'V'    => 'VOLT:DC ',
    'VDC'  => 'VOLT:DC ',
    'VAC'  => 'VOLT:AC ',
    'VA'   => 'VOLT:AC ',
    'R'    => 'RES ',
    'OHM'  => 'RES ',
    'R4'   => 'FRES ',
    'OHM4' => 'FRES ',
    'I'    => 'CURR:DC ',
    'IDC'  => 'CURR:DC ',
    'IAC'  => 'CURR:AC ',
    'IA'   => 'CURR:AC ',
    'F'    => 'FREQ ',
    'HZ'   => 'FREQ ',
    'T'    => 'PER ',
    'PER'  => 'PER ',
);

sub getMeasureNamesStr
{
  # no self
  my $s = '';
  my $sep = '';
  while( my ($key,$val) = each( %measure_name )  ) {
    $s .= $sep . $key;
    $sep = ', ';
  }

  return $s;

}

sub setMeasure
{
  my( $self, $m, $range ) = @_;
  my $m_u = uc( $m );

  if( defined $measure_name{$m_u} ) {
    $m = $measure_name{$m_u};
  }

  my $cmd = 'CONF:' . $m;
  if( $range ) {
    $cmd .= $range;
  }
  $cmd .= ';';
  return $self->sendCmd( $cmd );

}

sub setSamples
{
  my( $self, $samp ) = @_;
  my $cmd = 'SAMP:COUNT ' . int($samp) . ';';
  return $self->sendCmd( $cmd );
}

sub DESTROY
{
  my $self = shift;
  $self->sendCmd( 'ABORT;*CLS' );
  $self->{dev}->device_clear( $self->{lid}, 0x8, $self->{timeout}, $self->{timeout} );
  my $err = $self->{dev}->device_local( $self->{lid}, 0x8, $self->{timeout}, $self->{timeout} );
  # carp( "destroy err= $err\n" );
  $self->{dev}->destroy_link( $self->{lid} );
  return;
}

1;
__END__

=head1 NAME

Device-SDM3055 - Perl extension to control Siglent SDM3055 multimeter via VXI/TCP

=head1 SYNOPSIS

  use Device-SDM3055;

=head1 DESCRIPTION

See SYNOPSIS and code for now - not a stable interface


=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Anton Guda, E<lt>atu@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 by Anton Guda

This library is free software; you can redistribute it and/or modify
it under the same terms of GPLv3


=cut
