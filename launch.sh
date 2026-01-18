#!/bin/bash

# Initialize variables
DRY_RUN=0
CONFIG_FILE=""

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -d, --dry-run       Set dry-run mode (sets variable to 1)"
    echo "  -c, --config FILE   Path to configuration file (required)"
    echo "  -h, --help          Display this help message"
    echo ""
    echo "Configuration file format (JSON):"
    echo "{"
    echo "  \"url\": \"https://uptime.example.com\","
    echo "  \"probes\": {"
    echo "    \"cpu\": {"
    echo "      \"token\": \"token_cpu_123\","
    echo "      \"threshold\": 95"
    echo "    },"
    echo "    \"ram\": {"
    echo "      \"token\": \"token_ram_456\","
    echo "      \"threshold\": 95"
    echo "    },"
    echo "    \"fs\": ["
    echo "      {"
    echo "        \"token\": \"token_fs_root\","
    echo "        \"mount_point\": \"/\","
    echo "        \"threshold\": 90"
    echo "      },"
    echo "      {"
    echo "        \"token\": \"token_fs_data\","
    echo "        \"mount_point\": \"/data\","
    echo "        \"threshold\": 95"
    echo "      }"
    echo "    ]"
    echo "  }"
    echo "}"
    exit "${1:-1}"
}

# Function to extract a probe section from JSON
extract_probe_section() {
    local json_content="$1"
    local probe_name="$2"
    
    # Extract the probe section between "probe_name": { and }
    echo "$json_content" | grep -o "\"$probe_name\"[[:space:]]*:[[:space:]]*{[^}]*}" | sed 's/.*{//' | sed 's/}.*//'
}

# Function to parse JSON string value
parse_json_value() {
    local json_section="$1"
    local key="$2"
    
    # Extract value for the given key
    echo "$json_section" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/'
}

# Function to parse JSON numeric value
parse_json_number() {
    local json_section="$1"
    local key="$2"
    
    # Extract numeric value for the given key
    echo "$json_section" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*[0-9]*" | sed 's/.*:[[:space:]]*\([0-9]*\).*/\1/'
}

# Function to parse FS array from JSON
parse_fs_array() {
    local config_file="$1"
    
    # Initialize arrays
    FS_TOKENS=()
    FS_MOUNT_POINTS=()
    FS_THRESHOLDS=()
    
    # Extract lines between "fs": [ and ]
    local in_fs=0
    local fs_lines=""
    
    while IFS= read -r line; do
        # Check if we're entering the fs array
        if echo "$line" | grep -q '"fs".*\['; then
            in_fs=1
            continue
        fi
        
        # Check if we're leaving the fs array
        if [[ $in_fs -eq 1 ]] && echo "$line" | grep -q '^\s*\]'; then
            break
        fi
        
        # Accumulate lines while in fs array
        if [[ $in_fs -eq 1 ]]; then
            fs_lines="$fs_lines$line"$'\n'
        fi
    done < "$config_file"
    
    # Parse each FS object (we know there are 2 objects based on structure)
    # Extract all values in order they appear
    local idx=0
    local current_token=""
    local current_mount=""
    local current_threshold=""
    
    while IFS= read -r line; do
        if echo "$line" | grep -q '"token"'; then
            current_token=$(echo "$line" | sed 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        elif echo "$line" | grep -q '"mount_point"'; then
            current_mount=$(echo "$line" | sed 's/.*"mount_point"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        elif echo "$line" | grep -q '"threshold"'; then
            current_threshold=$(echo "$line" | sed 's/.*"threshold"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/')
            
            # We have all 3 values for this object, save them
            FS_TOKENS[$idx]="$current_token"
            FS_MOUNT_POINTS[$idx]="$current_mount"
            FS_THRESHOLDS[$idx]="$current_threshold"
            ((idx++))
            
            # Reset for next object
            current_token=""
            current_mount=""
            current_threshold=""
        fi
    done <<< "$fs_lines"
}

# Function to load configuration from JSON file
load_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        echo "Error: Configuration file not found: $config_file"
        exit 1
    fi
    
    # Read entire file content (removing newlines and extra spaces for easier parsing)
    local json_content
    json_content=$(tr -d '\n' < "$config_file" | tr -s ' ')
    
    # Parse main URL
    URL=$(parse_json_value "$json_content" "url")
    
    # Extract and parse CPU probe configuration
    local cpu_section
    cpu_section=$(extract_probe_section "$json_content" "cpu")
    CPU_TOKEN=$(parse_json_value "$cpu_section" "token")
    CPU_THRESHOLD=$(parse_json_number "$cpu_section" "threshold")
    
    # Extract and parse RAM probe configuration
    local ram_section
    ram_section=$(extract_probe_section "$json_content" "ram")
    RAM_TOKEN=$(parse_json_value "$ram_section" "token")
    RAM_THRESHOLD=$(parse_json_number "$ram_section" "threshold")
    
    # Initialize FS arrays
    FS_TOKENS=()
    FS_MOUNT_POINTS=()
    FS_THRESHOLDS=()
    
    # Parse FS array (pass config file path, not content)
    parse_fs_array "$config_file"
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -c|--config)
            if [[ -n $2 && $2 != -* ]]; then
                CONFIG_FILE="$2"
                shift 2
            else
                echo "Error: --config requires a file path"
                usage 1
            fi
            ;;
        -h|--help)
            usage 0
            ;;
        *)
            echo "Unknown option: $1"
            usage 1
            ;;
    esac
done

# Verify configuration file was provided
if [[ -z "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file is required"
    usage 1
fi

# Load configuration
load_config "$CONFIG_FILE"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Display configuration
echo "=== Launch Configuration ==="
echo "Dry-run mode: $DRY_RUN"
echo "Configuration file: $CONFIG_FILE"
echo "URL: ${URL:-<not set>}"
echo ""
echo "CPU Probe:"
echo "  Token: ${CPU_TOKEN:-<not set>}"
echo "  Threshold: ${CPU_THRESHOLD:-<not set>}"
echo ""
echo "RAM Probe:"
echo "  Token: ${RAM_TOKEN:-<not set>}"
echo "  Threshold: ${RAM_THRESHOLD:-<not set>}"
echo ""
echo "FS Probes: ${#FS_TOKENS[@]}"
for i in "${!FS_TOKENS[@]}"; do
    echo "  FS[$i]:"
    echo "    Token: ${FS_TOKENS[$i]:-<not set>}"
    echo "    Mount: ${FS_MOUNT_POINTS[$i]:-<not set>}"
    echo "    Threshold: ${FS_THRESHOLDS[$i]:-<not set>}"
done
echo "============================"

# Execute probes
echo ""
echo "=== Executing Probes ==="

# CPU Probe
if [[ -n "$CPU_TOKEN" ]]; then
    echo "Running CPU probe..."
    export KUMA_URL="$URL"
    export KUMA_TOKEN="$CPU_TOKEN"
    export CRITICAL_LIMIT="$CPU_THRESHOLD"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        "$SCRIPT_DIR/scripts/cpu.sh" -d
    else
        "$SCRIPT_DIR/scripts/cpu.sh"
    fi
fi

# RAM Probe
if [[ -n "$RAM_TOKEN" ]]; then
    echo "Running RAM probe..."
    export KUMA_URL="$URL"
    export KUMA_TOKEN="$RAM_TOKEN"
    export CRITICAL_LIMIT="$RAM_THRESHOLD"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        "$SCRIPT_DIR/scripts/ram.sh" -d
    else
        "$SCRIPT_DIR/scripts/ram.sh"
    fi
fi

# FS Probes
for i in "${!FS_TOKENS[@]}"; do
    if [[ -n "${FS_TOKENS[$i]}" ]]; then
        echo "Running FS probe for ${FS_MOUNT_POINTS[$i]}..."
        export KUMA_URL="$URL"
        export KUMA_TOKEN="${FS_TOKENS[$i]}"
        export MOUNT_POINT="${FS_MOUNT_POINTS[$i]}"
        export CRITICAL_LIMIT="${FS_THRESHOLDS[$i]}"
        
        if [[ $DRY_RUN -eq 1 ]]; then
            "$SCRIPT_DIR/scripts/fs.sh" -d
        else
            "$SCRIPT_DIR/scripts/fs.sh"
        fi
    fi
done

echo "=== All probes completed ==="
