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

sub perl_release_date {
    my $v = shift;
    $Module::CoreList::released{$v};
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

sub module_versions {
    my ($self,$module) = @_;
    my %seen;
    my @data;
    for my $v (reverse sort keys %Module::CoreList::version) {
        my $modver = $Module::CoreList::version{$v}->{$module};
        #next unless $modver;
        next if $seen{numify_version($v)}++;
        push @data, {
            perl => $v,
            perl_formated => format_perl_version($v),
            perl_release_date => perl_release_date($v),
            module => $modver,
            deprecated => Module::CoreList::is_deprecated($module, $v) ? 1 : 0,
        };
    }
    return @data;
}

sub perl_versions {
    my $self = shift;
    my %seen;
    grep { !$seen{$_->{numify_version}}++ } map {{
        version => $_,
        numify_version => numify_version($_),
        formated => format_perl_version($_),
        release_date => perl_release_date($_),
        coremodules => scalar keys %{$Module::CoreList::version{$_}},
    }} reverse sort keys %Module::CoreList::version;
}

sub is_first_release {
    my ($module,$version) = @_;
    my $v = Module::CoreList::first_release($module);
    return unless $v;
    format_perl_version($v) eq format_perl_version($version) ? 1 : 0;
}

sub perl_core_modules {
    my ($self,$version) = @_;
    my %modules = %{$Module::CoreList::version{$version}};
    map {{
        name => $_,
        version => $modules{$_},
        deprecated => Module::CoreList::is_deprecated($_, $version) ? 1 : 0,
        first_release => is_first_release($_,$version),
    }} sort keys %modules;
}

sub perl_removed_modules {
    my ($self,$version) = @_;
    map { { name => $_ } } sort keys %{$Module::CoreList::delta{$version}{removed}}
}

sub removed_from_version {
    my ($self,$module) = @_;
    my $version = Module::CoreList::removed_from($module);
    return {} unless $version;
    {
        format_perl_version => format_perl_version($version),
        perl_release_date => perl_release_date($version),
        version => $version
    }
}

sub first_release_version {
    my ($self,$module) = @_;
    my $version = Module::CoreList::first_release($module);
    return {} unless $version;
    {
        format_perl_version => format_perl_version($version),
        perl_release_date => perl_release_date($version),
        version => $version
    }
}

sub deprecated_version {
    my ($self,$module) = @_;
    my $version = Module::CoreList::deprecated_in($module);
    return {} unless $version;
    {
        format_perl_version => format_perl_version($version),
        perl_release_date => perl_release_date($version),
        version => $version
    }
}


get '/' => sub {
    my ($self, $c)  = @_;
    $c->render('index.tx', { corelist_version => $Module::CoreList::VERSION });
};

get '/version-list' => sub {
    my ($self, $c) = @_;
    $c->render('version-list.tx',{
        versions => [$self->perl_versions]
    });
};

get '/v/:version' => sub {
    my ($self,$c) = @_;
    my $version = $c->args->{version} // $c->halt(400);
    $version = numify_version($version);

    $c->render('version.tx', {
        version => $version, 
        formated_version => format_perl_version($version),
        release_date => perl_release_date($version),
        modules => [$self->perl_core_modules($version)],
        removed_modules => [$self->perl_removed_modules($version)],
    });
};


get '/m/:module' => sub {
    my ($self, $c) = @_;
    my $module = $c->args->{module} // $c->halt(400);

    my @versions = $self->module_versions($module);
    $c->render('module.tx', {
        module => $module, 
        versions => \@versions,
        first_release => $self->first_release_version($module),
        removed_from => $self->removed_from_version($module),
        deprecated_in => $self->deprecated_version($module),
    });
};


1;

