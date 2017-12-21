import groovy.json.*

def get = new URL("https://octopusdeploy.worldremit.com/api/projects/all").openConnection();
get.setRequestProperty("X-Octopus-ApiKey", "<key-goes-here>")
response = get.getInputStream().getText();


def parsed = new JsonSlurper().parseText(response)

def projectsList = []

parsed.each{
  projectsList << it.Name
}

projectsList