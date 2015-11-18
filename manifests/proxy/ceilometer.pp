#
# Configure ceilometer middleware for swift
#
# == Dependencies
#
# puppet-ceilometer (http://github.com/enovance/puppet-ceilometer)
#
# == Parameters
#
# [*rabbit_host*]
#   (Optional) IP or hostname of the rabbit server.
#   Defaults to '127.0.0.1'.
#
# [*rabbit_port*]
#   (Optional) Port of the rabbit server.
#   Defaults to 5672.
#
# [*rabbit_user*]
#   (Optional) Username for rabbit.
#   Defaults to 'guest'.
#
# [*rabbit_password*]
#   (Optional) Password for rabbit user.
#   Defaults to 'guest'.
#
# [*ensure*]
#   Enable or not ceilometer fragment
#   Defaults to 'present'
#
# [*group*]
#   Group name to add to 'swift' user.
#   ceilometer/eventlet: set 'ceilometer' (default)
#   ceilometer/wsgi: set $::apache::group
#   Defaults to 'ceilometer'
#
# == Examples
#
# == Authors
#
#   Francois Charlier fcharlier@enovance.com
#
# == Copyright
#
# Copyright 2013 eNovance licensing@enovance.com
#
class swift::proxy::ceilometer(
  $rabbit_user     = 'guest',
  $rabbit_password = 'guest',
  $rabbit_host     = '127.0.0.1',
  $rabbit_port     = '5672',
  $ensure          = 'present',
  $group           = 'ceilometer',
) inherits swift {

  User['swift'] {
    groups +> $group,
  }

  if defined(Service['swift-proxy']) {
    File['/var/log/ceilometer/swift-proxy-server.log'] -> Service['swift-proxy']
  }

  file { '/var/log/ceilometer/swift-proxy-server.log':
    ensure => file,
    mode   => '0664',
    owner  => 'swift',
    group  => 'swift',
  }

  concat::fragment { 'swift_ceilometer':
    target  => '/etc/swift/proxy-server.conf',
    content => template('swift/proxy/ceilometer.conf.erb'),
    order   => '33',
    require => Class['::ceilometer'],
  }

  package { 'python-ceilometermiddleware':
    ensure => $ensure,
    tag    => 'openstack',
  }

}
