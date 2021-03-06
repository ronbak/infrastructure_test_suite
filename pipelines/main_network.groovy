node {
  stage ('CheckoutRequiredRepoFromGitHub'){
    //checkout hprod-migration repo   
    checkout([$class: 'GitSCM', branches: [[name: "*/${branch}"]], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'infrastructure_test_suite']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:chudsonwr/infrastructure_test_suite.git']]])
    //chechout fps repo
    checkout([$class: 'GitSCM', branches: [[name: "*/master"]], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'arm_templates']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:Worldremit/arm_templates.git']]])
  }
  stage ('BuildNonPrdTemplates'){
    withCredentials([string(credentialsId: 'Github_PAC_csreautomation', variable: 'GIT_ACCESS_TOKEN'),
    string(credentialsId: 'octopus-csre-app-wr', variable: 'AZURE_CLIENT_SECRET'),
    string(credentialsId: 'nonprd-storage-account-key', variable: 'AZURE_STORAGE_ACCOUNT_KEY'),]) {
      env.CSRE_LOG_LEVEL = "${log_level}"
      sh "ruby infrastructure_test_suite/bin/provision.rb --action output --output ./nonprd_network.json --environment nonprd --config arm_templates/networks/configs/networking_master.config.json --complete --prep_templates"      
    }
  }
  stage ('BuildPrdTemplates'){
    withCredentials([string(credentialsId: 'Github_PAC_csreautomation', variable: 'GIT_ACCESS_TOKEN'),
    string(credentialsId: 'octopus-csre-app-wr', variable: 'AZURE_CLIENT_SECRET'),
    string(credentialsId: 'prd-storage-account-key', variable: 'AZURE_STORAGE_ACCOUNT_KEY'),]) {
      env.CSRE_LOG_LEVEL = "${log_level}"
      sh "ruby infrastructure_test_suite/bin/provision.rb --action output --output ./prd_network.json --environment prd --config arm_templates/networks/configs/networking_master.config.json --complete --prep_templates"      
    }
  }
  stage ('CreatePackage'){
    shortCommit = sh(returnStdout: true, script: "cd arm_templates && git log -n 1 --pretty=format:'%h'").trim()
    sh "cd arm_templates && git log -n 1 > gitinfo.txt"
    sh "zip main_networks.1.0.1.${BUILD_NUMBER}.zip nonprd_network.json nonprd_network.parameters.json prd_network.json prd_network.parameters.json gitinfo.txt"
  }
  stage ('RunSomeTestsOnTheJson') {
    withCredentials([string(credentialsId: 'Github_PAC_csreautomation', variable: 'GIT_ACCESS_TOKEN'),
    string(credentialsId: 'octopus-csre-app-wr', variable: 'AZURE_CLIENT_SECRET'),
    string(credentialsId: 'nonprd-storage-account-key', variable: 'AZURE_STORAGE_ACCOUNT_KEY'),]) {
      env.CSRE_LOG_LEVEL = "${log_level}"
      echo 'Testing NonPrd templates'
      sh "ruby infrastructure_test_suite/bin/provision.rb --action validate --output ./nonprd_network.json --config arm_templates/networks/configs/networking_master.config.json --environment nonprd"
    }
    withCredentials([string(credentialsId: 'Github_PAC_csreautomation', variable: 'GIT_ACCESS_TOKEN'),
    string(credentialsId: 'octopus-csre-app-wr', variable: 'AZURE_CLIENT_SECRET'),
    string(credentialsId: 'prd-storage-account-key', variable: 'AZURE_STORAGE_ACCOUNT_KEY'),]) {
      env.CSRE_LOG_LEVEL = "${log_level}"
      sh "echo 'Testing Prd templates'"
      sh "ruby infrastructure_test_suite/bin/provision.rb --action validate --output ./prd_network.json --config arm_templates/networks/configs/networking_master.config.json --environment prd"
    }
    sh "ruby infrastructure_test_suite/tests/template/network_templates_tests.rb"
  }
  stage ('PushDeployOctopus'){
    withCredentials([string(credentialsId: 'octopus_api_key', variable: 'octopus_api_key')]){
      sh "ruby infrastructure_test_suite/scripts/create_octopus_release.rb -a ${octopus_api_key} -p deploy-main-network -e csre-nonproduction-arm -f main_networks.1.0.1.${BUILD_NUMBER}.zip -s 'deploy-nonprd-template deploy-prd-template'"
    }
  }
  stage ('CleanUp'){
    sh "rm -rf *.zip"
  }
}