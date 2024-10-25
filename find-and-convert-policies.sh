#!/bin/bash

export POLICYFILES=$(find * -type f -name "policy.descriptor" -print)

for policyFile in $POLICYFILES; do
  # Make sure there's at least one match
  [ -e "$policyFile" ] || continue
  export policyDirName=$(dirname "$policyFile")
  export policyDirName=$(basename "$policyDirName")
  export policyParentName=$(dirname "$policyFile")
  export policyParentName=$(dirname "$policyParentName")
  if [ "$policyParentName" == "" ]; then
    export policyParentName="."
  fi
  export lcPolicyDirName=$(echo "${policyDirName}" | tr '[A-Z]' '[a-z]')
  export generatedPolicyName=$(echo "${policyParentName}/${lcPolicyDirName}-policyproject-generated.yaml")
  export configurationName=$(echo "${lcPolicyDirName}-policyproject")

  # We only want to update the ZIP file if the contents of the files have changed (we don't
  # want to always create a new Configuration every time even if nothing has changed) but 
  # ZIP files contain the file timestamps so we can't just create a new ZIP file and compare
  # it to the old one because the file times will change.
  TMPDIR=`mktemp -d`
  
  # Assume we do not need to rebuild
  policyHasChanged=0
  if [ -e "$generatedPolicyName" ]; then
    echo "Configuration YAML $generatedPolicyName already exists; checking to see if it needs updating"
    grep contents: $generatedPolicyName  | tr -d ' ' | sed 's/contents://g' | base64 -d > $TMPDIR/policies.zip
    unzip -d $TMPDIR $TMPDIR/policies.zip
    rm $TMPDIR/policies.zip
    OLDPOLICYFILES=$(cd $TMPDIR && find * -type f -print)
    for oldPolicyFile in $OLDPOLICYFILES; do
      echo "Checking $TMPDIR/$oldPolicyFile against ${policyParentName}/$oldPolicyFile"
      # Check to see if the file in the old ZIP exists
      if [ -e "${policyParentName}/$oldPolicyFile" ]; then
        diff "$TMPDIR/$oldPolicyFile" "${policyParentName}/$oldPolicyFile"
        if [ "$?" == "0" ]; then
          echo "  $oldPolicyFile unchanged"
        else
          echo "  $oldPolicyFile has changed"
          policyHasChanged=1
        fi
      else
        echo "  ${policyParentName}/$oldPolicyFile has been deleted"
        # The file doesn't exist anymore - we need to rebuild
        policyHasChanged=1
      fi
    done
    if [ "$policyHasChanged" == "0" ]; then
      # Also check for new files being added; removed files will have failed the check above
      oldCount=`find $TMPDIR -type f -print | wc -l`
      newCount=`find ${policyParentName}/${policyDirName} -type f -print | wc -l`
      if [ "$oldCount" != "$newCount" ]; then
        echo "File counts differ between old and new policies: $oldCount $newCount"
        policyHasChanged=1
      fi
    fi
    rm -rf $TMPDIR
  else
    echo "Configuration YAML $generatedPolicyName not found"
    policyHasChanged=1
  fi

  if [ "$policyHasChanged" == "0" ]; then
    echo "No changes found; not rebuilding the Configuration"
  else
    echo "Generating $generatedPolicyName from ${policyParentName}/${policyDirName}"
    cat << EOF > $generatedPolicyName
apiVersion: appconnect.ibm.com/v1beta1
kind: Configuration
metadata:
  name: ${configurationName}
spec:
  contents: $(cd ${policyParentName} && zip -r - ${policyDirName} | base64 -w0)
  description: "${configurationName}"
  type: policyproject
  version: 12.0.12-r1
EOF
  fi
done
