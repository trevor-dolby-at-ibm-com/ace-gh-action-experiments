#!/bin/bash
#########################################################################
# This script looks for ACE server.conf.yaml files and converts them to
# the CP4i Configuration format. CP4i expects the actual server.conf.yaml
# content to be base64 encoded and placed into a Configuration YAML that
# looks like this:
# 
# apiVersion: appconnect.ibm.com/v1beta1
# kind: Configuration
# metadata:
#   name: example-serverconf
# spec:
#   contents: UEsDBAoAAAAAAE18WVkAAAAAAAA ...
#   description: "Example server.conf.yaml"
#   type: serverconf
#   version: 12.0.12-r1
#
# The Configuration YAML can then be handed to Kubernetes (in a specific
# namespace) so it can be attached to one or more IntegrationRuntimes.
#
# This script always generates the Configuration YAML without attempting
# to check if anything has changed; git will detect changes by comparing
# the generated Configuration YAML against the previous version.
#########################################################################

export YAMLFILES=$(find * -type f -name "*-serverconf.yaml" -print)

for yamlFile in $YAMLFILES; do
  # Make sure there's at least one match
  [ -e "$yamlFile" ] || continue
  export yamlBaseName=$(basename "$yamlFile")
  export yamlDirName=$(dirname "$yamlFile")
  export generatedYamlName=$(echo "${yamlDirName}/${yamlBaseName}" | sed 's/-serverconf.yaml/-serverconf-generated.yaml/g')
  export configurationName=$(echo "${yamlBaseName}" | sed 's/-serverconf.yaml/-serverconf/g')
  echo "Generating $generatedYamlName from $yamlFile - will rely on git to check if it has changed"
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
