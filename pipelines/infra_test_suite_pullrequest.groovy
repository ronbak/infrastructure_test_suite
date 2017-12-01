try {
    setGitHubPullRequestStatus state: 'PENDING', context: "${env.JOB_NAME}", message: "Run #${env.BUILD_NUMBER} started"
    node {
        stage ('Checkout branch from GitHub') {
            checkout([$class: 'GitSCM', branches: [[name: '${GITHUB_PR_SOURCE_BRANCH}']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'infrastructure_test_suite']], submoduleCfg: [], userRemoteConfigs: [[credentialsId: '2c74e2d9-4e99-4f84-86fc-affb2559331f', url: 'git@github.com:chudsonwr/infrastructure_test_suite.git']]])
        }
        stage ('run some tests'){
            withCredentials([string(credentialsId: 'Github_PAC_csreautomation', variable: 'GIT_ACCESS_TOKEN'),
            string(credentialsId: 'gitlab_access_token_chudson', variable: 'GITLAB_ACCESS_TOKEN'),
            string(credentialsId: 'octopus-csre-app-wr', variable: 'AZURE_CLIENT_SECRET'),
            string(credentialsId: 'nonprd-storage-account-key', variable: 'AZURE_STORAGE_ACCOUNT_KEY'),]) {
                sh "cd infrastructure_test_suite && rake"
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
