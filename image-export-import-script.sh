while getopts t:u:p:y: flag
do
    case "${flag}" in
        t) TARGET_REGISTRY=${OPTARG};;
        u) REGISTRY_USERNAME=${OPTARG};;
        p) REGISTRY_PASSWORD=${OPTARG};;
        y) YAML_FOLDER=${OPTARG};;
    esac
done

# Use yq to find all "image" keys from the release-*.yaml downloaded
found_images=($(yq eval '.. | select(has("image")) | .image' ${YAML_FOLDER}/release-*.yaml | grep --invert-match  -- '---'))
docker login -u REGISTRY_USERNAME -p REGISTRY_PASSWORD
# Loop through each found image
# Pull, retag, push the images
# Update the found image references in all the release-*.yaml
for image in "${found_images[@]}"; do
  if echo "${image}" | grep -q '@'; then
    # If image is a digest reference
    image_ref=$(echo "${image}" | cut -d'@' -f1)
    image_sha=$(echo "${image}" | cut -d'@' -f2)
    image_path=$(echo "${image_ref}" | cut -d'/' -f2-)

    docker pull "${image}"
    docker tag "${image}" "${TARGET_REGISTRY}/${REGISTRY_USERNAME}/${image_path}"
    # Obtain the new sha256 from the `docker push` output
    new_sha=$(docker push "${TARGET_REGISTRY}/${REGISTRY_USERNAME}/${image_path}" | tail -n1 | cut -d' ' -f3)

    new_reference="${TARGET_REGISTRY}/${REGISTRY_USERNAME}/${image_path}@${new_sha}"
  else
    # If image is a tag reference
    image_path=$(echo ${image} | cut -d'/' -f2-)

    docker pull ${image}
    docker tag ${image} ${TARGET_REGISTRY}/${REGISTRY_USERNAME}/${image_path}
    docker push ${TARGET_REGISTRY}/${REGISTRY_USERNAME}/${image_path}

    new_reference="${TARGET_REGISTRY}/${REGISTRY_USERNAME}/${image_path}"
  fi

  # Replace the image reference with the new reference in all the release-*.yaml
  sed -i.bak -E "s#image: ${image}#image: ${new_reference}#" ${YAML_FOLDER}/release-*.yaml
done