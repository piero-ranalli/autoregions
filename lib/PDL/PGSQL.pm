package PDL::PGSQL;

use 5.006;
use strict;
use warnings FATAL => 'all';
use DBI;
use Carp;

=head1 NAME

PDL::PGSQL - Read and write data in PostgreSQL database


=head1 NOTICE

Any user of autoregions should modify one line in the new() sub by putting his/her Postgres username and password (and port if needed), as follows:

    $self->{DBH} = DBI->connect(
	      "dbi:Pg:database=$db;host=localhost;port=5432",
	      '_YOUR_USERNAME_HERE_','_YOUR_PASSWORD_HERE_',{AutoCommit=>0}
    );

If you don't have a Postgres password, put an empty string (e.g.: '').




=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Version of XMMCDFS::SQL modified for postgres, and to work on
different databases

my $sql = PDL::PGSQL->new('dbname');  
                     # open connection to mysql xmmcdfs database,
                     # return SQL object

$sql->add( $tablename, \%record );   # add a record to $tablename


@lists   = $sql->getlists(   $sqlstat, $ncols );
@piddles = $sql->getpiddles( $sqlstat, $ncols );
           # execute ${sqlstat}ement and return a number $ncols 
           # of perl lists or piddles

my $dbh = $sql->getdbh;   # return the dbh to directly query the database

$sql->uploadfile({ FILE => 'mydata.dat',
                   TABLE=> 'mysqltable',
                   COLS => 'COL1,COL2'
                 });
    # uses LOAD DATA LOCAL INFILE to upload the content of mydata.dat
    # into mysqltable;
    # mydata.dat should be formatted with \t field delimiters;
    # COLS describe the data content.


=head1 BUGS

the add() and uploadfile() have not yet been translated to postgres!


=cut



sub new {

    my $class = shift;
    my $db = shift;


    my $self = {};
    my $allok = 1;

    $db // croak 'Database not specified';

    $self->{DBH} = DBI->connect(
	      "dbi:Pg:database=$db;host=localhost;port=5432",
	      'piero','',{AutoCommit=>0}
    );

    unless ($self->{DBH}) {
	    carp "Cannot connect to pgsql database $db.\n";
	    return(undef);
    }

    bless($self,$class);
    return($self);
}



sub add {
    my $self = shift;
    my $table = shift;
    my ($hash) = @_;

    my @fieldlist = map { $self->{DBH}->quote_identifier($_) } keys %$hash;
    my @valuelist = map { $self->{DBH}->quote($_) } values %$hash;

    my $query =
	" INSERT INTO ".$self->{DBH}->quote_identifier($table)." ( ".
		      join(',',@fieldlist).
		      " ) VALUES ( ".
		      join(',',@valuelist).
		      " ) ";
    my $sth = $self->{DBH}->prepare($query);
    $sth->execute();
    $sth->finish;
}









sub getpiddles {
    use PDL;

    my $self = shift;
    my @lists = $self->getlists(@_);

    my @piddles;
    push(@piddles, pdl($_)) for @lists;

    return @piddles;
}


sub getlists {
    use PDL;

    my $self = shift;
    my $sqlstat = shift;
    my $ncols = shift;

#    $ncols //= $self->parse_and_get_cols($sqlstat);
#    say $sqlstat;

    # my $sth = $dbh->prepare();
    # $sth->execute;

    # $sth->bind_columns( \(

    my @cols = 1..$ncols;
    my $aref = $self->{DBH}->selectcol_arrayref($sqlstat,{Columns=>\@cols});

    croak "Wrong number of columns" if (($#{$aref}+1) % $ncols);

    my @lists;
    for my $i (0..($ncols-1)) {

	my @list = ();
	my $n = $i;

	while ($n <= $#{$aref}) {

	    push(@list, $$aref[$n]);
	    $n += $ncols;

	}

	push (@lists, \@list);

    }

    return(@lists);
}


# sub parse_and_get_cols {
#     use SQL::Statement;

#     my $self = shift;
#     my $sql = shift;

#     $sql =~ s/;\s*$//;

#     my $parser = SQL::Parser->new;
#     $parser->{RaiseError}=1;
#     $parser->{PrintError}=0;
# #    $parser->parse("LOAD 'MyLib::MySyntax' ");
#     my $stmt = SQL::Statement->new($sql,$parser);

#     my $numcolumns = $stmt->column_defs();

#     return $numcolumns;
# }



sub getdbh {
    my $self = shift;
    return($self->{DBH});
}








sub uploadfile {
    my $self = shift;
    my $opt = shift;

    my $query = "load data local infile '".$$opt{FILE}."' into table ".$$opt{TABLE}.
	" (".$$opt{COLS}.");";

    my $sth = $self->{DBH}->prepare($query);
    $sth->execute;
    $sth->finish;

}






=head1 AUTHOR

Piero Ranalli, C<< <piero.ranalli at noa.gr> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2013 Piero Ranalli.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of PDL::PGSQL
