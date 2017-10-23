# Azure Infrastructure Deployment and Test suite

- Provide configuration as JSON file.

- Provide ARM templates

- Builds completed ARM template copying multiple nested resources (not currently possible in ARM functionality)

- Uploads linked templates to Azure Storage and generates SAS token

- Works with authenticated GitHub or GitLab

- Provides automated infrastructure testing in Azure (under construction)

## Prerequisites

- Shell (BASH), Ruby.

## Usage

### Deploy

  Main script takes command line arguments:-  
  * `--action`  (deploy,deploy_resource_group,deploy_policy,deploy_policy_set,assign_policydelete,output)
  * `--config`  (path to file, URL or config as a JSON string)
  * `--environment`  (dev,prd,nonprd,core,tst,uat,int,ci,ppd)
  * `--complete` (deployment mode, boolean switch) - optional
  * `--prep_templates` (upload any linked templates to Azure Storage, inject resources if specified, boolean switch) - optional
  * `--output` (path to save built template and params to) - optional
  * `--rules` (specify path to an arm template with rules) - optional
  
  Examples

    ruby ./bin/provision.rb --action deploy --environment dev --config ./configs/networking_master.config.json

    ruby ./bin/provision.rb --action deploy --environment dev --config ./configs/networking_master.config.json --complete --prep_templates --output ../../testoutput.json

    ruby ./bin/provision.rb --action deploy --environment dev --config https://raw.githubusercontent/me/templates/network.json --complete --prep_templates

    ruby ./bin/provision.rb --action output --environment dev --config ./configs/networking_master.config.json --prep_templates --output ../../testoutput.json

    ruby ./bin/provision.rb --action deploy_policy --environment nonprd --config ./configs/resource_groups/policies/naming_standards.json

    ruby ./bin/provision.rb --action assign_policy --environment nonprd --config ./configs/resource_groups/policies/naming_standards.json    


## Functionality

  `--action` - Required  
  One of either `deploy`, `delete`, `output`, `deploy_resource_groups`, `deploy_policy`, `deploy_policy_set`, `assign_policy` or `delete_assignment`.  
  Deploy for deploying a stack, delete for deleting a resource group (as specified in the config file) and output for building the complete deployment object (without actually deploying it), then saving the template and parameters files in JSON, as referenced by the `--output` path to be used by another tool for deployent.  
  `deploy_resource_groups` - Will create resource groups in all environments depending on supplied resource group configuration template.  
  `deploy_policy`, `deploy_policy_set`, `assign_policy` and `delete_assignment` - All refer to management of resource group policies.  


  `--config` - Required  
  Can be supplied as a path to a file or a URL to a raw git file (Hub or Lab internal) or directly as a JSON string. The config file determines the ARM template to use (referenced either as a file path or URL); any rules templates that should be incorporated in to the final template and environment specific parameters for the template AND resource group and location.
  Environment specific parameters are retrieved based on the `--environment` command line option.
  For an example config file see [here](https://source.worldremit.com/chris/infrastructure_test_suite/blob/master/configs/networking_master.config.json).  

  `--environment` - Required  
  Refers to elements specified within the config file as well as which Azure subscription to deploy to based on metadata file [here.](https://source.worldremit.com/chris/infrastructure_test_suite/blob/master/metadata/metadata.json#L22-29)  

  `--complete` - Optional  
  Sets the Azure deployment mode to complete (rather than Incremental). Be careful with this setting as any resources not explicitly specified in the template being deployed will be removed from the resoure group. When deploying to prod this SHOULD be set to `--complete` as all resources should only ever be deployed via a pipeline/with a template. If you're not sure what you're doing leave this setting off.  

  `--prep_templates` - Optional  
  This option will find any linked templates referenced in the master template (referenced in the config file.....stay with me) and upload them to Azure Storage Account (referenced in the [metadata file](https://source.worldremit.com/chris/infrastructure_test_suite/blob/master/metadata/metadata.json#L9-11)). It will then create a SAS token with a 30 minute window and update the linkedTemplate uri in the master template accordingly.  

  `--output` - Optional  
  Path to save built deployment objects to. Use in conjuction with the `output` action. Can also be used with the `deploy` action to preserve the template/params used for a specific deployment.  

  `--rules` - Optional  
  You can specify a rules template or a local directory to pull in rules from. This setting will be overridden if rules templates are referenced in the config file, like [here](https://source.worldremit.com/chris/infrastructure_test_suite/blob/master/configs/networking_master.config.json#L5-8). Rules templates should be generic, see below for more details.  
  

## ConfigFile

  This is made up of various elements. A blank config file might look like this:-
```json
{
  "environments": {
    "global": {
      "arm_template": "",
      "arm_template_rules": [
        ]
    },
    "dev": {
      "resource_group_name": "",
      "subscription_name": "",
      "parameters": {
      }
    },
    "prd": {
      "resource_group_name": "",
      "subscription_name": "",
      "parameters": {
      }
    }
  },
  "parameters": {
   }
}
```

### environments 

  The environments element holds details for each environment you want to deploy to as well as `global` properties. 

#### global

  This holds the link to your ARM template (local path or URL) and any links to rules templates you may want to inject in to the final deployment object.  

#### dev/prd

  This element holds your resource group to deploy to, the Azure Subscription name and any environment specific parameters that your template may want. The parameters element is in the same format as a parameters file would be, it can be lifted directly out of a params file.  

### parameters

  These are the default parameters that apply to all/any environment. At build time the tool takes the default parameters and adds the environment specific parameters over the top. In many cases this default parameters element may be empty.  
  

## Rules template

  A rules template is designed to give us a single place to create/update/delete NSG rules that apply to ALL subnets/landscapes. Rather than having to add a rule to every NSG that exists on all landscapes, which is very error prone, we can update the base rule set, and then this is applied across all environments in the same manner. It ensures consistency across landscapes and reduces errors through manual update of rules. It also means we can more easily store our templates in Git and use a single set of objects as the source of truth. Furthermore with 1 rule set applied across landscapes it's far easier to navigate the template when making changes. 
  For ease of use I have split the templates up in to different files for each subnet they apply to. This is simply to make reading the templates easier, you could have a single template with all rules in but that in itself soon becomes too large and unwieldy.  
  A typical rules template with 1 rule in may look like this:-
```json
{
  "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "vNetName": {
      "type": "string",
      "defaultValue": "vNet1",
      "metadata": {
        "description": "Name for vNet 1"
      }
    },
    "vNet": {
      "type": "object"
    },
    "subnets_array": [
    ],
     "location": {
      "type": "String",
      "defaultValue": "WestEurope"
    }
  },
  "variables": {
  },
  "resources": [
    {
      "apiVersion": "2016-09-01",
      "type": "Microsoft.Network/networkSecurityGroups/securityRules",
      "name": "sql-from-publicclient",
      "location": "",
      "properties": {
        "description": "Rule to allow SQL in to private subnet from publicclient",
        "protocol": "Tcp",
        "sourcePortRange": "*",
        "destinationPortRange": "1433",
        "sourceAddressPrefix": "publicclient",
        "destinationAddressPrefix": "private",
        "access": "Allow",
        "priority": 200,
        "direction": "Inbound"
      }
    }
  ]
}
```
  Lets look at each section.  
### parameters 
  Your parameters section should directly reflect the parameters from the template you wish to inject this rule in to purely for consistency. They are not referenced by the deployment tool.  

### variables
  This can be included for reference but is not required.  

### resources
  Each rule you wish to apply to the master template should be reflected here as a resource. Rules are sub-resources of NSG's in Azure (which is why ARM cannot duplicate across multiple NSG's which are already being duplicated, i.e. nested copying). See the `type` key.  

#### name
  This is the name of the rule you would like to create, it's an arbitrary name but should be descriptive. The deployment tool will then pre-pend the NSG name that this rule will be added to during duplication, ensuring that it's applied to the correct NSG.  

#### source/destinationAddressPrefix
  This can be either a CIDR notation IP prefix or it can be the name of another subnet within the landscape, for instance, `private`, `privatepartner`, `publicclient`, `publicpartner` or `GatewaySubnet`. The deployment tool will then retrieve the actual address prefix for the given landscape subnet that this rule is being applied to during duplication. For instance, this rule will allow the address prefix for the publicclient subnet in each landscape in to the address prefix for the private subnet in each landscape on TCP1433 (or SQL for those in the know). It is important to note the `direction` of this rule when specifying source and address values. When inbound the destination address MUST be one of the landscape subnets, i.e. `private`, `privatepartner`, `publicclient` or `publicpartner`. When `outbound` it's the `sourceAddressprefix` that must be correct. See below for more information.  

#### direction
  This is relevant as the deployment tool will verify the value for `sourceAddressprefix` and `destinationAddressprefix` based on the direction and determine which NSG to apply this to. When `inbound` the `destinationAddressPrefix` should always be the subnet this is being applied to. i.e. if this rule has a direction of `inbound` and a `destinationAddressPrefix` of `private` then it will be applied to the NSG that sits on the private subnet of each landscape. Furthermore it will only validate the value of the `destinationAddressPrefix` as the `sourceAddressPrefix` could be anything. Conversely if the direction is `outbound` then it's the `sourceAddressPrefix` that determines which NSG to apply the rule to and therefore must be specified correctly. The tool will validate these entries at deployment time and raise a fatal exception if, for instance, an inbound rule with a `destinationAddressPrefix` that is not part of the subnet names array list, i.e. `private`, `privatepartner`, `publicclient` or `publicpartner`. This subnet names array is created from the `vNet` landscapes parameters element, so if the subnet exists in there it can be specified in the rule.   

### Duplicated rule
  This rule resource (or object) will then get duplicated for every landscape NSG specified in the `vNet` hash parameter under the `landscapes` element that contains a `private` subnet. So in the case of NonProd environment this rule will be duplicated 6 times, once each for, dev, uat, tst, ci, int and ppd and the values for `sourceAddressprefix` and `destinationAddressPrefix` applied as per the landscape NSG it is being applied to. 
  The completed rule is then injected in to the NSG resource `securityRules` array in the NSG's template. So the dev_private-NSG resource will look like this:-
```json
{
  "apiVersion": "2015-06-15",
  "type": "Microsoft.Network/networkSecurityGroups",
  "name": "nsg01-dev-eurw-private",
  "condition": "[not(equals('private', parameters('vNet').landscapes.gateway.name))]",
  "location": "[resourceGroup().location]",
  "tags": "[parameters('tags')]",
  "properties": {
    "securityRules": [
      {
        "name": "sql-from-publicclient",
        "properties": {
          "description": "Rule to allow SQL in to private subnet from publicclient in dev",
          "protocol": "Tcp",
          "sourcePortRange": "*",
          "destinationPortRange": "1433",
          "sourceAddressPrefix": "10.24.20.0/23",
          "destinationAddressPrefix": "10.24.16.0/23",
          "access": "Allow",
          "priority": 200,
          "direction": "Inbound"
        },
      }
    ]
  }
}
```
  You can see that the address prefixes have been updated accordingly and that it has been injected as a `securityRule` in the NSG resource object. 

  
## Resource Expansion
For both Subnets and NSG's the tool expands the resources in the templates for each landscape. For example, with NSG's we have 1 defined in the NSG template. The tool reads the lanscapes in the `vNet` parameter and determines we need 24 NSG resources. There are 6 landscapes in nonprod and each landscape consists of 4 subnets.  
The tool creates each NSG resource, names it correctly, and injects the rules as above based on the presence of a specific variable, `inject_rules_here`. If this value is set to `true` the tool will expand the NSG resource for each landscape and inject all the rules.  
The same applies for subnets in the Vnets template. The tool looks for the template variable `inject_subnets_here`. If it finds it, it creates a subnet resource (a sub-resource of a VNet resource) based on the values in the `vNet` parameter and injecs it in to the VNet resource in the template.  
  

The purpose of this process is firstly, to have an easily managed template; the NSG's template is 128 lines long, however if we were to expand all the resources of each landscape it would be 2681 lines long for the nonprd environment alone. Add prd and core and we're well over 3000 lines of template just for NSG's. 
Secondly, if we need to make a change to a single resource we would have to remember to make that change for every landsacpe. Though this is possible, with a minimum of 8 landscapes, that gives us 8 opportunities to make a mistake. 
Finally, should we ever need to add to our network, either a landscape, a subnet or anything else, we simply add it to the `vNet` parameter and the tool builds all the resources required for it to function in the same manner as the existing resources. If we had static templates, that would be a very large and error prone task. As we expand as a company our cloud infrastrucure expands too and these processes become vital to ensure consistency and scalability without errors.


## Example Deployment Flow and Class Interaction
The diagram below describes a typical deploymnt of the networking resources to the Non-Production subscription. It shows how all classes interact and what they do in order to create the ARM templates, link them correctly and deploy them to Azure. 
![class interaction](https://github.com/chudsonwr/infrastructure_test_suite/blob/master/documentation/toolSoftwareFlow.png "Class Interaction")  
  

## Contribution Guide

If you want to contribute code:

- Write [good commit messages](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html),
  explain what your patch does, and why it is needed.
- Keep it simple: Any patch that changes a lot of code or is difficult to
  understand should be discussed before you put in the effort.
- If in doubt, just create a pull request to notify the team of your changes. Just go for it.
