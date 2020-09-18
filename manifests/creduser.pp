define doazure::creduser (

  # class arguments
  # ---------------
  # setup defaults

  $user                 = $title,
  $group                = $title,

  # customisable constants
  $folder_name          = '.azure',

  # template vars
  $cloud_name           = 'AzureCloud',
  $domain_name          = 'example.com',
  $client_id            = '',
  $client_secret        = '',
  $object_id            = '',
  $tenant_name          = '',
  $tenant_directory_id  = '',
  $admin_user_object_id = '',
  $subscription         = '',
  $cert_name            = '',
  $cert_pem             = '',
  $cert_crt             = '',

  # optional template vars
  $storage_account_access_key = undef,
  $azure_devops = {},

  # end of class arguments
  # ----------------------
  # begin class

) {

  $filepath_linux = "/home/${user}/${folder_name}/"
  $filepath_win = "C:\\Users\\${user}\\${folder_name}\\"
  $filepath_cygwin = "/cygdrive/c/Users/${user}/${folder_name}/"
  case $operatingsystem {
    centos, redhat, oraclelinux, fedora, ubuntu, debian: {
      $filepath = $filepath_linux
      $filecertroot = $filepath_linux
    }
    windows: {
      $filepath = $filepath_win
      $filecertroot = $filepath_cygwin
    }
  }

  File {
    owner  => $user,
    group  => $group,
    ensure => 'file',
    mode   => '0640',
  }

  file { "doazure-dir-${user}":
    ensure => 'directory',
    path   => "${filepath}",
    mode   => '0750',
  }

  file { "doazure-config-${user}":
    path    => "${filepath}config",
    content => template('doazure/config.erb'),
  }

  file { "doazure-clouds-config-${user}":
    path    => "${filepath}clouds.config",
    content => template('doazure/clouds.config.erb'),
  }

  file { "doazure-cert-pem-${user}":
    path    => "${filepath}${cert_name}-cert.pem",
    content => "${cert_pem}",
  }
  file { "doazure-cert-crt-${user}":
    path    => "${filepath}${cert_name}-cert.crt",
    content => "${cert_crt}",
  }
  $command_pfxgen = "/usr/bin/openssl pkcs12 -export -out ${filecertroot}${cert_name}-cert.pfx -in ${filecertroot}${
    cert_name}-cert.pem -passout pass: ; chown ${user}:${group} ${filecertroot}${cert_name}-cert.pfx"

  case $operatingsystem {
    centos, redhat, oraclelinux, fedora, ubuntu, debian: {
      # create a script file for required environment variables
      file { "doazure-environment-${user}":
        path    => "${filepath}environment",
        content => template('doazure/environment.erb'),
      }
      concat::fragment { "doazure-bashrc-environment-${user}":
        target  => "/home/${user}/.bashrc",
        order   => '40',
        content => "# Add Azure settings as environment variables\nif [ -f ${filepath}environment ]; then source ${
          filepath}environment; fi\n",
      }
      # generate pfx file from pem
      exec { "doazure-generate-cert-pfx-${user}":
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
        variable  => 'ARM_SUBSCRIPTION_ID',
        value     => $subscription,
      }
      windows_env { "doazure-envvar-tenant-id-${user}":
        user      => "${user}",
        mergemode => 'clobber',
        variable  => 'ARM_TENANT_ID',
        value     => $tenant_directory_id,
      }
      windows_env { "doazure-envvar-client-id-${user}":
        user      => "${user}",
        mergemode => 'clobber',
        variable  => 'ARM_CLIENT_ID',
        value     => $client_id,
      }
      windows_env { "doazure-envvar-client-cert-path-${user}":
        user      => "${user}",
        mergemode => 'clobber',
        variable  => 'ARM_CLIENT_CERTIFICATE_PATH',
        value     => "${filepath}${cert_name}-cert.pfx",
      }
      if ($storage_account_access_key != undef) {
        windows_env { "doazure-envvar-storage-acckey-${user}":
          user      => "${user}",
          mergemode => 'clobber',
          variable  => 'ARM_ACCESS_KEY',
          value     => $storage_account_access_key,
        }
      }
      if ($azure_devops != {}) {
        if ($azure_devops['org_service_url'] != undef) {
          windows_env { "doazure-envvar-azuredevops-orgservurl-${user}":
            user      => "${user}",
            mergemode => 'clobber',
            variable  => 'AZDO_ORG_SERVICE_URL',
            value     => $azure_devops['org_service_url'],
          }
        }
        if ($azure_devops['personal_access_token'] != undef) {
          windows_env { "doazure-envvar-azuredevops-pat-${user}":
            user      => "${user}",
            mergemode => 'clobber',
            variable  => 'AZDO_PERSONAL_ACCESS_TOKEN',
            value     => $azure_devops['personal_access_token'],
          }
        }
      }
      windows_env { "doazure-envvar-admin-client-id-${user}":
        user      => "${user}",
        mergemode => 'clobber',
        variable  => 'TF_VAR_client_id',
        value     => $client_id,
      }
      windows_env { "doazure-envvar-admin-client-secret-${user}":
        user      => "${user}",
        mergemode => 'clobber',
        variable  => 'TF_VAR_client_secret',
        value     => $client_secret,
      }
      windows_env { "doazure-envvar-tenant-directory-id-${user}":
        user      => "${user}",
        mergemode => 'clobber',
        variable  => 'TF_VAR_tenant_directory_id',
        value     => $tenant_directory_id,
      }
      windows_env { "doazure-envvar-admin-user-object-id-${user}":
        user      => "${user}",
        mergemode => 'clobber',
        variable  => 'TF_VAR_admin_user_object_id',
        value     => $admin_user_object_id,
      }

      # generate the pfx file
      if defined(dowindows::cygwin::run) {
        dowindows::cygwin::run { "doazure-generate-cert-pfx-${user}":
          command => "${command_pfxgen}",
          creates => "${filepath}${cert_name}-cert.pfx",
          require => [File["doazure-cert-pem-${user}"]],
        }
      }
    }
  }

}

