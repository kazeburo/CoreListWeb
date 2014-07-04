use FindBin;
use lib "$FindBin::Bin/extlib/lib/perl5";
use lib "$FindBin::Bin/lib";
use File::Basename;
use Plack::Builder;
use Plack::Builder::Conditionals;
use CoreListWeb::Web;
use Module::CoreList;

my $root_dir = File::Basename::dirname(__FILE__);

warn "Module::CoreList::VERSION => $Module::CoreList::VERSION\n";

my $app = CoreListWeb::Web->psgi($root_dir);
builder {
    enable match_if addr([qw/127.0.0.1/]), 'ReverseProxy';
    enable 'Static',
        path => qr!^/(?:(?:css|js|img)/|favicon\.ico$)!,
        root => $root_dir . '/public';
    enable "Deflater",
      content_type => ['text/css','text/html','text/javascript','application/javascript'];
    $app;
};

