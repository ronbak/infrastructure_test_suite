try {
    setGitHubPullRequestStatus state: 'PENDING', context: "${env.JOB_NAME}", message: "Run #${env.BUILD_NUMBER} started"
    node {
        stage ('Checkout from GitHub') {
            checkout([$class: 'GitSCM', branches: [[name: '${GITHUB_PR_SOURCE_BRANCH}']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'arm_templates']], submoduleCfg: [], userRemoteConfigs: [[credentialsId: '2c74e2d9-4e99-4f84-86fc-affb2559331f', url: 'git@github.com:Worldremit/arm_templates.git']]])
        }
        stage ('checkout test tools') {
            checkout([$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'infrastructure_test_suite']], submoduleCfg: [], userRemoteConfigs: [[credentialsId: '2c74e2d9-4e99-4f84-86fc-affb2559331f', url: 'git@github.com:chudsonwr/infrastructure_test_suite.git']]])
        }
        stage ('run some tests'){
            sh "echo 'this is a test'"
            sh "ls -lah && cd arm_templates && cat test_for_merge.txt"
            sh "cd infrastructure_test_suite && ls -lah"
        }
        stage ('notify git hub') {
            setGitHubPullRequestStatus context: "${env.JOB_NAME}", message: 'SUCCESS', state: 'SUCCESS'
        }
    }
} catch (Exception e) {
    setGitHubPullRequestStatus context: "${env.JOB_NAME}", message: 'FAILED', state: 'FAILURE'
    throw e
}
    
    