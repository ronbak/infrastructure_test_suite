node {
  stage ('CheckoutRequiredRepoFromGitHub'){
    checkout([$class: 'GitSCM', branches: [[name: "*/${branch}"]], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'infrastructure_test_suite']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:chudsonwr/infrastructure_test_suite.git']]])
  }
  stage ('Build RG Template'){
    sh "ruby infrastructure_test_suite/scripts/create_resource_group_template.rb"      
    
  }
  stage ('Test RG Template'){
    withEnv(["template=${name}.json"]){
      sh "ruby infrastructure_test_suite/tests/template/rg_tests.rb"
    }
  }
  stage ('Deploy Resource Groups NonPrd'){
    withCredentials([string(credentialsId: 'github_PAC_chudson', variable: 'GIT_ACCESS_TOKEN'),
    string(credentialsId: 'octopus-csre-app-wr', variable: 'AZURE_CLIENT_SECRET'),
    string(credentialsId: 'prd-storage-account-key', variable: 'AZURE_STORAGE_ACCOUNT_KEY'),]) {
      env.CSRE_LOG_LEVEL = "${log_level}"
      env.name = "${name}"
      env.group_name = "${group_name}"
      env.OwnerContact = "${OwnerContact}"
      env.Project = "${Project}"
      env.RunModel = "${RunModel}"
      sh "ruby infrastructure_test_suite/bin/provision.rb --action deploy_resource_groups --environment nonprd --config ${name}.json"      
    }
  }
}