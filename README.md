# sh-sigstore-stack-airgap-registry-migration
two step registry migration script for air gapped installation (https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-install-air-gap.html)

# usage
./image-export-script.sh -y YAML_FOLDER -o IMAGE_OUTPUT_PATH -f IMAGE_FILENAME
./image-import-script.sh -t TARGET_REGISTRY -y YAML_FOLDER -i IMAGE_FOLDER -f INPUT_FILENAME