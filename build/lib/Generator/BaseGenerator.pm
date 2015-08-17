# Copyright (c) 2005 Ian Joyce
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package ModParrot::Config::Generator::BaseGenerator;

use strict;
use warnings;

use POSIX qw(strftime);

our $VERSION = '0.01';

sub new
{
    my ($class, %args) = @_;
    my $self = \%args;
    return bless $self, $class;
}

sub get_map
{
    my ($self, $map_file) = @_;

    my @entries;

    open FILE, $map_file or die $!;

    while (my $line = <FILE>) {
        chomp $line;

        # Comment in the map file.
        next if $line =~ /^#/;

        # Empty line
        next if $line =~ /^\s*$/;

        my @properties = split /\|/, $line;
        s/^\s+|\s+$//g for @properties;

        my %properties = (
            'name'        => $properties[0],
            'return_type' => $properties[1],
            'access'      => $properties[2],
        );

        push @entries, \%properties;
    }

    close FILE;

    return \@entries;
}

sub write_file 
{
    my ($self, $type, $filename, $contents) = @_;

    my $file = $type eq 'nci'
        ? $self->{'nci_src'}
        : $self->{'pir_src'};
    $file .= $filename;

    open (OUT_FILE, ">$file") or die $!;
    print OUT_FILE $self->message($type eq 'nci' ? '//' : '#');
    print OUT_FILE $contents;
    close OUT_FILE;

    return 1;
}

sub merge
{
    my ($self, $template, $record) = @_;

    foreach my $key (keys %$record) {
        $template =~ s/%%$key%%/$record->{$key}/ig;
    }

    return $template;
}

sub message
{
    my ($self, $comment) = @_;

    my $message = <<'END'
+
+ This file is autogenereted.
+
+ Do No Edit!
+
+ %%NOW%%
+

END
;

    my $now = strftime "%a %b %e %H:%M:%S %Y", localtime;

    $message =~ s/%%NOW%%/$now/;
    $message =~ s/\+/$comment/g;

    return $message;
}

1;
