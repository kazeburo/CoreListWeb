package CoreListWeb::Web;

use strict;
use warnings;
use utf8;
use 5.010001;
use File::Basename;
use version;

use Kossy;
use Module::CoreList;
use List::MoreUtils qw/before after/;

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
        next unless exists $Module::CoreList::version{$v}{$module};
        my $modver = $Module::CoreList::version{$v}{$module};
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
    my $delta_from = $Module::CoreList::delta{$version}{delta_from};
    my %prev_versions = $delta_from ? %{$Module::CoreList::version{$delta_from}} : ();
    my @data;
    for my $m ( sort keys %modules ) {
        my $previous_version = $prev_versions{$m} || "undef";
        my $first_release = is_first_release($m,$version);
        push @data, {
            name => $m,
            version => $modules{$m},
            deprecated => Module::CoreList::is_deprecated($m, $version) ? 1 : 0,
            first_release => $first_release,
            previous_version => (!$first_release && $modules{$m} && $previous_version ne $modules{$m}) ? $previous_version : undef,
        }
    }
    @data;
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


my %PAGE_CACHE;
filter 'page_cache' => sub {
    my ($app) = @_;
    sub {
        my ($self, $c) = @_;
        return $app->($self, $c) if ! exists $ENV{DYNO}; #dev
        $PAGE_CACHE{$c->req->uri} ||= $app->($self, $c);
    };
};


get '/' => [qw/page_cache/] => sub {
    my ($self, $c)  = @_;
    $c->render('index.tx', { corelist_version => $Module::CoreList::VERSION });
};

get '/version-list' => [qw/page_cache/] =>  sub {
    my ($self, $c) = @_;
    $c->render('version-list.tx',{
        versions => [$self->perl_versions]
    });
};

get '/v/:version' => [qw/page_cache/] => sub {
    my ($self,$c) = @_;
    my $version = $c->args->{version} // $c->halt(400);
    $version = numify_version($version);
    my @core_modules = $self->perl_core_modules($version);
    my @perl_versions = $self->perl_versions();
    my @next = before { numify_version($_->{version}) eq $version } @perl_versions;
    my @prev = after { numify_version($_->{version}) eq $version } @perl_versions;
    $c->render('version.tx', {
        version => $version, 
        formated_version => format_perl_version($version),
        release_date => perl_release_date($version),
        modules => \@core_modules,
        new_modules => scalar(grep { $_->{first_release} } @core_modules),
        updated_modules => scalar(grep { $_->{previous_version} } @core_modules),
        removed_modules => [$self->perl_removed_modules($version)],
        next => @next ? $next[-1] : undef,
        prev => @prev ? $prev[0] : undef,
    });
};


get '/m/:module' => [qw/page_cache/] => sub {
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

