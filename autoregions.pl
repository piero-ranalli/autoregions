#!/usr/bin/env perl
#

=head1 NAME

autoregions -- create sky.txt and bgsky.txt for cdfs-estract

=head1 USAGE

./autoregions.pl [--cached] [--maxsep=m]

=head1 DESCRIPTION

Given a catalogue of sources, stored in a database (currently
PostgreSQL), this programme computes extraction regions for its
companion programme cdfs-extract.

Source regions are circles, whose radii are chosen by maximizing the
expected signal/noise ratio, given the source counts and the
background surface brightnesses.  The signal/noise ratio is defined in
the same way as in the XMM-Newton SAS task eregionanalyse.

Background regions are annuli with inner and outer radii equal to 1.5
and 2 times, respectively, the source region radius.

Overlapping regions are identified, and excised unless they are too
close.

Using this program is easy, but it requires non-trivial preparation
steps. In particular it needs:

=over 4

* a PostgreSQL database holding the source information and the
haversine distance function;

* two files should be edited by the user: the PDL::PGSQL package
(which contains the access info to the database) and the Query
package (which contains the SQL queries);

* two Perl libraries need to be installed: PDL (including PDL::Minuit)
and Moose.

=back

Some documentation about the database is present in the README.SQL
file, and PostgreSQL is very easy to install. However, it is strongly
advised that the user contacts the author ( pranalli.github@gmail.com
) if there is any uncertainty about how to proceed.

For further information, see also the following papers:

* Ranalli, Georgantopoulos, Corral, et al. 2014, "The XMM-Newton
survey in the H-ATLAS field", submitted to Astronomy & Astrophysics

* Fotopoulou et al., in preparation

=head1 AUTHOR

Piero Ranalli

Post-doc researcher at IAASARS, National Observatory of Athens, Greece;
Associate of INAF -- Osservatorio Astronomico di Bologna, Italy.

pranalli.github@gmail.com

=head1 LICENSE

Copyright (C) 2014  Piero Ranalli

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU Affero General Public
License along with this program.  If not, see
<http://www.gnu.org/licenses/>.



=cut



#use Modern::Perl;
use strict;
use warnings;
use v5.010;

use PDL;
use Getopt::Long;

use Query;

use FindBin;
use lib "$FindBin::Bin/lib/";

use PDL::PGSQL;
use Autoregions;



$ENV{SAS_CCFPATH} = "$FindBin::Bin/lib/"; # for PSF.pm to find the CCF it wants
$/=1;

my $cached = 0;
my $maxseparation = 999999;  # arcmin
my $excludethresh = .5;      # arcmin; threshold below which exclusion regions are calculated

GetOptions( 'cached'   => \$cached,
	    'maxsep=f' => \$maxseparation,  # in arcmin
	  );

my ($xseq,$ra,$dec,$srcmos,$srcpn,$bkgmos,$bkgpn,$nndist) =
    $cached ? Query->reloadtable : Query->querydb;

my $reg = Autoregions->new;

open my $sky,   '> atlas-sky.txt';
$reg->sky($sky);
open my $bgsky, '> atlas-bgsky.txt';
$reg->bgsky($bgsky);
open my $ds9mos, '> atlas-spectra-mos.reg';
open my $ds9pn,  '> atlas-spectra-pn.reg';

my $ds9generic = <<DS9;
# Region file format: DS9 version 4.1
# XXL-N survey
global color=green dashlist=8 3 width=1 font="helvetica 10 normal roman" select=1 highlite=1 dash=0 fixed=0 edit=1 move=1 delete=1 include=1 source=1
fk5
DS9

print $ds9mos $ds9generic;
print $ds9pn $ds9generic;


for my $i (0..$xseq->dim(0)-1) {

    $reg->name( $xseq->at($i) );
    $reg->ra(  $ra->at($i)  );
    $reg->dec( $dec->at($i) );
    $reg->nndist( $nndist->at($i) );

    next if ($reg->nndist > $maxseparation);

    my $doexclude = $reg->nndist < $excludethresh;

    my ($exclude_reglist_mos, $exclude_reglist_pn) =
	Query->find_neighbours($reg->name,$reg->ra,$reg->dec,$excludethresh)
	    if $doexclude;

    # mos
    $reg->clear;
    $reg->srccts( $srcmos->at($i) );
    $reg->bkgbri( $bkgmos->at($i) );
    say $reg->name, $reg->nndist;
    say $#{$exclude_reglist_mos};

    $reg->exclude_reglist( $exclude_reglist_mos ) if ($doexclude and defined($exclude_reglist_mos) and @$exclude_reglist_mos);
    $reg->camera('EMOS1');
    $reg->check and $reg->fit;
    $reg->choosebkg;
    $reg->preparesky;
    $reg->prepareds9;
    $reg->write;
    $reg->writebkg;
    $reg->ds9($ds9mos);
    $reg->writeds9;
    $reg->log;
    $reg->camera('EMOS2');
    $reg->preparesky;
    $reg->write;
    $reg->writebkg;

    # pn
    $reg->clear;
    $reg->srccts( $srcpn->at($i) );
    $reg->bkgbri( $bkgpn->at($i) );
    $reg->exclude_reglist( $exclude_reglist_pn ) if ($doexclude and defined($exclude_reglist_pn) and @$exclude_reglist_pn);
    $reg->camera('EPN');
    $reg->check and $reg->fit;
    $reg->choosebkg;
    $reg->preparesky;
    $reg->write;
    $reg->writebkg;
    $reg->log;
    $reg->prepareds9;
    $reg->ds9($ds9pn);
    $reg->writeds9;

    $reg->clear_exclude_reglist;
}





__END__

