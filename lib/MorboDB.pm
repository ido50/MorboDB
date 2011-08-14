package MorboDB;

# ABSTRACT: In-memory database, mostly-compatible clone of MongoDB

use Any::Moose;
use Carp;
use MorboDB::Database;

our $VERSION = "0.001";
$VERSION = eval $VERSION;

=head1 NAME

MorboDB - In-memory database, mostly-compatible clone of MongoDB

=head1 SYNOPSIS

	use MorboDB;

=head1 DESCRIPTION

MorboDB is an in-memory database, meant to be a mostly-compatible clone
of Perl's L<MongoDB> driver that can be used to replace or supplement
it in applications where it might be useful.

=head2 USE CASES

An in-memory database can be useful for many purposes. A common use case
is testing purposes. You can already find a few in-memory databases on
CPAN, such as L<MMapDB>, L<DB_File|DB_File/"In_Memory_Databases"> (has optional
support for in-memory databases) and L<KiokuDB> (which has an in-memory
hash serializer). I'm sure there are others more.

I decided to develop MorboDB for two main purposes:

=over

=item * MongoDB disaster fallback - at work I am currently developing a
very critical application that uses MongoDB (with replica-sets setup) as
a database backend. This application cannot afford to suffer downtimes.
The application's database has some constant data (not too much) that shouldn't change
which is completely required for it to work. Most of the data, dynamically
written due to user's work, is not as important so it wouldn't matter if
the database won't be able to take such writes for some time. Therefore,
I have decided to build a fail-safe: when the application is launched (actually
I haven't decided yet if on launch or not), the constant data is loaded into
MorboDB, which silently waits in the background. If for some reason the
MongoDB database crashes, the application switches to MorboDB and the application
continues to work - the user's don't even notice something happend. Since
MorboDB provides mostly the same syntax as MongoDB, this isn't very far-fetched
codewise.

=item * Delayed writes and undos - I am also working on a content management
system in which I want to allow users to undo changes for a certain duration
(say 30 seconds) after the changes have been made. MorboDB can work as
a bridge between the application and the actual MongoDB database (or whatever
actually). Data only lives in MorboDB for 30 seconds. If the user decides
to undo, the data is removed and nothing happens. Otherwise, the data is
moved to MongoDB after the 30 seconds are over.

=back

=head2 MOSTLY-COMPATIBLE?

As I've mentioned, MorboDB is "mostly-compatible" with L<MongoDB>. First
of all, a lot of things that are relevant for MongoDB are not relevant for
in-memory database. Some things aren't supported and probably never will,
like GridFS for example. Otherwise, the syntax is almost completely the
same (by relying on L<MQUL>), apart for some changes detailed in both
L<MQUL::Reference/"NOTABLE_DIFFERENCES_FROM_MONGODB"> and L</"INCOMPATIBILITIES WITH MONGODB">.

I have provided most methods provided by relevant MongoDB modules, even where
they're not really implemented (in which case they either return 1 or an
undefined value). Read the documentation of MorboDB's different modules
for information on every method and whether it's implemented or not. These
methods are only provided to make it possible to use MorboDB as a drop-in
replacement of MongoDB where appropriate (so you don't get "undefined subroutine"
errors). Please let me know if there are methods you need (even unimplemented)
that I haven't provided.

=head2 STATUS

This module is beta software, not suitable for production use yet. Feel
free to test it and let me know how it works for you (of course, not on
production), I'd be happy to receive any bug reports, requests, ideas, etc.

=cut

has '_dbs' => (is => 'ro', isa => 'HashRef[MorboDB::Database]', default => sub { {} });

=head1 OBJECT METHODS

=head2 database_names()

Returns a list with the names of all existing databases.

=cut

sub database_names { sort keys %{$_[0]->_dbs} }

=head2 get_database( $name )

Returns a L<MorboDB::Database> object with the given name. There are two
ways to call this method:

	my $morbodb = MorboDB->new;
	
	my $db = $morbodb->get_database('mydb');
	# or
	my $db = $morbodb->mydb; # just like MongoDB

=cut

sub get_database {
	my ($self, $name) = @_;

	confess "You must provide the name of the database to get."
		unless $name;

	return $self->_dbs->{$name} ||= MorboDB::Database->new(_top => $self, name => $name);
}

=head2 get_master()

Not implemented, simply returns a true value here.

=cut

sub get_master { 1 } # not implemented

sub AUTOLOAD {
	my $self = shift;

	our $AUTOLOAD;
	my $db = $AUTOLOAD;
	$db =~ s/.*:://;

	return $self->get_database($db);
}

=head1 CAVEATS

Currently (not sure if this will change), MorboDB does not work in shared
memory, so if your application is multi-threaded, every thread will have
its own MorboDB container completely separate and unaware of other threads.

=head1 DIAGNOSTICS

This module throws the following errors:

=item C<< "You must provide the name of the database to get." >>

Thrown by C<get_database()> if you don't provide it with the name of the
database you want to get/create.

=back

=head1 CONFIGURATION AND ENVIRONMENT
  
MorboDB requires no configuration files or environment variables.

=head1 DEPENDENCIES

MorboDB depends on the following CPAN modules:

=over

=item * L<Any::Moose>

=item * L<boolean>

=item * L<Clone>

=item * L<Data::UUID>

=item * L<MQUL>

=item * L<Tie::IxHash>

=back

=head1 INCOMPATIBILITIES WITH MONGODB

=head1 INCOMPATIBILITIES WITH OTHER MODULES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-MorboDB@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MorboDB>.

=head1 SEE ALSO

L<MongoDB>, L<MongoDB::Connection>, L<MQUL>, L<MQUL::Reference>.

=head1 AUTHOR

Ido Perlmuter <ido@ido50.net>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2011, Ido Perlmuter C<< ido@ido50.net >>.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself, either version
5.8.1 or any later version. See L<perlartistic|perlartistic> 
and L<perlgpl|perlgpl>.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

__PACKAGE__->meta->make_immutable;
__END__
