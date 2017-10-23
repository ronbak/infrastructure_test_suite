node {
  stage ('CheckoutRequiredRepoFromGitHub'){
    //checkout hprod-migration repo   
    checkout([$class: 'GitSCM', branches: [[name: '*/${branch}']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'infrastructure_test_suite']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:chudsonwr/infrastructure_test_suite.git']]])
    //chechout fps repo
    checkout([$class: 'GitSCM', branches: [[name: "*/master"]], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'arm_templates']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:Worldremit/arm_templates.git']]])
    sh "cd infrastructure_test_suite/ && git submodule update --init --recursive"
  }
  stage ('BuildTemplates'){
    withCredentials([string(credentialsId: 'github_PAC_chudson', variable: 'GIT_ACCESS_TOKEN'),
    string(credentialsId: 'octopus-csre-app-wr', variable: 'AZURE_CLIENT_SECRET'),
    string(credentialsId: 'xycsrecore01-key', variable: 'AZURE_STORAGE_ACCOUNT_KEY'),]) {
      env.CSRE_LOG_LEVEL = "${log_level}"
      sh "ruby infrastructure_test_suite/bin/provision.rb --action output --output ./core_network.json --environment core --config arm_templates/networks/configs/networking_core.config.json --complete --prep_templates"      
    }
  }
  stage ('CreatePackage'){
    shortCommit = sh(returnStdout: true, script: "cd arm_templates && git log -n 1 --pretty=format:'%h'").trim()
    sh "zip core_networks.1.0.0.${BUILD_NUMBER}.zip core_network.json core_network.parameters.json"
  }
  stage ('RunSomeTestsOnTheJson') {
    withCredentials([string(credentialsId: 'github_PAC_chudson', variable: 'GIT_ACCESS_TOKEN'),
    string(credentialsId: 'octopus-csre-app-wr', variable: 'AZURE_CLIENT_SECRET'),
    string(credentialsId: 'core-storage-account-key', variable: 'AZURE_STORAGE_ACCOUNT_KEY'),]) {
      env.CSRE_LOG_LEVEL = "${log_level}"
      echo 'Testing Core templates'
      sh "ruby infrastructure_test_suite/bin/provision.rb --action validate --output ./core_network.json --config arm_templates/networks/configs/networking_core.config.json --environment nonprd"
    }
    sh "ruby infrastructure_test_suite/tests/template/network_templates_tests.rb"
  }
  stage ('PushDeployOctopus'){
    withCredentials([string(credentialsId: 'octopus_api_key', variable: 'octopus_api_key')]){
      //sh "ruby infrastructure_test_suite/scripts/create_octopus_release.rb -a ${octopus_api_key} -p deploy-core-network -e csre-core -f core_networks.1.0.0.${BUILD_NUMBER}.zip -s deploy_arm_template"
    }
  }
}