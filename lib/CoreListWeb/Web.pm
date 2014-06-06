package CoreListWeb::Web;

use strict;
use warnings;
use utf8;
use 5.010001;
use File::Basename;
use version;

use Kossy;
use Module::CoreList;

our $VERSION = '0.01';

sub versions {
    my ($self,$module) = @_;

    my @data;
    for my $v (reverse sort keys %Module::CoreList::version) {
        my $modver = $Module::CoreList::version{$v}->{$module};
        next unless $modver;
        push @data, {perl => $v, perl_formated => format_perl_version($v), module => $modver};
    }
    return @data;
}

sub format_perl_version {
    my $v = shift;
    return $v if $v < 5.006;
    return version->new($v)->normal;
}


sub numify_version {
    my $ver = shift;
    if ($ver =~ /\..+\./) {
        $ver = version->new($ver)->numify;
    }
    $ver += 0;
    return $ver;
}

get '/' => sub {
    my ($self, $c)  = @_;
    $c->render('index.tx', { corelist_version => $Module::CoreList::VERSION });
};

get '/version-list' => sub {
    my ($self, $c) = @_;
    my %seen;
    $c->render( 'version-list.tx',
        { versions => [ grep { !$seen{$_->{formated}}++ } 
                            map { {version => $_, formated => format_perl_version($_)}  } 
                            reverse sort keys %Module::CoreList::version ] } );
};

get '/v/:version' => sub {
    my ($self,$c) = @_;
    my $version = $c->args->{version} // $c->halt(400);
    $version = numify_version($version);

    my %modules = %{$Module::CoreList::version{$version}};
    my @modules = map {{
        name => $_,
        version => $modules{$_}
    }} sort keys %modules;
    $c->render('version.tx', {version => $version, 
                              formated_version => format_perl_version($version),
                              modules => \@modules});
};

get '/m/:module' => sub {
    my ($self, $c) = @_;

    my $module = $c->args->{module} // $c->halt(400);
    my @versions = $self->versions($module);

    $c->render('module.tx', {versions => \@versions, module => $module});
};


1;

