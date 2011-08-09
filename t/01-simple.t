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

# find some documents
my $curs1 = $coll->find({ _id => 1 });
is($curs1->count, 1, 'count is 1 when searching for a known ID');
my $doc1_from_cursor = $curs1->next;
my $doc1_from_fone = $coll->find_one({ _id => 1 });
is_deeply($doc1_from_fone, $doc1_from_cursor, 'find_one by ID finds the same thing as find');
my $curs2 = $coll->find({ starring => 'Jason Segel' });
is($curs2->count, 2, 'Jason Segel stars in two shows');

# update Freaks and Geeks 'cause Jason Segel stars in that one too
my $up1 = $coll->update({ title => qr/^Freaks/ }, { '$push' => { starring => 'Jason Segel' } });
ok($up1->{ok} == 1 && $up1->{n} == 1, 'update seems to have succeeded');

# let's see in how many shows Jason Segel stars now
my $curs3 = $coll->find({ starring => 'Jason Segel' });
is($curs3->count, 3, 'Jason Segel now stars in three shows');

# let's try an upsert
my $up2 = $coll->update({ title => 'Buffy the Vampire Slayer' }, {
	'$set' => {
		_id => 4,
		seasons => 7,
		starring => ['Sarah Michelle Gellar', 'Alyson Hannigan'],
	},
	'$inc' => {
		year => 1997,
	},
	'$pushAll' => {
		genres => [qw/action drama fantasy/],
	},
}, { upsert => 1 });
is($up2->{upserted}, 4, 'upsert seems to have succeeded');

# let's find the upserted document
my $doc3 = $coll->find_one({ year => { '$gt' => 1996, '$lte' => 1997 } });
ok($doc3->{_id} == 4 && $doc3->{title} eq 'Buffy the Vampire Slayer', 'upserted document exists in the database');

# let's see if autoload works okay
my $coll2 = $db->autoloaded;
is(ref $coll2, 'MorboDB::Collection', 'autoload on database returned a collection object');
is($coll2->full_name, 'morbodb_test.autoloaded', 'autoloaded collection object seems okay');

# let's see how child collections work
my $coll3 = $coll2->subloaded;
is(ref $coll3, 'MorboDB::Collection', 'autoload on collection returned a collection object');
is($coll3->full_name, 'morbodb_test.autoloaded.subloaded', 'autoloaded child collection seems okay');

# let's try to remove all Jason Segel starring shows
my $rem1 = $coll->remove({ starring => 'Jason Segel' });
is($rem1->{n}, 3, 'removed three documents as expected');
my $curs4 = $coll->find({ starring => 'Jason Segel' });
is($curs4->count, 0, 'No more Jason Segel shows');

# how many documents do we have left?
is($coll->count, 1, 'we have one document left');

# let's remove that document too
$coll->remove;
is($coll->count, 0, 'we have on more documents');

# let's reinsert a document
$coll->insert({ _id => 1, title => 'WOOOOOOEEEEE' });
is($coll->count, 1, 'new document created');
# and now drop the collection
$coll->drop;
is($coll->count, 0, 'dropped collection is empty (as it does not exist)');

done_testing();
