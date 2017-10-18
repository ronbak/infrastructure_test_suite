try {
    setGitHubPullRequestStatus state: 'PENDING', context: "${env.JOB_NAME}", message: "Run #${env.BUILD_NUMBER} started"
    node {
        stage ('Checkout branch from GitHub') {
            checkout([$class: 'GitSCM', branches: [[name: '${GITHUB_PR_SOURCE_BRANCH}'], [name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'arm_templates']], submoduleCfg: [], userRemoteConfigs: [[credentialsId: '2c74e2d9-4e99-4f84-86fc-affb2559331f', url: 'git@github.com:Worldremit/arm_templates.git']]])
        }
        stage ('Checkout master from GitHub') {
            checkout([$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'arm_templates-master']], submoduleCfg: [], userRemoteConfigs: [[credentialsId: '2c74e2d9-4e99-4f84-86fc-affb2559331f', url: 'git@github.com:Worldremit/arm_templates.git']]])
        }
        stage ('checkout test tools') {
            checkout([$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'infrastructure_test_suite']], submoduleCfg: [], userRemoteConfigs: [[credentialsId: '2c74e2d9-4e99-4f84-86fc-affb2559331f', url: 'git@github.com:chudsonwr/infrastructure_test_suite.git']]])
        }
        stage ('run some tests'){
            masterCommit = sh(returnStdout: true, script: "cd arm_templates-master && git log -n 1 --pretty=format:'%H'").trim()
            branchCommit = sh(returnStdout: true, script: "cd arm_templates && git log -n 1 --pretty=format:'%H'").trim()
            println masterCommit
            println branchCommit
            sh "cd arm_templates && ruby ../infrastructure_test_suite/tests/template/templates_tests.rb ./  ${masterCommit} ${branchCommit}"
            filesChanged = sh(returnStdout: true, script: "cd arm_templates && git diff --name-only ${masterCommit} ${branchCommit}").trim()
            if (filesChanged.contains('/networks/')) {

            }
        }
        stage ('set network update') {
            fullPath =  sh(returnStdout: true, script: "pwd").trim()
            networksToDeploy = new File("${fullPath}/arm_templates/networks_to_deploy.txt").text
            println networksToDeploy
        }
        switch(networksToDeploy) {
            case "nonprd":
            stage ('Create NonPrd release in octopus') {
                echo 'deploying to nonprd'
            }
        }
        stage ('notify git hub') {
            setGitHubPullRequestStatus context: "${env.JOB_NAME}", message: 'SUCCESS', state: 'SUCCESS'
        }
    }
} catch (Exception e) {
    setGitHubPullRequestStatus context: "${env.JOB_NAME}", message: 'FAILED', state: 'FAILURE'
    throw e
}
