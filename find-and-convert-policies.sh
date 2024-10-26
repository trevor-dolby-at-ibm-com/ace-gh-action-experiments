#!/bin/bash
#########################################################################
# This script looks for ACE policy projects and converts them to the CP4i
# Configuration format. CP4i expects the policy content to be zipped up,
# base64 encoded, and then placed into a Configuration YAML that looks 
# like this:
# 
# apiVersion: appconnect.ibm.com/v1beta1
# kind: Configuration
# metadata:
#   name: example-policyproject
# spec:
#   contents: UEsDBAoAAAAAAE18WVkAAAAAAAA ...
#   description: "Example policyproject"
#   type: policyproject
#   version: 12.0.12-r1
#
# The Configuration YAML can then be handed to Kubernetes (in a specific
# namespace) so it can be attached to one or more IntegrationRuntimes.
#
# ZIP files store both content and metadata so this script cannot just
# always create the Configuration and rely on git comparing the generated 
# Configuration YAML against the previous version: "git clone" will set
# the timestamp on the source *.policyxml files during the extract, and
# so the generated ZIP file will always be different.
#
# This script therefore extracts the previous ZIP file from the existing
# Configuration YAML so it can compare the actual files inside the ZIP.
#########################################################################


if [ "$1" == "--include-parent-dir" ]; then
  includeParentDir=1
else
  includeParentDir=0
fi 

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
    # We don't really have a parent dir, so we re-use the policy directory
    export policyParentDir="$policyDirName"
  else
    export policyParentDir=$(basename "$policyParentName")
  fi
  export lcPolicyDirName=$(echo "${policyDirName}" | tr '[A-Z]' '[a-z]')
  if [ "$includeParentDir" == "0" ]; then
    export generatedPolicyName=$(echo "${policyParentName}/${lcPolicyDirName}-policyproject-generated.yaml")
    export configurationName=$(echo "${lcPolicyDirName}-policyproject")
  else
    policyGrandparentName=$(dirname "$policyParentName")
    export generatedPolicyName=$(echo "${policyGrandparentName}/${policyParentDir}-${lcPolicyDirName}-policyproject-generated.yaml")
    export configurationName=$(echo "${policyParentDir}-${lcPolicyDirName}-policyproject")
  fi
  # Expected values for various variables, starting from this repo 
  # with the policy project in subdir/level1/RemoteMQ:
  # 
  # policyDirName=RemoteMQ
  # policyParentName=subdir/level1
  # policyParentDir=level1
  # lcPolicyDirName=remotemq
  # generatedPolicyName=subdir/level1/remotemq-policyproject-generated.yaml
  # configurationName=remotemq-policyproject
  # 
  # If includeParentDir has been set, then the last two are
  # generatedPolicyName=subdir/level1-remotemq-policyproject-generated.yaml
  # configurationName=level1-remotemq-policyproject



  # We only want to update the ZIP file if the contents of the files have changed (we don't
  # want to always create a new Configuration every time even if nothing has changed) but 
  # ZIP files contain the file timestamps so we can't just create a new ZIP file and compare
  # it to the old one because the file times will change.

  # Assume we do not need to rebuild
  policyHasChanged=0
  TMPDIR=`mktemp -d`
  if [ -e "$generatedPolicyName" ]; then
    echo "Configuration YAML $generatedPolicyName already exists; checking to see if it needs updating"
    # Extract from YAML into a ZIP file; no obvious way to feed this into unzip via a pipe
    grep contents: $generatedPolicyName  | tr -d ' ' | sed 's/contents://g' | base64 -d > $TMPDIR/policies.zip
    unzip -d $TMPDIR $TMPDIR/policies.zip
    rm $TMPDIR/policies.zip
    # Scan the existing (previous) ZIP file contents and check against current
    OLDPOLICYFILES=$(cd $TMPDIR && find * -type f -print)
    for oldPolicyFile in $OLDPOLICYFILES; do
      echo "Checking $TMPDIR/$oldPolicyFile against ${policyParentName}/$oldPolicyFile"
      # Check to see if the file in the old ZIP exists now
      if [ -e "${policyParentName}/$oldPolicyFile" ]; then
        # Diff the files to see if they match
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
    # If there's no generated file, then we must be creating new
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
