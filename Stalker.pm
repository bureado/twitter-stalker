#
# Stalker -- a Perl module to perform algorithmic follower stalking.
#   (C) 2011-2012 Jose Miguel Parrella Romero (@bureado, j@bureado.com)
#   This is free software, released under the same terms of Perl.
#

# USAGE:
# You need to write a Perl file that `use Stalker;'
# The file should call new() and populateStarFollowers(), i.e.:
#
#   my $bot = Stalker->new;
#             $bot->populateStarFollowers('bureado');
#
# The program will add a Twitter follower object to a small schema with the
# name of the tweetstar, and to a large schema named 'people'.

package Stalker;

use MongoDB;
use Net::Twitter;
use POSIX qw/strftime/;
use Date::Parse;

sub new {
	my $package   = shift;
	my $key       = '';
	my $nt        = Stalker->connect or die;
	print "[INF] Connected and ready to go!\n";
	return bless({ conn => $nt, key => $key, $package });
}

sub connect {
	my $nt = Net::Twitter->new(
	 # YOU NEED TO CONFIGURE THE VALUES BELOW.
         traits              => [qw/OAuth API::RESTv1_1/],
	 consumer_key        => '',
	 consumer_secret     => '',
	 access_token        => '',
	 access_token_secret => '',
         source              => '',
	);
	return $nt;
}

sub populateStarFollowers {
	my $self      = shift;
	my $twitstars = shift;       # A Twitter handle must be passed. An arrayref can be passed as well.
	my $cursor    = shift || -1; # Users can optionally pass a cursor ID (e.g., broken executions)

	my $nt = $self->{conn};

	my $conn = MongoDB::Connection->new; # This will connect to Mongo in localhost.
                                             # See CPAN MongoDB docs for other scenarios.

	my $dbh   = $conn->get_database('twitter'); # DB name in MongoDB
	my $ppl   = $dbh->get_collection('people');   # "Large" schema name

	foreach my $twitstar ( @$twitstars ) {
		next unless $twitstar;
		if ( @$twitstars > 1 ) {
			print "[INF] Multiple twitstars mode, resetting cursor\n";
			$cursor = -1;
		}
		my $str   = $dbh->get_collection($twitstar); # "Small" schema name
	
		print "[INF] Entering $twitstar at " . localtime() . "\n";
		my @objs;
		my $i = 1;
		
		for ( my $r; $cursor; $cursor = $r->{next_cursor} ) {
			eval {
				$r = $nt->followers( { screen_name => $twitstar, cursor => $cursor } );
			};
			if ( $@ ) {
				print "[ERR] Fail whale: $@\n" unless $@ =~ /Rate limit/; # This happens more often than I'd like.
				sleep 300 if $@ =~ /Rate limit/;
				redo;
			}
			print "[DBG] Entering READ loop in cursor $cursor ($i)\n";
			my $users  = $r->{users};
			foreach my $user ( @$users ) {
				print "[DBG] Entering follower " . $user->{screen_name} . "\n";

				my %obj;

				# I get only the useful fields (that's why I don't copy the object)
				my @usf = qw/screen_name id created_at statuses_count time_zone followers_count friends_count location lang description/;
				foreach ( @usf ) {
					$obj{$_} = $user->{$_};
				}

				$obj{'source'}      = $user->{'status'}->{'source'};
				$obj{'coordinates'} = $user->{'status'}->{'coordinates'};
				$obj{'place'}       = $user->{'status'}->{'place'};
				$obj{'geo'}         = $user->{'status'}->{'geo'};

				# I do some date mangling here so I can do data arithmetics later.
				$obj{'created_at'} =~ s/^(\w)+//;
				$obj{'created_at'} =~ s/[\+\-](\d){4}//;
				$obj{'created_at'} =~ s/\s{2,}/ /;
				$obj{'created_at'} =~ s/(\S+) (\S+) (\S+) (\S+)/$2 $1 $4 $3/;
				$obj{'created_at'} =  strftime("%Y-%m-%d %H:%M:%S", localtime(str2time($obj{'created_at'})));
				# Black magic ends.

				push ( @objs, { %obj } );
				undef %obj;

				if ( $i >= 500 ) { # Write to DB.
					print "[DBG] Entering WRITE loop at $i in cursor $cursor\n";
					foreach my $act ( @objs ) {
						my $scr = $act->{'screen_name'};
						$ppl->insert($act) ? print "[DBG] Created $scr in MongoDB\n" : print "[DBG] Skipped $scr\n";
						$str->insert({'id' => $act->{'id'}});
					}
					undef @objs;
					$i = 1;
				}
				++$i;
			}
			#my $slp = $nt->until_rate(0.1); # Rate limiting, Twitter-enforced.
			#print "[INF] Sleeping $slp seconds\n";
			#sleep $slp;
		}
		if ( $i > 0 ) { # Last flush.
			print "[DBG] Entering last WRITE loop at $i in cursor $cursor\n";
			foreach my $act ( @objs ) {
				my $scr = $act->{'screen_name'};
				$ppl->insert($act) ? print "[DBG] Created $scr in MongoDB\n" : print "[DBG] Skipped $scr\n";
				$str->insert({'user_id' => $act->{'user_id'}});
			}
		}
	}
}

1; # kthxbye
