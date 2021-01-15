# migrate-harbor-registry
This repo will help to migrate from a Harbor-registry (https://goharbor.io) to another image-registry.

You just need to edit the config and fill the variables with your values from the old and new registry.

The script will use the Harbor RestAPI to get all its projects and then will pull all images. These will be directly pushed to the new Image Registry using the same path.
