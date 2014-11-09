package Autoregions::RegionText;

use Moose::Role;

has texttowrite =>    ( is => 'rw', isa => 'Str' );
has bkgtexttowrite => ( is => 'rw', isa => 'Str' );
has ds9towrite  =>    ( is => 'rw', isa => 'Str' );

has bkgcomment  =>    ( is => 'rw', isa => 'Str' );


sub cleartext {
    my $self = shift;
    $self->texttowrite( '' );
    $self->bkgtexttowrite( '' );
    $self->ds9towrite( '' );
    $self->bkgcomment( '' );
}

sub log {
    my $self = shift;

    print $self->texttowrite;
}


sub addtotext {
    my $self = shift;

    $self->texttowrite(
		       $self->texttowrite.shift."\n"
		      );
}

sub addtobkgtext {
    my $self = shift;

    $self->bkgtexttowrite(
		       $self->bkgtexttowrite.shift."\n"
		      );
}

sub addtods9 {
    my $self = shift;

    $self->ds9towrite(
		       $self->ds9towrite.shift."\n"
		      );
}


sub write {
    my $self = shift;
    my $fh = $self->sky;

    print $fh $self->texttowrite;
    $self->texttowrite( '' );
}

sub writebkg {
    my $self = shift;
    my $fh = $self->bgsky;

    print $fh $self->bkgtexttowrite;
    $self->bkgtexttowrite( '' );
}

sub writeds9 {
    my $self = shift;
    my $fh = $self->ds9;

    print $fh $self->ds9towrite;
    $self->ds9towrite( '' );
}


sub skip_0cts {
    my $self = shift;
    $self->addtotext(
	"# skipping xseq=".$self->name." because it has zero counts in ".$self->camera
	     );
}


sub skip_hasneighbour {
    my $self = shift;
    $self->addtotext(
	"# skipping xseq=".$self->name." because it has nearest neighbour at ".$self->nndist." arcmin"
		    );
}


sub preparesky {
    # prepare region text when checks are ok
    my $self = shift;

    return unless $self->checkok;

    my $comment = sprintf("SNR=%7.1f", $self->br->bestsnr);
    $self->addtotext(
		     sprintf("xseq%06i %10f %10f %5.1f  %5s # %s",
			     $self->name,$self->ra,$self->dec,$self->radius,
			     $self->camera,$comment
			    )
		    );


    $self->addtobkgtext(
			sprintf("xseq%06i %10f %10f %5.1f %5.1f %5s # %s",
				$self->name,$self->bkgra,$self->bkgdec,
				$self->bkgradius1, $self->bkgradius2,
				$self->camera,$self->bkgcomment
			       )
		       );

    if ($self->has_exclude_reglist) {
	my $r = $self->exclude_reglist;

	for my $i (0..$#$r) {
	    my $comment = sprintf("excluded neighbour at %5.2f'",$$r[$i]->dist2main);
	    $self->addtotext(
			     sprintf("xseq%06i exclude %10f %10f %5.1f  %5s # %s",
				     $self->name,$$r[$i]->ra,$$r[$i]->dec,$$r[$i]->radius,
				     $self->camera,$comment
				    )
			    );
	    $self->addtobkgtext(
			     sprintf("xseq%06i exclude %10f %10f %5.1f  %5s # %s",
				     $self->name,$$r[$i]->ra,$$r[$i]->dec,$$r[$i]->radius,
				     $self->camera,$comment
				    )
			    );

	}
    }
}

sub prepareds9 {
    # prepare region text when checks are ok
    my $self = shift;

    return unless $self->checkok;


    $self->addtods9(
		    sprintf("circle(%10f,%10f,%5.1f\") # text={xseq%06i}",
			    $self->ra,$self->dec,$self->radius,$self->name
			   )
		   );
    $self->addtods9(
		    sprintf("annulus(%10f,%10f,%5.1f\",%5.1f\") # text={xseq%06i} background",
			    $self->ra,$self->dec,$self->bkgradius1,$self->bkgradius2,$self->name
			   )
		   );
}


sub skip_bkgconflict {
    my $self = shift;
    $self->addtotext(
		     sprintf("# skipping xseq%06i because it has nearest neighbour at %4.2f' (radius would be %4.2f\")",$self->name,$self->nndist,$self->radius)
		    );
    $self->addtobkgtext(
			sprintf("# skipping xseq%06i because it has nearest neighbour at %4.2f' (outer radius would be %4.2f\")",$self->name,$self->nndist,$self->bkgradius2)
		       );
}

1;
