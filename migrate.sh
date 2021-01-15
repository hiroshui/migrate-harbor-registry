#!/bin/bash
set -eux

source config


# Returns a string in which the sequences with percent (%) signs followed by
# two hex digits have been replaced with literal characters.
function rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"    # You can either set a return variable (FASTER) 
  #REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}

echo "[INFO]: Login to both registries."
docker login ${OLD_REGISTRY_URL} -u ${OLD_REGISTRY_USER} -p ${OLD_REGISTRY_PASSWORD}
docker login ${NEW_REGISTRY_URL} -u ${NEW_REGISTRY_USER} -p ${NEW_REGISTRY_PASSWORD}

echo "[INFO]: Get all projects from registry ${OLD_REGISTRY_URL}."
export PROJECTS=$(curl -u ${OLD_REGISTRY_USER}:${OLD_REGISTRY_PASSWORD} -k -X GET "https://${OLD_REGISTRY_URL}/api/projects" | jq -r .[].name)

for project in ${PROJECTS}; do
    echo "[INFO]: Get repos for project ${project}"
    export REPOS=$(curl -u ${OLD_REGISTRY_USER}:${OLD_REGISTRY_PASSWORD} -k -X GET "https://${OLD_REGISTRY_URL}/api/search?q=${project}/" | jq -r .repository[].repository_name)
    for repo in ${REPOS}; do
        export REPO_ID=$(curl -u ${OLD_REGISTRY_USER}:${OLD_REGISTRY_PASSWORD} -k -X GET "https://${OLD_REGISTRY_URL}/api/search?q=${project}/" | jq ".repository[] | select (.repository_name==\"${repo}\")" | jq -r .project_id)
        echo "get Tags for repo ${repo} in project ${project}."
        export encoded_repo=$(rawurlencode "$repo")
        export TAGS=$(curl  -k -X GET -H 'Accept: application/json' "https://${OLD_REGISTRY_URL}/api/repositories/${encoded_repo}/tags" | jq -r .[].name)
        for tag in ${TAGS}; do
            docker pull "${OLD_REGISTRY_URL}/${repo}:${tag}"
            docker tag "${OLD_REGISTRY_URL}/${repo}:${tag}" "${NEW_REGISTRY_URL}/${repo}:${tag}"
            docker push "${NEW_REGISTRY_URL}/${repo}:${tag}"
            echo "[INFO]: Successfully pushed image ${repo}:${tag} to registry ${NEW_REGISTRY_URL}."
            echo "[INFO]: Cleanup both images from local registry."
            docker rmi "${NEW_REGISTRY_URL}/${repo}:${tag}"
            docker rmi "${OLD_REGISTRY_URL}/${repo}:${tag}"
        done
    done
done

echo "[INFO]: Done. Completly migrated from old registry to new one."
