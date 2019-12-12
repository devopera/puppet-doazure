define doazure::creduser (

  # class arguments
  # ---------------
  # setup defaults

  $user = $title,
  $group = $title,

  # template vars
  $cloud_name = 'AzureCloud',
  $domain_name = 'example.com',
  $client_id = '',
  $object_id = '',
  $tenant_name = '',
  $tenant_directory_id = '',
  $admin_user_object_id = '',
  $subscription = '',
  $cert_name = '',
  $cert_pem = '',
  $cert_crt = '',

  # end of class arguments
  # ----------------------
  # begin class

) {

  # No need for notify any more
  # $mess = 'This module installs all the necessary files and environment variables. `az login` should not be required in each of the using environments (windows cmd and cygwin)'
  # notify { "doazure-creduser-azlog-${title}" : message => "${mess}" }

  $filepath_linux = "/home/${user}/.azure/"
  $filepath_win = "C:\\Users\\${user}\\.azure\\"
  $filepath_cygwin = "/cygdrive/c/Users/${user}/.azure/"
  case $operatingsystem {
    centos, redhat, fedora,
    ubuntu, debian: {
      $filepath = $filepath_linux
      $filecertroot = $filepath_linux
    }
    windows: {
      $filepath = $filepath_win
      $filecertroot = $filepath_cygwin
    }
  }

  File {
    owner => $user,
    group => $group,
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
  $command_pfxgen = "/usr/bin/openssl pkcs12 -export -out ${filecertroot}${cert_name}-cert.pfx -in ${filecertroot}${cert_name}-cert.pem -passout pass: ; chown ${user}:${group} ${filecertroot}${cert_name}-cert.pfx"

  case $operatingsystem {
    centos, redhat, fedora,
    ubuntu, debian: {
      # create a script file for required environment variables
      file { "doazure-environment-${user}" :
        path    => "${filepath}environment",
        content => template('doazure/environment.erb'),
      }
      concat::fragment { "doazure-bashrc-environment-${user}":
        target  => "/home/${user}/.bashrc",
        order   => '40',
        content => @("END")
      # add Azure environment variables if present
      if [ -f ${filepath}environment ]; then
        source ${filepath}environment
      fi
      | END
      }
      # generate pfx file from pem
      exec { "doazure-generate-cert-pfx-${user}" :
        command => "${command_pfxgen}",
        require => [File["doazure-cert-pem-${user}"]],
        creates => "${filepath}${cert_name}-cert.pfx",
      }
    }
    windows: {
      # create environment vars in registry, per user
      windows_env { "doazure-envvar-sub-sid-${user}":
        user      => "${user}",
        mergemode => 'clobber',
        variable => 'ARM_SUBSCRIPTION_ID',
        value => $subscription,
      }
      windows_env { "doazure-envvar-tenant-id-${user}":
        user      => "${user}",
        mergemode => 'clobber',
        variable => 'ARM_TENANT_ID',
        value => $tenant_directory_id,
      }
      windows_env { "doazure-envvar-client-id-${user}":
        user      => "${user}",
        mergemode => 'clobber',
        variable => 'ARM_CLIENT_ID',
        value => $client_id,
      }
      windows_env { "doazure-envvar-client-cert-path-${user}":
        user      => "${user}",
        mergemode => 'clobber',
        variable => 'ARM_CLIENT_CERTIFICATE_PATH',
        value => "${filepath}${cert_name}-cert.pfx",
      }
      windows_env { "doazure-envvar-tenant-directory-id-${user}":
        user      => "${user}",
        mergemode => 'clobber',
        variable => 'TF_VAR_tenant_directory_id',
        value => $tenant_directory_id,
      }
      windows_env { "doazure-envvar-admin-user-object-id-${user}":
        user      => "${user}",
        mergemode => 'clobber',
        variable => 'TF_VAR_admin_user_object_id',
        value => $admin_user_object_id,
      }
      # generate the pfx file
      if defined(windows::cygwin_run) {
        windows::cygwin_run { "doazure-generate-cert-pfx-${user}":
          command => "${command_pfxgen}",
          creates => "${filepath}${cert_name}-cert.pfx",
          require => [File["doazure-cert-pem-${user}"]],
        }
      }
    }
  }

}

