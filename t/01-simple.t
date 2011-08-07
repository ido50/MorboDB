#!perl

use warnings;
use strict;
use utf8;
use MorboDB;
use Test::More;
use Try::Tiny;

# create a new MorboDB object
my $morbo = MorboDB->new;
ok($morbo, 'Got a proper MorboDB object');

# create a MorboDB database
my $db = $morbo->get_database('morbodb_test');
ok($db, 'Got a proper MorboDB::Database object');

# create a MorboDB collection
my $coll = $db->get_collection('tv_shows');
ok($coll, 'Got a proper MorboDB::Collection object');

# create some documents
my $id1 = $coll->insert({
	_id => 1,
	title => 'Freaks and Geeks',
	year => 1999,
	seasons => 1,
	genres => [qw/comedy drama/],
	starring => ['Linda Cardellini', 'John Francis Daley', 'James Franco'],
});
my ($id2, $id3) = $coll->batch_insert([
	{
		_id => 2,
		title => 'Undeclared',
		year => 2001,
		seasons => 1,
		genres => [qw/comedy drama/],
		starring => ['Jay Baruchel', 'Carla Gallo', 'Jason Segel'],
	}, {
		_id => 3,
		title => 'How I Met Your Mother',
		year => 2005,
		seasons => 7,
		genres => [qw/comedy romance/],
		starring => ['Josh Radnor', 'Jason Segel', 'Cobie Smulders', 'Neil Patrick Harris', 'Alyson Hannigan'],
	}
]);

ok($id1 == 1, 'insert() returned the correct ID');
ok($id2 == 2 && $id3 == 3, 'batch_insert() returned the correct IDs');

done_testing();
