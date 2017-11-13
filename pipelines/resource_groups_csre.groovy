node {
  stage ('CheckoutRequiredRepoFromGitHub'){
    checkout([$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'infrastructure_test_suite']], gitTool: 'Default', submoduleCfg: [], userRemoteConfigs: [[url: 'git@github.com:chudsonwr/infrastructure_test_suite.git']]])
  }
  withEnv(["CSRE_LOG_LEVEL=DEBUG"]) {
    withCredentials([string(credentialsId: 'Github_PAC_csreautomation', variable: 'GIT_ACCESS_TOKEN'),
    string(credentialsId: 'octopus-csre-app-wr', variable: 'AZURE_CLIENT_SECRET'),]) {
        stage ('test supplied template'){
            withEnv(["template=${template}"]){
                sh "ruby infrastructure_test_suite/tests/template/rg_tests.rb"
            }
        }
        stage ('ProcessRG'){
            sh "ruby infrastructure_test_suite/bin/provision.rb --action deploy_resource_groups --environment ${environment} --config '${template}' --complete --prep_templates"      
        }
    }
  }
}