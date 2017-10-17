
Feature: Test to ensure All landscape subnets exist in the vnets template
 
  Scenario Outline: All of the subnets are listed in the vnets file
    Given a generated vnets_subnets.json ARM template
    When I parse the template
    Then it should contain 4 subnets for each landscape

    @nonprd
      Examples:
        | subnet       |  landscape    |
        | private      |  dev          |
        

     @prd
      Examples:
        | repository                                                         |  version  |
        | https://nexus-pro3-blue-horizontal.uk.capitalone.com/nexus/        |  Pro      |

     @core
      Examples:
        | repository                                                         |  version  |
        | https://nexus-pro3-green-horizontalprod.uk.capitalone.com/nexus/   |  Pro      |
