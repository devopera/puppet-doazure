define doazure::creduser (

  # class arguments
  # ---------------
  # setup defaults

  $user = $title,
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
    ensure => 'file',
  }

  file { "doazure-dir-${user}" :
    path   => "${filepath}",
    ensure => 'directory'
  }

  file { "doazure-config-${user}" :
    path    => "${filepath}config",
    content => template('doazure/config.erb'),
  }

  file { "doazure-clouds-config-${user}" :
    path    => "${filepath}clouds.config",
    content => template('doazure/clouds.config.erb'),
  }

  file { "doazure-cert-pem-${user}" :
    path    => "${filepath}${cert_name}-cert.pem",
    content => "${cert_pem}"
  }
  file { "doazure-cert-crt-${user}" :
    path    => "${filepath}${cert_name}-cert.crt",
    content => "${cert_crt}"
  }

  case $operatingsystem {
    centos, redhat, fedora,
    ubuntu, debian: {
      # create a script file for required environment variables
      file { "doazure-environment-${user}" :
        path    => "${filepath}environment",
        content => template('doazure/environment.erb'),
      }
      # if there's an open bashrc
      if defined(Concat["/home/${user}/.bashrc"]) {
        # add line to include environment variables
        $command_bash_include_azenv = "\n# add Azure environment variables if present\nif [ -f ${filepath}environment ]; then\n        source ${filepath}environment\nfi\n"
        concat::fragment { "doazure-bashrc-environment-${user}":
          target  => "/home/${user}/.bashrc",
          content => $command_bash_include_azenv,
          order   => '20',
        }
      }
      # generate pfx file from pem
      exec { "doazure-generate-cert-pfx-${user}" :
        command => "/usr/bin/openssl pkcs12 -export -out ${filepath}${cert_name}-cert.pfx -in ${filepath}${cert_name}-cert.pem -passout pass: ; chown ${user}:${user} ${filepath}${cert_name}-cert.pfx",
        require => [File["doazure-cert-pem-${user}"]],
        creates => "${filepath}${cert_name}-cert.pfx",
      }
    }
    windows: {
      #
      # Windows install only partially built, doesn't work yet
      #

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

