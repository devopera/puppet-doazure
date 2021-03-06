class doazure (

  # class arguments
  # ---------------
  # setup defaults

  $user = undef,
  $group = $user,
  $users = {},
  $user_defaults = {},

  # template vars
  $cloud_name = 'AzureCloud',
  $domain_name = 'example.com',
  $client_id = '',
  $client_secret = '',
  $object_id = '',
  $tenant_name = '',
  $tenant_directory_id = '',
  $admin_user_object_id = '',
  $subscription = '',
  $cert_name = '',
  $cert_pem = '',
  $cert_crt = '',

  # optional template vars
  $storage_account_access_key = undef,
  $azure_devops = {},

  # end of class arguments
  # ----------------------
  # begin class

) {

  case $operatingsystem {
    centos, redhat, oraclelinux, fedora: {
      # MS repo install requires CO7 or above
      # if (Float($::operatingsystemmajrelease >= 7)) {
      if ($::operatingsystemmajrelease == "7") {
        yumrepo { 'azure-cli':
          baseurl  => 'https://packages.microsoft.com/yumrepos/azure-cli',
          enabled  => 1,
          gpgcheck => 1,
          gpgkey   => 'https://packages.microsoft.com/keys/microsoft.asc',
          descr    => 'Microsoft Azure CLI install repo',
        }
        ensure_packages(['azure-cli'], { ensure => 'present', require => [Yumrepo['azure-cli']] })
      }
    }
    ubuntu, debian: {
      ensure_packages(['azure-cli'], { ensure => 'present'} )
    }
    windows: {
      ensure_packages(['azure-cli'], { provider => 'chocolatey', })
    }
  }

  # create single user if details passed in vars
  if ($user != undef) {
    doazure::creduser { 'doazure-creduser-default-user' :
      user => $user,
      group => $group,
      cloud_name => $cloud_name,
      domain_name => $domain_name,
      client_id => $client_id,
      client_secret => $client_secret,
      object_id => $object_id,
      tenant_name => $tenant_name,
      tenant_directory_id => $tenant_directory_id,
      admin_user_object_id => $admin_user_object_id,
      subscription => $subscription,
      cert_name => $cert_name,
      cert_pem => $cert_pem,
      cert_crt => $cert_crt,
      storage_account_access_key => $storage_account_access_key,
      azure_devops => $azure_devops,
    }
  }

  # create multiple users if details passed in hash
  if ($users != {}) {
    create_resources(doazure::creduser, $users, $user_defaults)
  }

}

