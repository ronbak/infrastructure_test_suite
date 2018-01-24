import groovy.json.*

node {
  stage ('CheckoutRequiredRepoFromGitHub'){
    //checkout hprod-migration repo   
    checkout([$class: 'GitSCM', branches: [[name: "*/${branch}"]], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'infrastructure_test_suite']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:chudsonwr/infrastructure_test_suite.git']]])
    //chechout fps repo
    checkout([$class: 'GitSCM', branches: [[name: "*/master"]], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'arm_templates']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:Worldremit/arm_templates.git']]])
    sh "cd infrastructure_test_suite/ && git submodule update --init --recursive"
  }
  stage ('PrepareTemplate'){
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
      println template
      switch(template) {
        case "basicInternalCluster":
          config_path = "arm_templates/csre/servicefabric/basicInternalCluster.config.json"
          break
        case "dualNodeType":
          config_path = "arm_templates/csre/servicefabric/dualNodeTypeCluster.config.json"
          break
        case "internalMidCluster":
          config_path = "arm_templates/csre/servicefabric/internalMidCluster.config.json"
          break
        case "publicMidCluster":
          config_path = "arm_templates/csre/servicefabric/publicMidCluster.config.json"
          break
        case "internalMasterCluster":
          config_path = "arm_templates/csre/servicefabric/master/internalMasterCluster.config.json"
          break
        default:
          config_path = "not_a_file"
          break
      }
      println config_path
      env.WORKSPACE = pwd()
      def fileContents = readFile "${env.WORKSPACE}/${config_path}"

      def parsedConfig = new JsonSlurperClassic().parseText(fileContents)
      if(clusterName){
        parsedConfig.parameters.name.value = clusterName
      }
      if(clusterApplication){
        parsedConfig.environments."${environment}".parameters.clusterApplication.value = clusterApplication
      }
      if(clientApplication){
        parsedConfig.environments."${environment}".parameters.clientApplication.value = clientApplication
      }

      parsedConfig.environments."${environment}".resource_group_name = "${clusterName}-rg-${environment}-wr"

      def json = JsonOutput.toJson(parsedConfig)
      println json
      env.JSON_CONFIG = json
    }
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
      sh "ruby infrastructure_test_suite/bin/provision.rb --action ${action} --environment ${environment} --config '${env.JSON_CONFIG}' --complete --prep_templates"
    }      
  }
}
