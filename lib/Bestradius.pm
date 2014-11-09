package Bestradius;

=head1 NAME

Bestradius.pm -- find the best extraction radius for XMM spectra

=head1 SYNOPSIS

my $br = Bestradius->new;
$br->srccts( 100 ); # source net counts
$br->bkgbri(   5 ); # bkg brightness (arcsec/pixel**2)
say $br->snr( 10 ); # calc SNR for given radius (in arcsec)

$br->fit;
say $br->bestr,$br->bestr_err,$br->bestsnr;  # best radius, with error, and best SNR


=head1 DESCRIPTION

Find best extraction radius given source and bkg counts, following
the same idea of
L<eregionanalyze|http://xmm.esac.esa.int/sas/current/doc/eregionanalyse/node32.html>:

=head2 ALGORITHM

   SNRMAX=0

   TOTAL_SRC_COUNTS = counts in the input image within the source region
                      corrected for the encircled energy fraction of the
                      source region

   Loop TEST_RADIUS = 1 to 300 arcseconds

      EEF = calculate encircled energy fraction for this TEST_RADIUS
             using the PSF relevant for this Epic camera at the
             position of the source box for a photon energy of 1.5 keV 

      SRC_COUNTS = TOTAL_SRC_COUNTS * EEF

      BGD_COUNTS = background counts per arcsec^2 * PI * TEST_RADIUS**2

      S/N ratio = SRC_COUNTS / sqrt(SRC_COUNTS + BGD_COUNTS)

      if (S/N ratio > SNRMAX) {
         SNRMAX = S/N ratio
      }

   EndLoop

=head2 IMPLEMENTATION

Since we cannot (yet) tune the region for different event files, a single
average combination of off-axis angle, energy and camera will be used.

We will choose PN, 2 keV, 6 arcmin off-axis.

Also we will fit instead of looping over radii.

=cut

use Modern::Perl;
use PDL;
use PDL::Minuit;
use Moose qw/has/;

use PSF;


has psf  => ( is => 'rw', isa => 'Object', builder => 'loadPSF' );
has rmin => ( is => 'rw', isa => 'Num',  default => 5   );  # in arcsec
has rmax => ( is => 'rw', isa => 'Num',  default => 300 );  # in arcsec

has bestr      => ( is => 'rw', isa => 'Num' );  # in arcsec
has bestr_err  => ( is => 'rw', isa => 'Num' );  # in arcsec
has bestsnr    => ( is => 'rw', isa => 'Num' );

has srccts => ( is => 'rw', isa => 'Num' ); # source net counts
has bkgbri => ( is => 'rw', isa => 'Num' ); # bkg brightness (cts/arcsec^2)


sub loadPSF {
    my $self = shift;
    my $psf = PSF->new(6,2,'EPN');
    $self->psf( $psf );
}


sub snr {
    my $self = shift;
    my $radius = shift;

    my $eef = $self->psf->frac_in_radius( $radius );
    my $srccts_in_psf = $self->srccts * $eef;
    my $bkgcts_in_psf = $self->bkgbri * 3.141592 * $radius**2;

    my $snr = $srccts_in_psf / sqrt( $srccts_in_psf + $bkgcts_in_psf );
    return $snr;
}


sub fit {
    my $self = shift;

    mn_init( $self->calc_snr );
    my $iflag = mn_def_pars( pdl(10), pdl(1),
			     { Lower_bounds => pdl($self->rmin),
			       Upper_bounds => pdl($self->rmax),
			     } );

    $iflag = mn_excm('simplex');
    my ($val,$err) = mn_pout(1);

    $self->bestr( $val->sclr );
    $self->bestr_err( $err->sclr );
    $self->bestsnr( $self->snr( $val->sclr ) );
}



sub calc_snr {
    my $self = shift;

    return sub {
	# the five variables input to the function to be minimized
	# xval is a piddle containing the current values of the parameters
	my ($npar,$grad,$fval,$xval,$iflag) = @_;

	$fval = - $self->snr( $xval->at(0) ); #minus since we need to maximize SNR

	# return the two variables. If no gradient is being computed
	# just return the $grad that came as input
	return ($fval, $grad);
    }
}

1;


__PACKAGE__->meta->make_immutable;
