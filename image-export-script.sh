while getopts y:o:f: flag
do
    case "${flag}" in
        y) YAML_FOLDER=${OPTARG};;
        o) OUTPUT_FOLDER=${OPTARG};;
        f) OUTPUT_FILENAME=${OPTARG};;
    esac
done
# Use yq to find all "image" keys from the release-*.yaml downloaded
found_images=($(yq eval '.. | select(has("image")) | .image' ${YAML_FOLDER}/release-*.yaml | grep --invert-match  -- '---'))
output_file="${OUTPUT_FOLDER}/${OUTPUT_FILENAME}.yaml"
touch ${output_file}
# Loop through each found image
# Pull and save the images
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
  else
    echo "loading tag reference for image: ${image}"
    # If image is a tag reference
    image_path=$(echo ${image} | cut -d'/' -f2-)
    image_name=$(echo ${image_path////.})
    image_name=$(echo ${image_name//:/v})
    echo "tag image_reference pull: ${image_path}"
    docker pull ${image}
    echo "tag image_name save: ${image_name}"    
    save_file="${OUTPUT_FOLDER}/${image_name}.tar"
    docker save -o "${save_file}" "${image}"
  fi
  yq w ${output_file} images.image ${image} saved_file ${save_file};"
done