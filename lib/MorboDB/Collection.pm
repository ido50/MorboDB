package MorboDB::Collection;

# ABSTRACT: [One line description of module's purpose here]

use Any::Moose;
use boolean;
use Carp;
use Clone qw/clone/;
use MorboDB::Cursor;
use MQUL qw/update_doc/;

our $VERSION = "0.001";
$VERSION = eval $VERSION;

=head1 NAME

MorboDB - [One line description of module's purpose here]

=head1 SYNOPSIS

	use MorboDB;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.

=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.

=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.

=cut

has 'name' => (is => 'ro', isa => 'Str', required => 1);

has 'full_name' => (is => 'ro', isa => 'Str', lazy_build => 1);

has '_database' => (is => 'ro', isa => 'MorboDB::Database', required => 1, weak_ref => 1);

has '_data' => (is => 'ro', isa => 'HashRef', default => sub { {} }, clearer => '_clear_data');

sub to_index_string {
	# this function is just stolen as-is from MongoDB::Collection
	my $keys = shift;

	my @name;
	if (ref $keys eq 'ARRAY' || ref $keys eq 'HASH') {
		while ((my $idx, my $d) = each(%$keys)) {
			push @name, $idx;
			push @name, $d;
		}
	} elsif (ref $keys eq 'Tie::IxHash') {
		my @ks = $keys->Keys;
		my @vs = $keys->Values;
		@vs = $keys->Values;

		for (my $i=0; $i<$keys->Length; $i++) {
			push @name, $ks[$i];
			push @name, $vs[$i];
		}
	} else {
		confess 'expected Tie::IxHash, hash, or array reference for keys';
	}

	return join('_', @name);
}

sub find {
	my ($self, $query) = @_;

	confess "Query must be a hash reference."
		if $query && ref $query ne 'HASH';

	$query ||= {};

	return MorboDB::Cursor->new(_coll => $self, _query => $query);
}

sub query { shift->find(@_) }

sub find_one { shift->find(@_)->limit(1)->next }

sub insert { ($_[0]->batch_insert([$_[1]]))[0] }

sub batch_insert {
	my ($self, $docs) = @_;

	confess "batch_insert() expects an array reference of documents."
		unless $docs && ref $docs eq 'ARRAY';

	foreach my $doc (@$docs) {
		confess "Data to insert must be a hash reference."
			unless $doc && ref $doc eq 'HASH';

		confess "You must provide an ID (for now)."
			unless $doc->{_id};

		confess "Duplicate key error, ID $doc->{_id} already exists in the collection."
			if exists $self->_data->{$doc->{_id}};
	}

	return map { $self->save($_) } @$docs;
}

sub update {
	my ($self, $query, $update, $opts) = @_;

	confess "The query structure must be a hash reference."
		if $query && ref $query ne 'HASH';

	$query ||= {};

	confess "The update structure must be a hash reference."
		unless $update && ref $update eq 'HASH';

	confess "The options structure must be a hash reference."
		if $opts && ref $opts ne 'HASH';

	$opts ||= {};

	my @docs;
	if ($opts->{multiple}) {
		@docs = $self->find($query)->all;
	} else {
		my $doc = $self->find_one($query);
		push(@docs, $doc) if $doc;
	}

	if (scalar @docs == 0 && $opts->{upsert}) {
		# take attributes from the query where appropriate
		my $doc = {};
		foreach (keys %$query) {
			next if $_ eq '_id';
			$doc->{$_} = $query->{$_}
				if !ref $query->{$_};
		}
		my $id = $self->save(update_doc($doc, $update));
		return {
			ok => 1,
			n => 1,
			upserted => $id,
			updatedExisting => false,
			wtime => 0,
		};
	} else {
		foreach (@docs) {
			$self->save(update_doc($_, $update));
		}
		return {
			ok => 1,
			n => scalar @docs,
			updatedExisting => true,
			wtime => 0,
		};
	}
}

sub remove {
	my ($self, $query, $opts) = @_;

	confess "The query structure must be a hash reference."
		if $query && ref $query ne 'HASH';

	confess "The options structure must be a hash reference."
		if $opts && ref $opts ne 'HASH';

	$query ||= {};
	$opts ||= {};

	my @docs = $opts->{just_one} ? ($self->find_one($query)) : $self->find($query)->all;
	foreach (@docs) {
		delete $self->_data->{$_->{_id}};
	}

	return {
		ok => 1,
		n => scalar @docs,
		wtime => 0,
	};
}

sub ensure_index { 1 } # not implemented

sub save {
	my ($self, $doc) = @_;

	confess "Document to save must be a hash reference."
		unless $doc && ref $doc eq 'HASH';

	$self->_data->{$doc->{_id}} = clone($doc);

	return $doc->{_id};
}

sub count {
	my ($self, $query) = @_;

	$self->find($query)->count;
}

sub validate { {} } # not implemented

sub drop_indexes { 1 } # not implemented

sub drop_index { 1 } # not implemented

sub get_indexes { return } # not implemented

sub drop {
	my $self = shift;

	$self->_clear_data;
	delete $self->_database->_colls->{$self->name};
	return;
}

sub AUTOLOAD {
	my $self = shift;

	our $AUTOLOAD;
	my $coll = $AUTOLOAD;
	$coll =~ s/.*:://;

	return $self->_database->get_collection($self->name.'.'.$coll);
}

sub _build_full_name { $_[0]->_database->name.'.'.$_[0]->name }

=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back

=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
MorboDB requires no configuration files or environment variables.

=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.

=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.

=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-MorboDB@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MorboDB>.

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
