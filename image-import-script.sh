while getopts t:u:p:y:i:f: flag
do
    case "${flag}" in
        t) TARGET_REGISTRY=${OPTARG};;
        u) REGISTRY_USERNAME=${OPTARG};;
        p) REGISTRY_PASSWORD=${OPTARG};;
        y) YAML_FOLDER=${OPTARG};;
        f) INPUT_FILENAME=${OPTARG};;
    esac
done

# Use yq to find all "image" keys from the yaml exported
found_images=($(yq eval '.. | select(has("image")) | .image' ${INPUT_FILENAME} | grep --invert-match  -- '---'))
saved_file=($(yq eval '.. | select(has("saved_file")) | .saved_file' ${INPUT_FILENAME} | grep --invert-match  -- '---'))
docker login -u ${REGISTRY_USERNAME} -p ${REGISTRY_PASSWORD} ${TARGET_REGISTRY}
# Loop through each found image
# Load, tag and push the images
i=0
for image in "${found_images[@]}"; do
  save_file = ${saved_file[${i}]}
  i = ${i} + 1
  if echo "${image}" | grep -q '@'; then
    echo "loading digest reference for image: ${image}"
    # If image is a digest reference
    image_ref=$(echo "${image}" | cut -d'@' -f1)
    image_sha=$(echo "${image}" | cut -d'@' -f2)
    image_path=$(echo "${image_ref}" | cut -d'/' -f2-)
    docker load -i "${save_file}"
    docker tag "${image}" "${TARGET_REGISTRY}/${image_path}"
    # Obtain the new sha256 from the `docker push` output
    new_sha=$(docker push "${TARGET_REGISTRY}/${image_path}" | tail -n1 | cut -d' ' -f3)
    new_reference="${TARGET_REGISTRY}/${image_path}@${new_sha}"
  else
    echo "loading tag reference for image: ${image}"
    # If image is a tag reference
    image_path=$(echo ${image} | cut -d'/' -f2-)
    image_name=$(echo ${image_path////.})
    docker load -i "${save_file}"
    docker tag ${image} ${TARGET_REGISTRY}/${image_path}
    docker push ${TARGET_REGISTRY}/${image_path}
    new_reference="${TARGET_REGISTRY}/${image_path}"
  fi
  # Replace the image reference with the new reference in all the release-*.yaml
  sed -i.bak -E "s#image: ${image}#image: ${new_reference}#" ${YAML_FOLDER}/release-*.yaml
done