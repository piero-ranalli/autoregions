package Autoregions;

use Bestradius;

use Moose;
with 'Autoregions::RegionText';

has skip_neighbour_thresh => ( is => 'rw', isa => 'Num', default => .2 ); # arcmin

has sky   => ( is => 'rw', isa => 'FileHandle' );
has bgsky => ( is => 'rw', isa => 'FileHandle' );
has ds9   => ( is => 'rw', isa => 'FileHandle' );
has br    => ( is => 'rw', isa => 'Object', builder => 'loadBestradius' );

has name    => ( is => 'rw', isa => 'Str' );
has racorr  => ( is => 'rw', isa => 'Num' );
has deccorr => ( is => 'rw', isa => 'Num' );
has ra      => ( is => 'rw', isa => 'Num' );
has dec     => ( is => 'rw', isa => 'Num' );
has camera  => ( is => 'rw', isa => 'Str' );
has srccts  => ( is => 'rw', isa => 'Num' );
has bkgbri  => ( is => 'rw', isa => 'Num' );
has nndist  => ( is => 'rw', isa => 'Num' );

has exclude_reglist => ( is => 'rw', isa => 'ArrayRef[Autoregions]',
			 predicate => 'has_exclude_reglist',
			 clearer => 'clear_exclude_reglist',
		       );
has dist2main  => ( is => 'rw', isa => 'Num' );  # used by excluded regions


has checkok => ( is => 'rw', isa => 'Bool' );

has radius  => ( is => 'rw', isa => 'Num' );

has bkg_is_annulus => ( is => 'rw', isa => 'Bool', default => 1 );
has bkgra  =>         ( is => 'rw', isa => 'Num' );
has bkgdec =>         ( is => 'rw', isa => 'Num' );
has bkgradius1 =>     ( is => 'rw', isa => 'Num' );
has bkgradius2 =>     ( is => 'rw', isa => 'Num' );


sub loadBestradius {
    my $self = shift;
    $self->br( Bestradius->new );
}

sub clear {
    # clear flags and text
    my $self = shift;
    $self->cleartext;
    $self->checkok( 0 );
    $self->bkg_is_annulus( 1 );
};


sub check {
    # checks that source has positive counts, and that neirest neighbour
    # is at least 30" away
    my $self = shift;
    my $check = 1;

    if ($self->srccts <= 0) {
	$self->skip_0cts;
	$check = 0;
    }
    if ($self->nndist < $self->skip_neighbour_thresh) {
	$self->skip_hasneighbour;
	$check = 0;
    }

    if ($self->has_exclude_reglist) {
	my $r = $self->exclude_reglist;
	for my $i (0..$#$r) {
	    $$r[$i]->check;
	}
    }


    $self->checkok( $check );
    return $check;
}

sub fit {
    my $self = shift;
    $self->br->srccts( $self->srccts );
    $self->br->bkgbri( $self->bkgbri );
    $self->br->fit;

    if ($self->checkok) {
	$self->radius( $self->br->bestr );
    }

    if ($self->has_exclude_reglist) {
	my $r = $self->exclude_reglist;
	for my $i (0..$#$r) {
	    $$r[$i]->fit if ($$r[$i]->checkok);
	}
    }
}



sub choosebkg {
    my $self = shift;

    # we'll use an annulus with inner radius = 1.5 * source_radius
    # and outer_radius = 2 * source_radius
    #
    # this gives bkg_area = (2**2 - 1.5**2) * source_area = 1.75 * source_area
    #
    # however, this is conditioned on not having any other source, including a
    # 15" 'respect zone', inside the outer_radius

    my $outer = 2*$self->radius;
    if ($outer < 60*$self->nndist + 15) {
	$self->bkgradius1( 1.5*$self->radius );
	$self->bkgradius2( $outer );
	$self->bkgra( $self->ra );
	$self->bkgdec( $self->dec );

	my $eef1 = $self->br->psf->frac_in_radius( $self->bkgradius1 );
	my $eef2 = $self->br->psf->frac_in_radius( $outer );
	my $eef = $eef2 - $eef1;
	my $srccts_in_bkg_area = $self->srccts * $eef;
	$self->bkgcomment( sprintf(
	       "SRC_CONTRIB=%6.1f cts (%4.1f%% of PSF)",$srccts_in_bkg_area,100*$eef
				   )
			 );
    } else {
	$self->skip_bkgconflict;
	$self->checkok( 0 );
    }
}

1;


__PACKAGE__->meta->make_immutable;
