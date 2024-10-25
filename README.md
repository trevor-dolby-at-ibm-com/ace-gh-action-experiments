# ace-gh-action-experiments
ACE actions to create CP4i Configurations from source, including server.conf.yaml and policy projects. 
The scripts and demo Action create files with a `-generated.yaml` suffix to make it clear that the
files should not be changed manually, and also to allow the eclusion of such files in the Action
trigger to avoid loops.

The source policy projects are detected by scanning for `policy.descriptor` files in the repo, and 
server.conf.yaml files are found by looking for a `-serverconf.yaml` ending.