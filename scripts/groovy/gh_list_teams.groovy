import groovy.json.*

def get = new URL("https://api.github.com/orgs/Worldremit/teams").openConnection();
get.setRequestProperty("Authorization", "<pac-goes-here>")
response = get.getInputStream().getText();


def parsed = new JsonSlurper().parseText(response)

def teamsList = []

parsed.each{
  teamsList << it.name
}

teamsList.sort()