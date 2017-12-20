import groovy.json.*
node{
  stage('clone_repo'){
    checkout([$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'infrastructure_test_suite']], submoduleCfg: [], userRemoteConfigs: [[credentialsId: '2c74e2d9-4e99-4f84-86fc-affb2559331f', url: 'git@github.com:chudsonwr/infrastructure_test_suite.git']]])
    sh(returnStdout: true, script: "if [ -d source_repo ]; then rm -rf source_repo; fi")
    sh(returnStdout: true, script: "git clone $sourceRepo source_repo")
    sh(returnStdout: true, script: "if [ -d target_repo ]; then rm -rf target_repo; fi")
    sh(returnStdout: true, script: "cp -r source_repo target_repo")
    sh(returnStdout: true, script: "cd target_repo && rm -rf .git/")
  }
  stage('replace_names_TCBuild'){
    // def workspace = env.WORKSPACE 
    // def currentDir = new File(workspace + "/target_repo/.teamcity/");
    // def fileText;
    // def exts = [".xml"]
    // def srcExp = "baseProject"
    // def replaceText = "$projectName"
    // currentDir.eachFileRecurse(
    //   {file ->
    //     println file.name
    //     for (ext in exts){
    //       if (file.name.endsWith(ext)) {
    //         println "we're changing the file: ${file.name}"
    //         fileText = file.text;
    //         fileText = fileText.replaceAll(srcExp, replaceText)
    //         file.write(fileText);
    //       }
    //     }
    //   }
    // )

    // def currentDir = new File("./target_repo/.teamcity/");
    // def fileText;
    // def exts = [".xml"]
    // def srcExp = "baseProject"
    // def replaceText = "NewProject1"
    // currentDir.eachFileRecurse(
    //   {file ->
    //     if (file.name.includes(srcExp)) {
    //       println 'we are doing it'
    //       println file.name
    //       newName = file.path.replaceAll(srcExp, replaceText)
    //       println newName
    //       file.renameTo(newName)
    //     }

    //   }
    // )
    sh(resturnStdout: true, script: "ruby infrastructure_test_suite/scripts/rename_files_dirs.rb $projectName target_repo/.teamcity")
  }
  stage('commit_to_git'){
    withCredentials([string(credentialsId: 'Github_PAC_csreautomation', variable: 'GITHUB_ACCESS_TOKEN'),]){
      sh(resturnStdout: true, script: "curl -v -i -H 'Authorization: token ${env.GITHUB_ACCESS_TOKEN} -d '{\"name\":\"${projectName}\"' https://api.github.com/user/repos")
    }
  }
  stage('create_octopus_project'){
    withCredentials([string(credentialsId: 'octokey', variable: 'OCTOPUS_API_KEY'),]){
      // get all projectgrop objects
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
