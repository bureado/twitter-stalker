
Stalker -- a Perl module to perform algorithmic follower stalking.
  (C) 2011-2012 Jose Miguel Parrella Romero (@bureado, j@bureado.com)
  This is free software, released under the same terms of Perl.


USAGE:
You need to write a Perl file that `use Stalker;'
The file should call new() and populateStarFollowers(), i.e.:

  my $bot = Stalker->new;
            $bot->populateStarFollowers('bureado');

The program will add a Twitter follower object to a small schema with the
name of the tweetstar, and to a large schema named 'people'.

IMPORTANT: you need to request a consumer key/secret and access token+secret
from Twitter to access their API. Fill out the data below. Module won't work
otherwise. You also need MongoDB running.

Performance notes: slurping data from Twitter is resource-consuming, both in
bandwidth, CPU in some cycles, RAM and I/O when writting to Mongo. I run one
Twitter analysis for Ecuador each Q, and consume about 150 MB of res MEM with
Mongo, and varying levels of CPU and MEM with this Perl script. My learnings:

  1. Adjust near line 110, if you want to write earlier or later. Writing later
     exhausts MongoDB RAM more slowly, but then Perl will consume a bit more.
  2. Consider trying to connect to MongoDB on the write loops. I haven't tried
     this but it seems that keeping the connection open will cause overhead in
     large Twitter accounts.
  3. Adjust the sleep rate near line 128, if you want a more smooth execution or
     just exhaust your rate ASAP.
  4. Avoid querying Mongo while the process is running, especialy when your
     tables don't have indices. It hogs RAM like a boss.

-> Feel free to reach out to j@bureado.com and Twitter @bureado for questions.