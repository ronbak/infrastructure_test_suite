import groovy.json.*
import groovyx.net.http.RESTClient
import static groovyx.net.http.ContentType.JSON

node{
  stage('verify_details'){
  }
  // Check repo not exist before commencing run....must be run outside of a stage to exit correctly
  withCredentials([string(credentialsId: 'Github_PAC_csreautomation', variable: 'GITHUB_ACCESS_TOKEN'),]){
    // Verify Repo doesn't exist, get list of repos
    def getRepos = new URL("https://api.github.com/orgs/Worldremit/repos?type=all").openConnection();
    getRepos.setRequestProperty("Authorization", "token $env.GITHUB_ACCESS_TOKEN")
    response = getRepos.getInputStream().getText();
    
    // get repo name
    def parsedRepos = new JsonSlurper().parseText(response)
    def repo = parsedRepos.find{
      it.name == projectName
    }
    if (repo){
      println "FATAL: The repo, ${projectName} already exists in Github, please choose another name."
      currentBuild.result = 'ABORTED'
      error('Stopping early…')
    }else{
      println 'The repo does not yet exist, creating'
    }
  }
  stage('clone_repo'){
    // Clone the tools repo so we can use some ruby scripts
    checkout([$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'infrastructure_test_suite']], submoduleCfg: [], userRemoteConfigs: [[credentialsId: '2c74e2d9-4e99-4f84-86fc-affb2559331f', url: 'git@github.com:chudsonwr/infrastructure_test_suite.git']]])
    // cleanup folders from previous runs and then clone the specified repo
    sh(returnStdout: true, script: "if [ -d source_repo ]; then rm -rf source_repo; fi")
    sh(returnStdout: true, script: "git clone $sourceRepo source_repo")
    sh(returnStdout: true, script: "if [ -d target_repo ]; then rm -rf target_repo; fi")
    sh(returnStdout: true, script: "cp -r source_repo target_repo")
    sh(returnStdout: true, script: "cd target_repo && rm -rf .git/")
  }
  stage('replace_names_TCBuild'){
    // find and replace any names from base repo - TODO: make more configurable
    sh(returnStdout: true, script: "ruby infrastructure_test_suite/scripts/rename_files_dirs.rb $projectName target_repo/.teamcity")
  }
  stage('commit_to_git'){
    withCredentials([string(credentialsId: 'Github_PAC_csreautomation', variable: 'GITHUB_ACCESS_TOKEN'),]){

      // get GitHub teams list
      println 'Getting GitHub teams list'
      def getTeams = new URL("https://api.github.com/orgs/Worldremit/teams").openConnection();
      getTeams.setRequestProperty("Authorization", "token $env.GITHUB_ACCESS_TOKEN")
      response = getTeams.getInputStream().getText();
      
      // get Github team id from teams list
      println "Finding team ID for ${env.repoteamAccess}"
      def parsedTeams = new JsonSlurper().parseText(response)
      def gitTeam = parsedTeams.find{
        it.name == env.repoTeamAccess
      }

      // Create GitHub repo
      println 'Creating repo........'
      url = "https://api.github.com/orgs/Worldremit/repos"
      @Grab (group = 'org.codehaus.groovy.modules.http-builder', module = 'http-builder', version = '0.5.0')
      def client = new RESTClient(url)
      def jsonString = "{ \"name\": \"${projectName}\", \"private\": true }"
      def tokenString = "token ${env.GITHUB_ACCESS_TOKEN}"
      def jsonObj = new JsonSlurper().parseText(jsonString)
      def response = client.post(contentType: JSON,
        body: jsonObj,
        headers: [Accept: 'application/json', Authorization: tokenString])
      println("Status: " + response.status)
      if (response.data) {
        println("Content Type: " + response.contentType)
        println response.data
      }

      // Add GitHub team as admins tonew repo
      println "Adding ${env.repoTeamAccess} with id ${gitTeam.id} as admins on repo"
      url = "https://api.github.com/teams/${gitTeam.id}/repos/Worldremit/${projectName}?permission=admin"
      def update_client = new RESTClient(url)
      def update_response = update_client.put(headers: [Authorization: tokenString])
      println("Status: " + update_response.status)
      if (update_response.data) {
        println("Content Type: " + update_response.contentType)
        println update_response.data
      }
    }
  }
  stage('new_git_commands'){
    // Commit to new repo
    println 'Committing to new repo'
    setupssh = "eval \"\$(ssh-agent -s)\" && ssh-add /var/lib/jenkins/.ssh/id_rsa_csre && cd target_repo"
    cleanssh = " ssh-agent -k"
    command = "git init && git add -A && git config --global user.email ${contactEmail} && git config --global user.name JenkinsCSRE && git commit -m \"CSRE automation initial commit\""
    command2 = "git remote add origin git@github.com:Worldremit/${projectName}.git && git push origin master"
    sh(returnStdout: true, script: "${setupssh} && ${command} && ${command2} && ${cleanssh}")
    //sh "eval \"\$(ssh-agent -s)\" && ssh-add /var/lib/jenkins/.ssh/id_rsa_csre && cd target_repo && git remote add origin git@github.com:Worldremit/$projectName.git && git push origin master && ssh-agent -k"
  }
  stage('create_octopus_project'){
    withCredentials([string(credentialsId: 'octokey', variable: 'OCTOPUS_API_KEY'),]){
      // get all projectgroup objects
      def get = new URL("https://octopusdeploy.worldremit.com/api/projectgroups/all").openConnection();
      get.setRequestProperty("X-Octopus-ApiKey", "$env.OCTOPUS_API_KEY")
      response = get.getInputStream().getText();
      
      // get project group selected by user
      def parsed = new JsonSlurper().parseText(response)
      def obj = parsed.find{
        it.Name == env.projectGroup
      }

      // get cloning project id
      def getProjs = new URL("https://octopusdeploy.worldremit.com/api/projects/all").openConnection();
      getProjs.setRequestProperty("X-Octopus-ApiKey", "$env.OCTOPUS_API_KEY")
      response = getProjs.getInputStream().getText();
      
      // get project selected by user
      def parsedProjs = new JsonSlurper().parseText(response)
      def cloneProj = parsedProjs.find{
        it.Name == env.templateToClone
      }
  
      // create new octopus job with name under selected projectgroup 
      def post = new URL("https://octopusdeploy.worldremit.com/api/projects?clone=$cloneProj.Id").openConnection();
      message_map = [:]
      message_map.Name = projectName
      message_map.ProjectGroupId = obj.Id 
      message_map.LifecycleId = 'Lifecycles-1'
      def message_string = JsonOutput.toJson(message_map)
      post.setRequestMethod("POST")
      post.setDoOutput(true)
      post.setRequestProperty("X-Octopus-ApiKey", "$env.OCTOPUS_API_KEY")
      post.setRequestProperty("Content-Type", "application/json")
      post.getOutputStream().write(message_string.getBytes("UTF-8"));
      respo = post.getInputStream().getText();
      println respo
    }
  }
}
