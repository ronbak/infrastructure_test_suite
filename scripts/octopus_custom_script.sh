echo 'Setting up Deployment Tool'
echo "$(get_octopusvariable "GIT_SSH_KEY")" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
echo "$(get_octopusvariable "GITHUB_FINGERPRINT")" > ~/.ssh/known_hosts


REPOSRC=git@github.com:chudsonwr/infrastructure_test_suite.git
LOCALREPO=~/infrastructure_test_suite

LOCALREPO_VC_DIR=$LOCALREPO/.git

if [ ! -d $LOCALREPO_VC_DIR ]
then
    git clone $REPOSRC $LOCALREPO --quiet
else
    if [ ! -d $LOCALREPO ]
    then
      mkdir $LOCALREPO
    fi
    cd $LOCALREPO
    git pull $REPOSRC --quiet
fi

echo 'Setting up environment variables'
export CSRE_LOG_LEVEL=DEBUG
export AZURE_CLIENT_SECRET=$(get_octopusvariable "AZURE_CLIENT_SECRET")
export GIT_ACCESS_TOKEN=$(get_octopusvariable "GIT_ACCESS_TOKEN")
export AZURE_STORAGE_ACCOUNT_KEY=$(get_octopusvariable "AZURE_STORAGE_ACCOUNT_KEY")

echo 'Running command.....'
ruby ~/infrastructure_test_suite/bin/provision.rb --action deploy --environment $( echo $(get_octopusvariable "Octopus.Environment.Name") | tr '[:upper:]' '[:lower:]') --config https://raw.githubusercontent.com/chudsonwr/arm_templates/master/networks/configs/networking_master.config.json --complete --prep_templates
