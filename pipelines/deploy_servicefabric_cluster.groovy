import groovy.json.*

node {
  stage ('CheckoutRequiredRepoFromGitHub'){
    //checkout hprod-migration repo   
    checkout([$class: 'GitSCM', branches: [[name: "*/${branch}"]], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'infrastructure_test_suite']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:chudsonwr/infrastructure_test_suite.git']]])
    //chechout fps repo
    checkout([$class: 'GitSCM', branches: [[name: "*/master"]], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'arm_templates']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:Worldremit/arm_templates.git']]])
    sh "cd infrastructure_test_suite/ && git submodule update --init --recursive"
  }
  stage ('DeployTemplate'){
    withCredentials([string(credentialsId: 'Github_PAC_csreautomation', variable: 'GIT_ACCESS_TOKEN'),
    string(credentialsId: 'octopus-csre-app-wr', variable: 'AZURE_CLIENT_SECRET'),
    string(credentialsId: 'nonprd-storage-account-key', variable: 'AZURE_STORAGE_ACCOUNT_KEY_NP'),
    string(credentialsId: 'prd-storage-account-key', variable: 'AZURE_STORAGE_ACCOUNT_KEY_P'),
    string(credentialsId: 'core-storage-account-key', variable: 'AZURE_STORAGE_ACCOUNT_KEY_C'),]) {
      env.CSRE_LOG_LEVEL = "${log_level}"
      switch(environment) {
        case "prd":
        env.AZURE_STORAGE_ACCOUNT_KEY = env.AZURE_STORAGE_ACCOUNT_KEY_P
        case "core":
        env.AZURE_STORAGE_ACCOUNT_KEY = env.AZURE_STORAGE_ACCOUNT_KEY_C
        default:
        env.AZURE_STORAGE_ACCOUNT_KEY = env.AZURE_STORAGE_ACCOUNT_KEY_NP
      }
      switch(template) {
        case "basicInternalCluster":
        config_path = "./arm_templates/csre/servicefabric/basicInternalCluster.config.json"
        case "dualNodeType":
        config_path = "./arm_templates/csre/servicefabric/dualNodeTypeCluster.config.json"
        default:
        config_path = ""
      }
      String fileContents = new File(config_path).text
      def parsedConfig = new JsonSlurper().parseText(fileContents)
      parsedConfig.parameters.name.value = clusterName

      def json = JsonOutput.toJson(parsedConfig)

      sh "ruby infrastructure_test_suite/bin/provision.rb --action ${action} --environment ${environment} --config '${json}' --complete --prep_templates"
    }      
  }
}
