package MorboDB::Cursor;

# ABSTRACT: [One line description of module's purpose here]

use Any::Moose;
use Carp;
use Clone qw/clone/;
use MQUL qw/doc_matches/;
use Tie::IxHash;

our $VERSION = "0.001";
$VERSION = eval $VERSION;

has 'started_iterating' => (is => 'ro', isa => 'Bool', default => 0, writer => '_set_started_iterating');

has 'immortal' => (is => 'rw', isa => 'Bool', default => 0); # unimplemented

has 'tailable' => (is => 'rw', isa => 'Bool', default => 0); # unimplemented

has 'partial' => (is => 'rw', isa => 'Bool', default => 0); # unimplemented

has 'slave_okay' => (is => 'rw', isa => 'Bool', default => 0); # unimplemented

has '_coll' => (is => 'ro', isa => 'MorboDB::Collection', required => 1);

has '_query' => (is => 'ro', isa => 'HashRef', required => 1);

has '_fields' => (is => 'ro', isa => 'HashRef', writer => '_set_fields', clearer => '_clear_fields');

has '_limit' => (is => 'ro', isa => 'Int', default => 0, writer => '_set_limit', clearer => '_clear_limit');

has '_skip' => (is => 'ro', isa => 'Int', default => 0, writer => '_set_skip', clearer => '_clear_skip');

has '_sort' => (is => 'ro', isa => 'Tie::IxHash', predicate => '_has_sort', writer => '_set_sort', clearer => '_clear_sort');

has '_docs' => (is => 'ro', isa => 'ArrayRef[Str]', writer => '_set_docs', clearer => '_clear_docs');

has '_index' => (is => 'ro', isa => 'Int', default => 0, writer => '_set_index');

sub fields {
	my ($self, $f) = @_;

	confess 'cannot set fields after querying'
		if $self->started_iterating;

	confess 'not a hash reference'
		unless ref $f && ref $f eq 'HASH';

	$self->_set_fields($f);

	return $self;
}

sub limit {
	my ($self, $num) = @_;

	confess 'cannot set limit after querying'
		if $self->started_iterating;

	$self->_set_limit($num);

	return $self;
}

sub skip {
	my ($self, $num) = @_;

	confess 'cannot set skip after querying'
		if $self->started_iterating;

	$self->_set_skip($num);

	return $self;
}

sub sort {
	my ($self, $order) = @_;

	confess 'cannot set sort after querying'
		if $self->started_iterating;

	confess 'not a hash reference'
		unless ref $order && (ref $order eq 'HASH' || ref $order eq 'Tie::IxHash');

	if (blessed $order eq 'Tie::IxHash') {
		$self->_set_sort($order);
	} elsif (ref $order eq 'HASH') {
		my $obj = Tie::IxHash->new;
		foreach (keys %$order) {
			$obj->Push($_ => $order->{$_});
		}
		$self->_set_sort($obj);
	} else {
		confess 'sort() needs a Tie::IxHash object, a hash reference, or an even-numbered array reference.';
	}

	return $self;
}

sub snapshot {
	# NOT IMPLEMENTED YET (IF EVEN SHOULD BE)
	1;
}

sub explain {
	# NOT IMPLEMENTED YET
	1;
}

sub reset {
	my $self = shift;

	$self->_set_started_iterating(0);
	$self->_clear_fields;
	$self->_clear_limit;
	$self->_clear_skip;
	$self->_clear_sort;
	$self->_clear_docs;
	$self->_set_index(0);

	return 1;
}

sub info {
	# NOT IMPLEMENTED YET
	{};
}

sub count {
	my $self = shift;

	unless ($self->started_iterating) {
		# haven't started iterating yet, let's query the database
		$self->_query_db;
	}

	return scalar @{$self->_docs};
}

sub has_next {
	my $self = shift;

	unless ($self->started_iterating) {
		# haven't started iterating yet, let's query the database
		$self->_query_db;
	}

	return $self->_index < $self->count;
}

sub next {
	my $self = shift;

	# return nothing if we've started iterating but have no more results
	return if $self->started_iterating && !$self->has_next;

	unless ($self->started_iterating) {
		# haven't started iterating yet, let's query the database
		$self->_query_db;
		return unless $self->count;
	}

	my $doc = clone($self->_coll->_data->{$self->_docs->[$self->_index]});
	$self->_inc_index;

	if ($self->_fields) {
		my $ret = {};
		foreach (keys %{$self->_fields}) {
			$ret->{$_} = $doc->{$_}
				if exists $self->_fields->{$_};
		}
		return $ret;
	} else {
		return $doc;
	}
}

sub all {
	my $self = shift;

	my @docs;
	while ($self->has_next) {
		push(@docs, $self->next);
	}

	return @docs;
}

sub _query_db {
	my $self = shift;

	my @docs;
	my $skipped = 0;
	foreach (keys %{$self->_coll->_data || {}}) {
		if (doc_matches($self->_coll->_data->{$_}, $self->_query)) {
			# are we skipping this? we should only skip
			# here if we're not sorting, otherwise we
			# need to do that later, after we've sorted
			if (!$self->_has_sort && $self->_skip && $skipped < $self->_skip) {
				$skipped++;
				next;
			} else {
				push(@docs, $_);
			}
		}

		# have we reached our limit yet? if so, bail, but
		# only if we're not sorting, otherwise we need to
		# sort _all_ results first
		last if $self->_limit && scalar @docs == $self->_limit;
	}

	# okay, are we sorting?
	if ($self->_has_sort) {
		@docs = sort {
			# load the documents
			my $doc_a = $self->_coll->_data->{$a};
			my $doc_b = $self->_coll->_data->{$b};
			
			# start comparing according to $order
			# this is stolen from my own Giddy::Collection::sort() code
			foreach my $attr ($self->_sort->Keys) {
				my $dir = $self->_sort->FETCH($attr);
				if (defined $doc_a->{$attr} && !ref $doc_a->{$attr} && defined $doc_b->{$attr} && !ref $doc_b->{$attr}) {
					# are we comparing numerically or alphabetically?
					if ($doc_a->{$attr} =~ m/^\d+(\.\d+)?$/ && $doc_b->{$attr} =~ m/^\d+(\.\d+)?$/) {
						# numerically
						if ($dir > 0) {
							# when $dir is positive, we want $a to be larger than $b
							return 1 if $doc_a->{$attr} > $doc_b->{$attr};
							return -1 if $doc_a->{$attr} < $doc_b->{$attr};
						} elsif ($dir < 0) {
							# when $dir is negative, we want $a to be smaller than $b
							return -1 if $doc_a->{$attr} > $doc_b->{$attr};
							return 1 if $doc_a->{$attr} < $doc_b->{$attr};
						}
					} else {
						# alphabetically
						if ($dir > 0) {
							# when $dir is positive, we want $a to be larger than $b
							return 1 if $doc_a->{$attr} gt $doc_b->{$attr};
							return -1 if $doc_a->{$attr} lt $doc_b->{$attr};
						} elsif ($dir < 0) {
							# when $dir is negative, we want $a to be smaller than $b
							return -1 if $doc_a->{$attr} gt $doc_b->{$attr};
							return 1 if $doc_a->{$attr} lt $doc_b->{$attr};
						}
					}
				} else {
					# documents cannot be compared for this attribute
					# we want documents that have the attribute to appear
					# earlier in the results, so let's find out if
					# one of the documents has the attribute
					return -1 if defined $doc_a->{$attr} && !defined $doc_b->{$attr};
					return 1 if defined $doc_b->{$attr} && !defined $doc_a->{$attr};
					
					# if we're here, either both documents have the
					# attribute but it's non comparable (since it's a
					# reference) or both documents don't have that
					# attribute at all. in both cases, we consider them
					# to be equal when comparing these attributes,
					# so we don't return anything and just continue to
					# the next attribute to sort according to (if any)
				}
			}

			# if we've reached this point, the documents compare entirely
			# so we need to return zero
			return 0;
		} @docs;

		# let's limit (and possibly skip) the results if we need to
		splice(@docs, 0, $self->_skip)
			if $self->_skip;
		splice(@docs, $self->_limit, length(@docs) - $self->_limit)
			if $self->_limit && scalar @docs > $self->_limit;
	}

	$self->_set_started_iterating(1);
	$self->_set_docs(\@docs);
}

sub _inc_index {
	my $self = shift;

	$self->_set_index($self->_index + 1);
}

__PACKAGE__->meta->make_immutable;
