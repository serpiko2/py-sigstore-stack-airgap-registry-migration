while getopts t:y:o:f: flag
do
    case "${flag}" in
        t) TARGET_REGISTRY=${OPTARG};;
        y) YAML_FOLDER=${OPTARG};;
        o) OUTPUT_FOLDER=${OPTARG};;
        f) OUTPUT_FILENAME=${OPTARG};;
    esac
done

# Use yq to find all "image" keys from the release-*.yaml downloaded
found_images=($(yq eval '.. | select(has("image")) | .image' ${YAML_FOLDER}/release-*.yaml | grep --invert-match  -- '---'))
output_file="${OUTPUT_FOLDER}/${OUTPUT_FILENAME}"
touch ${output_file}
# Loop through each found image
# Pull, retag, push the images
# Update the found image references in all the release-*.yaml
for image in "${found_images[@]}"; do
  if echo "${image}" | grep -q '@'; then
    echo "loading digest reference for image: ${image}"
    # If image is a digest reference
    image_ref=$(echo "${image}" | cut -d'@' -f1)
    image_sha=$(echo "${image}" | cut -d'@' -f2)
    image_path=$(echo "${image_ref}" | cut -d'/' -f2-)
    image_name=$(echo ${image_path////.})
    
    echo "digest image_reference pull: ${image_path}"
    docker pull ${image}

    echo "digest image_name save: ${image_name}"
    save_file="${OUTPUT_FOLDER}/${image_name}.tar"
    docker save -o "${save_file}" "${image}"
    # docker tag "${image}" "${TARGET_REGISTRY}/${image_path}"
    # Obtain the new sha256 from the `docker push` output
    # new_sha=$(docker push "${TARGET_REGISTRY}/${image_path}" | tail -n1 | cut -d' ' -f3)

    # new_reference="${TARGET_REGISTRY}/${image_path}@${new_sha}"
  else
    echo "loading tag reference for image: ${image}"
    # If image is a tag reference
    image_path=$(echo ${image} | cut -d'/' -f2-)
    image_name=$(echo ${image_path////.})

    echo "tag image_reference pull: ${image_path}"
    docker pull ${image}

    echo "tag image_name save: ${image_name}"    
    save_file="${OUTPUT_FOLDER}/${image_name}.tar"
    docker save -o "${save_file}" "${image}"
    #docker tag ${image} ${TARGET_REGISTRY}/${image_path}
    #docker push ${TARGET_REGISTRY}/${image_path}

    # new_reference="${TARGET_REGISTRY}/${image_path}"
  fi
  echo "${image};${save_file};" >> ${output_file}

  # Replace the image reference with the new reference in all the release-*.yaml
  #sed -i.bak -E "s#image: ${image}#image: ${new_reference}#" release-*.yaml
done
