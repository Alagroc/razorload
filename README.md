# What does this do?
This is an old software I used to generate specific load on a website. It will crawl for certain links (string given), or just keep hitting an URI. The end goal is just to generate load, in a different way from ab would do (apache utils).

It can use tor to connect to the site, using the default socket configuration when launching the browser locally.

The cache bypass is experimental, and may not work depending on the cdn settings.

The client / server is a work in progress, you have to specify the target in the file itself for it to work.


# Usage

razorload.pl -u URL(comma separated) -string <String> [0 to skip crawl] -proc [concurrent processes] -rounds [rounds] 
                        --cachebypass    Try to bypass cache
                        --tor    Use local tor sockets (default config only)
                        --timeout <seconds> [default 1]
                        --debug  lots of shit output
                        --forms i to add random posts on forms
                         --help  to show this message
                ...or just
                        --client to connect to master
                        --master to start a server


If you want to query pages where the link contains images:

razerload.pl -u http://yoursite -string images -proc 5 -round 100

or, to hammer the /stats uri:

razerload.pl -u http://yoursite/stats -string 0 -proc 5 -round 100

Remember this is using perl, if you launch too many processes it will make your desktop unresponsive.

# What libraries do I need to run this?

You should have most of the modules already, use cpan for the rest:

$ cpan
# install HTTP::Request LWP::UserAgent HTTP::Request::Common Getopt::Long qw(GetOptions) Term::ANSIColor Carp IO::Socket IO::Socket::INET
