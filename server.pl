#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/CoreList-lib";
use Proclet;
use Plack::Loader;
use Plack::Builder;
use Plack::Builder::Conditionals;
use Getopt::Long;

my $port = 5000;
Getopt::Long::Configure ("no_ignore_case");
GetOptions(
    "p|port=s" => \$port,
);

chdir($FindBin::Bin);
my $proclet = Proclet->new;

sub cap_cmd {
    my ($cmdref) = @_;
    pipe my $logrh, my $logwh
        or die "Died: failed to create pipe:$!";
    my $pid = fork;
    if ( ! defined $pid ) {
        die "Died: fork failed: $!";
    } 

    elsif ( $pid == 0 ) {
        #child
        close $logrh;
        open STDOUT, '>&', $logwh
            or die "Died: failed to redirect STDOUT";
        close $logwh;
        exec @$cmdref;
        die "Died: exec failed: $!";
    }
    close $logwh;
    my $result;
    while(<$logrh>){
        warn $_;
        $result .= $_;
    }
    close $logrh;
    while (wait == -1) {}
    my $exit_code = $?;
    $exit_code = $exit_code >> 8;
    return ($result, $exit_code);
}

$proclet->service(
    every => '* * * * *',
    tag => 'cron',
    code => sub {
        warn "Try to cpanm -lCoreList-lib Module::CoreList\n";
        open(my $fh, "<", "server.pid") or die "$@";
        my $pid = <$fh>;
        chomp $pid;
        close($fh);
        my ($result,$exit_code) = cap_cmd(['cpanm','-lCoreList-lib','Module::CoreList']);
        if ( $exit_code == 0 && $result =~ m!Successfully installed Module-CoreList! ) {
            warn "KILLHUP server-starter ($pid)\n";
            kill 'HUP', $pid;
        }
    }
);

$proclet->service(
    code => sub {
        warn "Start CoreListWeb::Web $$\n";
        exec(qw!start_server --port!,$port,qw!--pid-file server.pid  --!,
             qw!plackup -Mlib=CoreList-lib/lib/perl5 -E production -s Starlet --max-workers 10 -a  app.psgi!);
    },
    tag => 'web',
);

$proclet->run;

