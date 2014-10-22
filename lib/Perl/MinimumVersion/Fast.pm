package Perl::MinimumVersion::Fast;
use 5.008005;
use strict;
use warnings;

use Compiler::Lexer;
use List::Util qw(max);

our $VERSION = "0.01";

my $MIN_VERSION   = version->new('5.008');
my $VERSION_5_012 = version->new('5.012');
my $VERSION_5_010 = version->new('5.010');

sub new {
    my ($class, $stuff) = @_;

    my $filename;
    my $src;
    if (ref $stuff ne 'SCALAR') {
        $filename = $stuff;
        open my $fh, '<', $filename
            or die "Unknown file: $filename";
        $src = do { local $/; <$fh> }; 
    } else {
        $filename = '-';
        $src = $$stuff;
    }

    my $lexer = Compiler::Lexer->new($filename);
    my @tokens = $lexer->tokenize($src);
    bless {
        tokens => \@tokens,
    }, $class;
}

sub minimum_version {
    my $self = shift;
    my @tokens = map { @$$_ } @{$self->{tokens}};
    my $version = $MIN_VERSION;
    for my $i (0..@tokens-1) {
        my $token = $tokens[$i];
        if ($token->{name} eq 'ToDo') {
            # ... => 5.12
            $version = max($version, $VERSION_5_012);
        } elsif ($token->{name} eq 'Package') {
            if (@tokens > $i+2) {
                my $number = $tokens[$i+2];
                if ($number->{name} eq 'Int' || $number->{name} eq 'Double' || $number->{name} eq 'Key') {
                    # package NAME VERSION; => 5.012
                    $version = max($version, $VERSION_5_012);
                }
            }
        } elsif ($token->{name} eq 'UseDecl' || $token->{name} eq 'RequireDecl') {
            # use feature => 5.010
            # use mro     => 5.010
            if (@tokens >= $i+1) {
                my $next_token = $tokens[$i+1];
                if ($next_token->{data} eq 'mro' || $next_token->{data} eq 'feature') {
                    $version = max($version, $VERSION_5_010);
                } elsif ($next_token->{name} eq 'Double') {
                    $version = max($version, version->new($next_token->{data}));
                }
            }
        } elsif ($token->{name} eq 'DefaultOperator') {
            if ($token->{data} eq '//') {
                $version = max($version, $VERSION_5_010);
            }
        } elsif ($token->{name} eq 'PolymorphicCompare') {
            if ($token->{data} eq '~~') {
                $version = max($version, $VERSION_5_010);
            }
        } elsif ($token->{name} eq 'DefaultEqual') {
            if ($token->{data} eq '//=') {
                $version = max($version, $VERSION_5_010);
            }
        } elsif ($token->{name} eq 'GlobalHashVar') {
            if ($token->{data} eq '%-' || $token->{data} eq '%+') {
                $version = max($version, $VERSION_5_010);
            }
        } elsif ($token->{name} eq 'SpecificValue') {
            # $-{"a"}
            # $+{"a"}
            if ($token->{data} eq '$-' || $token->{data} eq '$+') {
                $version = max($version, $VERSION_5_010);
            }
        } elsif ($token->{name} eq 'GlobalArrayVar') {
            if ($token->{data} eq '@-' || $token->{data} eq '@+') {
                $version = max($version, $VERSION_5_010);
            }
        } elsif ($token->{name} eq 'WhenStmt') {
            if ($i >= 1 && ($tokens[$i-1]->{name} ne 'SemiColon' && $tokens[$i-1]->{name} ne 'RightBrace')) {
                # postfix when
                $version = max($version, $VERSION_5_012);
            } else {
                # normal when
                $version = max($version, $VERSION_5_010);
            }
        }
    }
    return $version;
}

1;
__END__

=encoding utf-8

=head1 NAME

Perl::MinimumVersion::Fast - Find a minimum required version of perl for Perl code

=head1 SYNOPSIS

    use Perl::MinimumVersion::Fast;

    my $p = Perl::MinimumVersion::Fast->new($filename);
    print $p->minimum_version, "\n";

=head1 DESCRIPTION

"Perl::MinimumVersion::Fast" takes Perl source code and calculates the minimum
version of perl required to be able to run it. Because it is based on PPI,
it can do this without having to actually load the code.

Perl::MinimumVersion::Fast is alternative implementation of Perl::MinimumVersion.

It's based on goccy's L<Compiler::Lexer>.

This module supports only Perl 5.8.1+.
If you want to support B<Perl 5.6>, use L<Perl::MinimumVersion> instead.

In 2013, you don't need to support Perl 5.6 in most of case.

=head1 METHODS

=over 4

=item my $p = Perl::MinimumVersion::Fast->new($filename);

=item my $p = Perl::MinimumVersion::Fast->new(\$src);

Create new instance. You can create object from C<< $filename >> and C<< \$src >> in string.

=item $p->minimum_version();

Get a minimum perl version the code required.

=back

=head1 BENCHMARK

Perl::MinimumVersion::Fast is faster than Perl::MinimumVersion.
Because Perl::MinimumVersion::Fast uses L<Compiler::Lexer>, that is a Perl5 lexer implemented in C++.
And Perl::MinimumVersion::Fast omits some features implemented in Perl::MinimumVersion.

But, but, L<Perl::MinimumVersion::Fast> is really fast.

                                Rate Perl::MinimumVersion Perl::MinimumVersion::Fast
    Perl::MinimumVersion       5.26/s                   --                       -97%
    Perl::MinimumVersion::Fast  182/s                3365%                         --

=head1 LICENSE

Copyright (C) tokuhirom.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

tokuhirom E<lt>tokuhirom@gmail.comE<gt>

=head1 SEE ALSO

This module using L<Compiler::Lexer> as a lexer for Perl5 code.

This module is inspired from L<Perl::MinimumVersion>.

=cut

