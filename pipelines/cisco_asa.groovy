node {
  stage ('CheckoutRequiredRepoFromGitHub'){
    //checkout arm_templates repo   
    checkout([$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'infrastructure_test_suite']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:chudsonwr/infrastructure_test_suite.git']]])
    //chechout csre_infra_tool repo
    checkout([$class: 'GitSCM', branches: [[name: "*/${branch}"]], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'arm_templates']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:Worldremit/arm_templates.git']]])
  }
  stage ('ValidateTemplate'){
    withCredentials([string(credentialsId: 'octopus-csre-app-wr', variable: 'AZURE_CLIENT_SECRET'),]) {
      env.CSRE_LOG_LEVEL = "${log_level}"
      sh "ruby infrastructure_test_suite/bin/provision.rb --action validate --output ./arm_templates/csre/networkdevices/ciscoasav/cisco-asav-ha-mono-fast/asav-ha-template.json --environment core --resource-group cisco-asav-ha-rg-core-wr"      
    }
  }
  stage ('CreatePackage'){
    sh "cd arm_templates/csre/networkdevices/ciscoasav/cisco-asav-ha-mono-fast/ && zip asav-core.1.0.0.${BUILD_NUMBER}.zip asav-ha-template.json asav-ha-param.json && mv asav-core.1.0.0.${BUILD_NUMBER}.zip ../../../../../asav-core.1.0.0.${BUILD_NUMBER}.zip"
  }
  stage ('PushDeployOctopus'){
    withCredentials([string(credentialsId: 'octopus_api_key', variable: 'octopus_api_key')]){
      sh "ruby infrastructure_test_suite/scripts/create_octopus_release.rb -a ${octopus_api_key} -p deploy-core-asav -e csre-core -f asav-core.1.0.0.${BUILD_NUMBER}.zip -s deploy_asav_template"
    }
  }
}