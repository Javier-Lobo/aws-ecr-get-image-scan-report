#!/bin/bash

# Is whiptail installed?
if ! command -v whiptail &> /dev/null; then
    whiptail --title " Error " --msgbox "whiptail is not installed. Please, install it via Homebrew:\nbrew install newt" 10 60
    exit 1
fi

# Is aws cli installed?
if ! command -v aws &> /dev/null; then
    whiptail --title " Error " --msgbox "AWS CLI is not installed. Please, install it via Homebrew:\nbrew install awscli" 10 60
    exit 1
fi

# Read AWS profiles
get_profiles() {
    grep "^\[profile" ~/.aws/config | sed -n 's/^\[profile \([^]]*\)].*/\1/p' | sort
}

# Ask for ECR repository
REPOSITORY_NAME=$(whiptail --inputbox "Input ECR repository name:" 8 60 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
    echo "Canceled."
    exit 1
fi

# Verify the ECR repository has been introduced
if [ -z "$REPOSITORY_NAME" ]; then
    whiptail --title " Error " --msgbox "\nRepository name is required." 8 40
    exit 1
fi

# Get and show AWS profiles
profiles=($(get_profiles))
if [ ${#profiles[@]} -eq 0 ]; then
    whiptail --title " Error " --msgbox "\nNo AWS profiles found." 8 40
    exit 1
fi

profile_options=()
for i in "${!profiles[@]}"; do
    profile_options+=("${profiles[i]}" "")
done

PROFILE=$(whiptail --title " Select profile " --menu "\nAWS profile to use:" 15 60 5 "${profile_options[@]}" 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
    echo "Canceled."
    exit 1
fi

# File output name (replacing "/" to "-")
SAFE_REPOSITORY_NAME=$(echo "$REPOSITORY_NAME" | sed 's/\//-/g')
OUTPUT_FILE="$HOME/Downloads/${SAFE_REPOSITORY_NAME}-vulnerabilities.md"

# Función para mostrar el progreso
show_progress() {
    echo "$1" | awk '{print int($1)}' 
    sleep 1
}

# Download and process report
{
    show_progress "10"
    
    # Get last image ID
    IMAGE_ID=$(aws ecr describe-images --profile "$PROFILE" --repository-name "$REPOSITORY_NAME" --query 'sort_by(imageDetails, &imagePushedAt)[-1].imageDigest' --output text)

    show_progress "20"
    
    if [ -z "$IMAGE_ID" ]; then
        echo "No image with scan report found."
        sleep 2
        exit 1
    fi

    show_progress "30"

    aws ecr describe-image-scan-findings \
        --profile "$PROFILE" \
        --repository-name "$REPOSITORY_NAME" \
        --image-id imageDigest="$IMAGE_ID" > "$HOME/Downloads/${SAFE_REPOSITORY_NAME}.json"

    show_progress "40"

    if [ $? -ne 0 ]; then
        echo "Error downloading report."
        sleep 2
        exit 1
    fi

    show_progress "50"

    # Count vulnerabilities by severity
    echo "# Vulnerabilities report of $REPOSITORY_NAME" > "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    jq -r '.imageScanFindings.findings | group_by(.severity) | map({severity: .[0].severity, count: length}) | .[] | "- **\(.severity)**: \(.count)"' "$HOME/Downloads/${SAFE_REPOSITORY_NAME}.json" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    show_progress "55"

    SCAN_DATE=$(date)
    echo "Scanned image ID: $IMAGE_ID on $SCAN_DATE" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    show_progress "60"

    jq -r '
      .imageScanFindings.findings
      | sort_by(.severity)
      | reverse
      | group_by(.severity)[]
      | "## Severity: \(.[0].severity)\n\n" + 
        (.[] | "- **Name**: [\(.name)](https://nvd.nist.gov/vuln/detail/\(.name))\n  - **Description**: \(.description)\n  - **URI**: \(.uri)\n  - **Package**: \(.attributes[] | select(.key == "package_name") | .value // "Not specified")\n  - **Version**: \(.attributes[] | select(.key == "package_version") | .value // "Not specified")\n  - **CVSS3 Score**: \(.attributes[] | select(.key == "CVSS3_SCORE") | .value // "Not specified")\n  - **CVSS3 Vector**: \(.attributes[] | select(.key == "CVSS3_VECTOR") | .value // "Not specified")\n")
    ' "$HOME/Downloads/${SAFE_REPOSITORY_NAME}.json" >> "$OUTPUT_FILE"

    if [ $? -ne 0 ]; then
        echo "Error processing report."
        sleep 2
        exit 1
    fi

    show_progress "90"

    rm "$HOME/Downloads/${SAFE_REPOSITORY_NAME}.json"
    show_progress "100"
} | whiptail --gauge "Downloading and processing report..." 6 50 0

whiptail --title " Success " --msgbox "\nReport processed and saved in \n\n$OUTPUT_FILE" 10 70

clear
