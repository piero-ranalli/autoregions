autoregions
===========

Define source and background extraction regions with maximum signal/noise ratio, to be used with cdfs-extract to extract XMM-Newton spectra.


USAGE
=====

./autoregions.pl \[--cached\] \[--maxsep=m\]

DESCRIPTION
===========

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

Using this program is easy, but the documentation is currently
incomplete, and laso it requires non-trivial preparation steps.
Therefore, it is strongly advised that the user contacts the author (
pranalli.github@gmail.com ) if there is any uncertainty about how to
proceed.

In particular, the user shuold:

    \* setup a PostgreSQL database holding the source information and
    the haversine distance function;

    \* edit two files: the PDL::PGSQL package (which contains the
    access info to the database) and the Query package (which contains
    the SQL queries; more info can be obtained with the command
    "perldoc Query.pm");

    \* install two Perl libraries: PDL (including PDL::Minuit) and
    Moose. These are available in the repositories of most Linux
    distributions and (for Mac users) in Macports.

Some documentation about the database is present in the README.SQL
file, and PostgreSQL is very easy to install. 


For further information, see also the following papers:

\* Ranalli, Georgantopoulos, Corral, et al. 2014, "The XMM-Newton
survey in the H-ATLAS field", submitted to Astronomy & Astrophysics

\* Fotopoulou et al., in preparation

# SIGNAL/NOISE RATIO MAXIMIZATION

Find best extraction radius given source and bkg counts, following
the same idea of
[eregionanalyze](http://xmm.esac.esa.int/sas/current/doc/eregionanalyse/node32.html):

## ALGORITHM

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

## IMPLEMENTATION

Since we cannot (yet) tune the region for different event files, a single
average combination of off-axis angle, energy and camera will be used.

We will choose PN, 2 keV, 6 arcmin off-axis.

The fit is done with Minuit (through PDL::Minuit).




# AUTHOR

Piero Ranalli

Post-doc researcher at IAASARS, National Observatory of Athens, Greece;
Associate of INAF -- Osservatorio Astronomico di Bologna, Italy.

pranalli.github@gmail.com

# LICENSE

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




