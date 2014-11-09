package Query;

=head1 NAME

Query.pm -- Query a catalogue to get sources and neighbours

=head1 SYNOPSYS

 my ($xseq,$ra,$dec,$srcmos,$srcpn,$bkgmos,$bkgpn,$nndist) =
    $cached ? Query->reloadtable : Query->querydb;

 my ($exclude_reglist_mos, $exclude_reglist_pn) =
    Query->find_neighbours($reg->name,$reg->ra,$reg->dec,$excludethresh);

=head1 DESCRIPTION

This package contains the SQL queries needed by autoregions to get the
coordinates of sources and their neighbours.

The user should edit this file and adapt it to his/her own needs. In
particular, the following things should be edited:

=over 4

* SQL queries in querydb() and in find_neighbours(); a correspondence
between the database columns and the variables returned by
getpiddles() should be mantained (hint: if you rearrange the columns,
you must also rearrange the order of the varables);

* the PDL::PGSQL module, which contains the username and password to
connect to the database.

=back

Furthermore, the code below assumes all counts are MOS1+MOS2+PN, as in
XMM-ATLAS (the user should check that this assumption is valid, or
change the code).


=head1 AUTHOR

(c)  2014  Piero Ranalli    pranalli.github@gmail.com

=head1 LICENSE

See autoregions.pl

=cut






use Moose qw/has/; # no attributes, just some class methods
use PDL;
use v5.010;

use FindBin;
use lib "$FindBin::Bin/lib/";

use PDL::PGSQL;
use Autoregions;



sub querydb {
    my $self = shift;
    my $query = shift;

    my $writecache = not defined($query);  # only write cache for default query!
    $query //= <<SQL2;
select id,ra,dec_,coalesce(scts058,scts28,scts052),coalesce(bg_map058,bg_map28,bg_map052),nndist
from catalogueml
where coalesce(scts058,scts28,scts052)>=40
order by -coalesce( flux058, flux28, flux052 )
;
SQL2

    my $sql = PDL::PGSQL->new('atlas');
    my ($seq,$ra,$dec,$src,$bkg,$nndist) =
	$sql->getpiddles( $query, 6 );

    for ($src,$bkg) {
	say 'negative counts!' if (any($_<0));
    }

    # ATLAS was analyzed after summing the cameras. So to get mos and pn counts, we
    # rely on the average effective area, for which one mos is 1/3 of pn
    my $srcmos = .33 * $src;
    my $srcpn  = .67 * $src;
    my $bkgmos = .33 * $bkg;
    my $bkgpn  = .67 * $bkg;

    # save for faster reload
    my %tbl = ( SEQ => $seq,
		RA => $ra,
		DEC => $dec,
		SRCMOS => $srcmos,
		SRCPN => $srcpn,
		BKGMOS => $bkgmos,
		BKGPN => $bkgpn,
		NNDIST => $nndist,
	      );

    wfits(\%tbl,'autoregions-cachedtable.fits');
    return ($seq,$ra,$dec,$srcmos,$srcpn,$bkgmos,$bkgpn,$nndist);
}

sub reloadtable {
    my $self = shift;

    my $tbl = rfits('autoregions-cachedtable.fits');
    return ($tbl->{SEQ},$tbl->{RA},$tbl->{DEC},$tbl->{SRCMOS},$tbl->{SRCPN},$tbl->{BKGMOS},$tbl->{BKGPN},$tbl->{NNDIST});
}



sub find_neighbours {
    my ($self, $sname, $sra, $sdec, $excludethresh) = @_;

    my $query = <<SQL1;
select id,ra,dec_,coalesce(scts058,scts28,scts052),coalesce(bg_map058,bg_map28,bg_map052),
       haversine(ra,dec_,$sra,$sdec)/3.141592*180*60 as dist
from catalogueml
where id!=$sname
and ra<$sra+$excludethresh
and ra>$sra-$excludethresh
and dec_<$sdec+$excludethresh
and dec_>$sdec-$excludethresh
and haversine(ra,dec_,$sra,$sdec)/3.141592*180*60 < $excludethresh
;
SQL1

    my ($seq,$ra,$dec,$srcmos,$srcpn,$bkgmos,$bkgpn,$dist) = $self->querydb($query);

    return if ($seq->dim(0) == 0);  # no need to exclude anything

    my (@regmos,@regpn);
    for my $i (0..$seq->dim(0)-1) {
	my $rm = Autoregions->new;
	$rm->name( $seq->at($i) );
	$rm->ra(   $ra->at($i) );
	$rm->dec(  $dec->at($i) );
	$rm->nndist( 99999 );
	$rm->dist2main( $dist->at($i) );
	$rm->srccts( $srcmos->at($i) );
	$rm->bkgbri( $bkgmos->at($i) );

	my $rp = Autoregions->new;
	$rp->name( $seq->at($i) );
	$rp->ra(   $ra->at($i) );
	$rp->dec(  $dec->at($i) );
	$rp->nndist( 99999 );
	$rp->dist2main( $dist->at($i) );
	$rp->srccts( $srcpn->at($i) );
	$rp->bkgbri( $bkgpn->at($i) );

	push @regmos, $rm;
	push @regpn,  $rp;
    }
    return \@regmos, \@regpn;
}


1;
