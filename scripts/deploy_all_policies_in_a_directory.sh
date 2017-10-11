FILES=../arm_templates/resource_groups/policies/*.json
for f in $FILES
do
  echo "Processing $f file..."
  ruby bin/provision.rb --environment prd --action deploy_policy --config $f
  # take action on each file. $f store current file name
  
done

FILES=../arm_templates/resource_groups/policies/*.json
for f in $FILES
do
  echo "Processing $f file..."
  ruby bin/provision.rb --environment prd --action assign_policy --config $f
  # take action on each file. $f store current file name
  
done