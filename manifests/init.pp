class doazure (

  # class arguments
  # ---------------
  # setup defaults

  $user = undef,
  $users = hiera('doazure::users', {}),
  $user_defaults = hiera('doazure::user_defaults', {}),
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
    centos, redhat, fedora: {
      # MS repo install requires CO7 or above
      # if (Float($::operatingsystemmajrelease >= 7)) {
      if ($::operatingsystemmajrelease == "7") {
        yumrepo { 'azure-cli':
          baseurl  => 'https://packages.microsoft.com/yumrepos/azure-cli',
          enabled  => 1,
          gpgcheck => 1,
          gpgkey   => 'https://packages.microsoft.com/keys/microsoft.asc',
          descr    => 'Microsoft Azure CLI install repo',
          before   => [Package['azure-cli']],
        }
        if ! defined(Package['azure-cli']) {
          package { 'azure-cli' :
            ensure => 'present',
          }
        }
      }
    }
  }

  # create single user if details passed in vars
  if ($user != undef) {
    doazure::creduser { 'doazure-creduser-default-user' :
      user => $user,
      cloud_name => $cloud_name,
      domain_name => $domain_name,
      client_id => $client_id,
      tenant_id => $tenant_id,
      subscription => $subscription,
      cert_name => $cert_name,
      cert_pem => $cert_pem,
      cert_crt => $cert_crt,
    }
  }

  # create multiple users if details passed in hash
  if ($users != {}) {
    create_resources(doazure::creduser, $users, $user_defaults)
  }

}

