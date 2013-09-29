use FindBin;
use lib "$FindBin::Bin/extlib/lib/perl5";
use lib "$FindBin::Bin/lib";
use File::Basename;
use Plack::Builder;

use Plack::Middleware::Session;
use Plack::Session::Store::File;

use KoList::Web;

my $root_dir = File::Basename::dirname(__FILE__);

my $app = KoList::Web->psgi($root_dir);
builder {
		enable 'Session',
			store => Plack::Session::Store::File->new(
				dir => $root_dir . '/sessions'
			);
    enable 'ReverseProxy';
    enable 'Static',
        path => qr!^/(?:(?:css|js|img)/|favicon\.ico$)!,
        root => $root_dir . '/public';
    $app;
};

