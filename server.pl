#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/tmp/CoreList-lib";
use Proclet;
use Plack::Loader;
use Plack::Builder;
use Plack::Builder::Conditionals;
use Getopt::Long;
use HTTP::Tiny;

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
        open STDERR, '>&', $logwh
            or die "Died: failed to redirect STDERR";
        open STDOUT, '>&', $logwh
            or die "Died: failed to redirect STDOUT";
        close $logwh;
        exec @$cmdref;
        die "Died: exec failed: $!";
    }
    close $logwh;
    my $result;
    while(<$logrh>){
        warn $cmdref->[0]." : ".$_;
        $result .= $_;
    }
    close $logrh;
    while (wait == -1) {}
    my $exit_code = $?;
    $exit_code = $exit_code >> 8;
    return ($result, $exit_code);
}

sub update_corelist {
    local $ENV{PERL_CPANM_HOME} = "$FindBin::Bin/tmp";
    my ($result, $exit_code) = cap_cmd(['cpanm','-n','--no-man-pages','-ltmp/CoreList-lib','Module::CoreList']);
    if ( $result =~ m!failed\. See (.+) for details! ) { 
        cap_cmd('tail','-10',$1);
    }
    return ($result, $exit_code);
}

update_corelist();

$proclet->service(
    every => '28,58 * * * *',
    tag => 'cron',
    code => sub {
        warn "Try to cpanm Module::CoreList\n";
        open(my $fh, "<", "tmp/server.pid") or die "$@";
        my $pid = <$fh>;
        chomp $pid;
        close($fh);
        my ($result, $exit_code) = update_corelist();
        if ( $exit_code == 0 && $result =~ m!Successfully installed Module-CoreList! ) {
            warn "KILLHUP server-starter ($pid)\n";
            kill 'HUP', $pid;
        }
    },
);

if ( my $service_name = $ENV{SERVICE_NAME} ) {
    warn "detect DYNO. add ping_web service\n";
    $proclet->service(
        every => '16,46 * * * *',
        tag => 'ping_web',
        code => sub {
            my $ua = HTTP::Tiny->new;
            $ua->get('http://'.$service_name.'.herokuapp.com/');
        }
    );
}

$proclet->service(
    code => sub {
        warn "Start CoreListWeb::Web $$\n";
        exec(qw!start_server --port!,$port,qw!--pid-file tmp/server.pid  --!,
             qw!plackup -Mlib=tmp/CoreList-lib/lib/perl5 -E production -s Starlet --max-workers 10 -a  app.psgi!);
    },
    tag => 'web',
);

$proclet->run;

