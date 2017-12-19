import groovy.json.*
node{
  stage('clone_repo'){

  }
  stage('replace_names'){

  }
  stage('create_resource_groups'){

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
  
      // create new octopus job with name under selected projectgroup 
      def post = new URL("https://octopusdeploy.worldremit.com/api/projects").openConnection();
      message_map = [:]
      message_map.Name = name
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
