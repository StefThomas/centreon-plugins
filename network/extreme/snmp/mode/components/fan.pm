################################################################################
# Copyright 2005-2013 MERETHIS
# Centreon is developped by : Julien Mathis and Romain Le Merlus under
# GPL Licence 2.0.
# 
# This program is free software; you can redistribute it and/or modify it under 
# the terms of the GNU General Public License as published by the Free Software 
# Foundation ; either version 2 of the License.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with 
# this program; if not, see <http://www.gnu.org/licenses>.
# 
# Linking this program statically or dynamically with other modules is making a 
# combined work based on this program. Thus, the terms and conditions of the GNU 
# General Public License cover the whole combination.
# 
# As a special exception, the copyright holders of this program give MERETHIS 
# permission to link this program with independent modules to produce an executable, 
# regardless of the license terms of these independent modules, and to copy and 
# distribute the resulting executable under terms of MERETHIS choice, provided that 
# MERETHIS also meet, for each linked independent module, the terms  and conditions 
# of the license of that module. An independent module is a module which is not 
# derived from this program. If you modify this program, you may extend this 
# exception to your version of the program, but you are not obliged to do so. If you
# do not wish to do so, delete this exception statement from your version.
# 
# For more information : contact@centreon.com
# Authors : Quentin Garnier <qgarnier@merethis.com>
#
####################################################################################

package network::extreme::snmp::mode::components::fan;

use strict;
use warnings;

my %map_fan_status = (
    1 => 'operational',
    2 => 'not operational',
);

my $mapping = {
    extremeFanOperational => { oid => '.1.3.6.1.4.1.1916.1.1.1.9.1.2', map => \%map_fan_status },
    extremeFanSpeed => { oid => '.1.3.6.1.4.1.1916.1.1.1.9.1.4' },
};
my $oid_extremeFanStatusEntry = '.1.3.6.1.4.1.1916.1.1.1.9.1';

sub load {
    my (%options) = @_;
    
    push @{$options{request}}, { oid => $oid_extremeFanStatusEntry, end => $mapping->{extremeFanOperational}->{oid} };
}

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => "Checking fans");
    $self->{components}->{fan} = {name => 'fans', total => 0, skip => 0};
    return if ($self->check_exclude(section => 'fan'));

    my ($exit, $warn, $crit, $checked);
    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$self->{results}->{$oid_extremeFanStatusEntry}})) {
        next if ($oid !~ /^$mapping->{extremeFanOperational}->{oid}\.(.*)$/);
        my $instance = $1;
        my $result = $self->{snmp}->map_instance(mapping => $mapping, results => $self->{results}->{$oid_extremeFanStatusEntry}, instance => $instance);
        
        next if ($self->check_exclude(section => 'fan', instance => $instance));

        $self->{components}->{fan}->{total}++;
        $self->{output}->output_add(long_msg => sprintf("Fan '%s' status is '%s' [instance = %s, speed = %s]",
                                                        $instance, $result->{extremeFanOperational}, $instance, defined($result->{extremeFanSpeed}) ? $result->{extremeFanSpeed} : 'unknown'));
        $exit = $self->get_severity(section => 'fan', value => $result->{extremeFanOperational});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(severity => $exit,
                                        short_msg => sprintf("Fan '%s' status is '%s'", $instance, $result->{extremeFanOperational}));
            next;
        }
        
        ($exit, $warn, $crit, $checked) = $self->get_severity_numeric(section => 'fan', instance => $instance, value => $result->{extremeFanSpeed});            
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(severity => $exit,
                                        short_msg => sprintf("Fan '%s' is '%s' rpm", $instance, $result->{extremeFanSpeed}));
        }
        $self->{output}->perfdata_add(label => 'fan_' . $instance, unit => 'rpm', 
                                      value => $result->{extremeFanSpeed},
                                      warning => $warn,
                                      critical => $crit, min => 0
                                      );
    }
}

1;