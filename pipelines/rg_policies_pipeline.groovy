node {
  stage ('CheckoutRequiredRepoFromGitHub'){
    //checkout hprod-migration repo   
    checkout([$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'infrastructure_test_suite']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:chudsonwr/infrastructure_test_suite.git']]])
    //chechout fps repo
    checkout([$class: 'GitSCM', branches: [[name: "*/master"]], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'arm_templates']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:Worldremit/arm_templates.git']]])
    sh "cd infrastructure_test_suite/ && git submodule update --init --recursive"
  }
  withEnv(["CSRE_LOG_LEVEL=${log_level}"]) {
    withCredentials([string(credentialsId: 'github_PAC_chudson', variable: 'GIT_ACCESS_TOKEN'),
    string(credentialsId: 'octopus-csre-app-wr', variable: 'AZURE_CLIENT_SECRET'),]) {
      switch(action) {
        case "deploy":
        stage ('DeployPolicy'){
          
          sh "ruby infrastructure_test_suite/bin/provision.rb --action deploy_policy --environment ${subscription} --config ${policy_template} --complete --prep_templates"      
        }
        case "assign":
        stage ('AssignPolicy'){
          sh "ruby infrastructure_test_suite/bin/provision.rb --action assign_policy --environment ${subscription} --config ${policy_template} --complete --prep_templates"      
        }
        case "deployAndAssign":
        stage ('DeployPolicy'){
          sh "ruby infrastructure_test_suite/bin/provision.rb --action deploy_policy --environment ${subscription} --config ${policy_template} --complete --prep_templates"      
        }
        stage ('AssignPolicy'){
          sh "ruby infrastructure_test_suite/bin/provision.rb --action assign_policy --environment ${subscription} --config ${policy_template} --complete --prep_templates"      
        }
      }
    }
  }
}
