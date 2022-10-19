while getopts t:y:i:f: flag
do
    case "${flag}" in
        t) TARGET_REGISTRY=${OPTARG};;
        y) YAML_FOLDER=${OPTARG};;
        i) IMAGE_FOLDER=${OPTARG};;
        f) INPUT_FILENAME=${OPTARG};;
    esac
done

# Use yq to find all "image" keys from the yaml exported
#
# TODO
#

# Loop through each found image
# Load, tag and push the images
for image in "${found_images[@]}"; do
  if echo "${image}" | grep -q '@'; then
    echo "loading digest reference for image: ${image}"
    # If image is a digest reference
    image_ref=$(echo "${image}" | cut -d'@' -f1)
    image_sha=$(echo "${image}" | cut -d'@' -f2)
    image_path=$(echo "${image_ref}" | cut -d'/' -f2-)
    image_name=$(echo ${image_path////.})
    echo "digest image_name save: ${image_name}"
    docker load -o "${save_file}" "${image}"
    docker tag "${image}" "${TARGET_REGISTRY}/${image_path}"
    # Obtain the new sha256 from the `docker push` output
    new_sha=$(docker push "${TARGET_REGISTRY}/${image_path}" | tail -n1 | cut -d' ' -f3)
    new_reference="${TARGET_REGISTRY}/${image_path}@${new_sha}"
  else
    echo "loading tag reference for image: ${image}"
    # If image is a tag reference
    image_path=$(echo ${image} | cut -d'/' -f2-)
    image_name=$(echo ${image_path////.})
    image_name=$(echo ${image_name//:/v})
    echo "tag image_name save: ${image_name}"    
    docker load -o "${save_file}" "${image}"
    docker tag ${image} ${TARGET_REGISTRY}/${image_path}
    docker push ${TARGET_REGISTRY}/${image_path}
    new_reference="${TARGET_REGISTRY}/${image_path}"
  fi
  # Replace the image reference with the new reference in all the release-*.yaml
  sed -i.bak -E "s#image: ${image}#image: ${new_reference}#" release-*.yaml
done