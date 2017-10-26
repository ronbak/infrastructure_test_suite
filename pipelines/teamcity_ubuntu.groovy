node {
  stage ('CheckoutRequiredRepoFromGitHub'){
    //checkout hprod-migration repo   
    checkout([$class: 'GitSCM', branches: [[name: "*/${branch}"]], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'infrastructure_test_suite']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:chudsonwr/infrastructure_test_suite.git']]])
    //chechout fps repo
    checkout([$class: 'GitSCM', branches: [[name: "*/master"]], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'arm_templates']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:Worldremit/arm_templates.git']]])
    sh "cd infrastructure_test_suite/ && git submodule update --init --recursive"
  }
  stage ('DeployteamCity-Core'){
    withCredentials([string(credentialsId: 'github_PAC_chudson', variable: 'GIT_ACCESS_TOKEN'),
    string(credentialsId: 'octopus-csre-app-wr', variable: 'AZURE_CLIENT_SECRET'),
    string(credentialsId: 'nonprd-storage-account-key', variable: 'AZURE_STORAGE_ACCOUNT_KEY'),]) {
      env.CSRE_LOG_LEVEL = "${log_level}"
      sh "ruby infrastructure_test_suite/bin/provision.rb --action deploy --environment core --config arm_templates/vms/teamcity_ubuntu.config.json --complete --prep_templates"      
    }
  }
}