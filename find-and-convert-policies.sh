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
done
