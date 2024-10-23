#!/bin/bash

export YAMLFILES=$(find * -type f -name "*-serverconf.yaml" -print)

for yamlFile in $YAMLFILES; do
  # Make sure there's at least one match
  [ -e "$yamlFile" ] || continue
  export yamlBaseName=$(basename "$yamlFile")
  export yamlDirName=$(dirname "$yamlFile")
  export generatedYamlName=$(echo "${yamlDirName}/${yamlBaseName}" | sed 's/-serverconf.yaml/-serverconf-generated.yaml/g')
  export configurationName=$(echo "${yamlBaseName}" | sed 's/-serverconf.yaml/-serverconf/g')
  echo "Generating $generatedYamlName from $yamlFile"
  cat << EOF > $generatedYamlName
apiVersion: appconnect.ibm.com/v1beta1
kind: Configuration
metadata:
  name: ${configurationName}
spec:
  contents: $(cat $yamlFile | base64 -w0)
  description: "${configurationName} server.conf.yaml"
  type: serverconf
  version: 12.0.12-r1
EOF
done
