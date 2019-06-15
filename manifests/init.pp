class doazure (

  # class arguments
  # ---------------
  # setup defaults

  $user = 'web',
  $notifier_dir = '/etc/puppet/tmp',

  # template vars
  $cloud_name = 'AzureCloud',
  $domain_name = 'example.com',
  $client_id = '',
  $tenant_id = '',
  $subscription = '',
  $cert_name = '',
  $cert_pem = '',
  $cert_crt = '',

  # end of class arguments
  # ----------------------
  # begin class

) {

  #
  # Windows install only partially built, doesn't work yet
  #

  case $operatingsystem {
    centos, redhat, fedora,
    ubuntu, debian: {
      $filepath = "/home/${user}/.azure/"
    }
    windows: {
      $filepath = "C:\\Users\\${user}\\.azure\\"
    }
  }

  File {
    owner => $user,
    group => $user,
  }

  file { 'doazure-dir' :
    path   => "${filepath}",
    ensure => 'directory'
  }

  file { 'doazure-config' :
    path    => "${filepath}config",
    ensure  => 'file',
    content => template('doazure/config.erb'),
  }

  file { 'doazure-clouds-config' :
    path    => "${filepath}clouds.config",
    ensure  => 'file',
    content => template('doazure/clouds.config.erb'),
  }

  file { 'doazure-cert-pem' :
    path    => "${filepath}${cert_name}-cert.pem",
    ensure  => 'file',
    content => "${cert_pem}"
  }
  file { 'doazure-cert-crt' :
    path    => "${filepath}${cert_name}-cert.crt",
    ensure  => 'file',
    content => "${cert_crt}"
  }

  case $operatingsystem {
    centos, redhat, fedora,
    ubuntu, debian: {
      # create a script file for required environment variables
      file { 'doazure-environment' :
        path    => "${filepath}environment",
        ensure  => 'file',
        content => template('doazure/environment.erb'),
      }
      # if there's an open bashrc
      if defined(Concat["/home/${user}/.bashrc"]) {
        # add line to include environment variables
        $command_bash_include_azenv = "\n# add Azure environment variables if present\nif [ -f ${filepath}environment ]; then\n        source ${filepath}environment\nfi\n"
        concat::fragment { 'doazure-bashrc-environment':
          target  => "/home/${user}/.bashrc",
          content => $command_bash_include_azenv,
          order   => '20',
        }
      }
      # generate pfx file from pem
      exec { 'doazure-generate-cert-pfx' :
        command => "/usr/bin/openssl pkcs12 -export -out ${filepath}${cert_name}-cert.pfx -in ${filepath}${cert_name}-cert.pem -passout pass: ; chown ${user}:${user} ${filepath}${cert_name}-cert.pfx",
        require => [File['doazure-cert-pem']],
      }
    }
    windows: {
      # create environment vars in registry
      windows_env { 'ARM_SUBSCRIPTION_ID':
        value     => $subscription,
      }
      windows_env { 'ARM_TENANT_ID':
        value     => $tenant_id,
      }
      windows_env { 'ARM_CLIENT_ID':
        value     => $client_id,
      }
      windows_env { 'ARM_CLIENT_CERTIFICATE_PATH':
        value     => "${file_path}${cert_name}-cert.pfx",
      }
    }
  }

}

