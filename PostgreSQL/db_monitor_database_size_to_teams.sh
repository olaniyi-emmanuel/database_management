#!/bin/bash

# Hey there! This script monitors PostgreSQL database sizes using environment variables 
# and sends notifications via Microsoft Teams when certain thresholds are reached.

CONFIG_FILE="postgresql_dbs.conf"   # Configuration file where we list the environment variables for our DBs
CHECK_INTERVAL=300   # Time interval (in seconds) between checks, so the script doesn't overload your system
LOG_FILE="/var/log/postgresql_monitor_$(date +%Y%m%d_%H%M%S).log"  # Log file to track what's happening during monitoring
SIZE_THRESHOLD=10240  # If a database size exceeds 10GB, we get alerted!
TEAMS_WEBHOOK_URL="your_teams_webhook_url_here"  # This is the URL for sending notifications to Teams (you'll need to set this)

# Define some colors to make outputs look fancy in the terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color, to reset the color formatting

# Function to check if a command exists. It’s a good way to ensure all required tools are installed.
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Log messages to the log file and display on the screen. It keeps track of all actions during execution.
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to send a notification to Microsoft Teams when something important happens, 
# like when a database exceeds the size threshold.
send_teams_notification() {
    local message="$1" db_name="$2" db_host="$3"
    local payload=$(cat <<EOF
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "summary": "Database Size Alert",
    "title": "Database Size Alert",
    "sections": [{"activityTitle": "$db_name on $db_host", "text": "$message"}]
}
EOF
)
    curl -H "Content-Type: application/json" -d "$payload" "$TEAMS_WEBHOOK_URL" >/dev/null 2>&1
    [ $? -eq 0 ] && log_message "Teams notification sent: $message" || log_message "ERROR: Failed to send Teams notification"
}

# Friendly message at startup. This will also log that the script has started.
echo "=== PostgreSQL Database Size Monitor ==="
echo "Press Ctrl+C to stop monitoring"
log_message "Starting PostgreSQL database size monitoring from: $CONFIG_FILE"

# Check if all the required commands are available. If not, we'll give a friendly message explaining the issue.
for cmd in psql curl bc; do
    if ! command_exists "$cmd"; then
        echo -e "${RED}Error: $cmd not found. Please install it.${NC}"
        exit 1
    fi
done

# Check if the config file exists. This is where your database environment variables live.
[ ! -f "$CONFIG_FILE" ] && { echo -e "${RED}Error: Config file $CONFIG_FILE not found${NC}"; exit 1; }

# Function to get the size of the database using a connection string.
get_db_size() {
    local conn_str="$1"
    local db_user=$(echo "$conn_str" | cut -d':' -f1)
    local db_pass=$(echo "$conn_str" | cut -d':' -f2 | cut -d'@' -f1)
    local db_host=$(echo "$conn_str" | cut -d'@' -f2 | cut -d':' -f1)
    local db_port=$(echo "$conn_str" | cut -d':' -f3 | cut -d'/' -f1)
    local db_name=$(echo "$conn_str" | cut -d'/' -f2)
    
    # Log some debug information about the connection string for troubleshooting, if needed.
    log_message "DEBUG: conn_str=$conn_str, user=$db_user, pass=$db_pass, host=$db_host, port=$db_port, name=$db_name" >&2

    # Get the size of the database and return it (in MB). We're using psql here.
    PGPASSWORD="$db_pass" psql -U "$db_user" -h "$db_host" -p "$db_port" -d "$db_name" -t -c "SELECT pg_database_size('$db_name') / 1024 / 1024;" 2>/dev/null | xargs
}

# Main function to monitor databases
monitor_dbs() {
    declare -A notified  # We use this to keep track of which databases we've already notified about, to avoid spamming
    while true; do
        echo -e "\n${GREEN}Checking PostgreSQL databases at $(date '+%Y-%m-%d %H:%M:%S')${NC}"
        
        # Loop through each environment variable defined in the config file
        while IFS='|' read -r env_var; do
            [[ "$env_var" =~ ^#.*$ ]] || [[ -z "$env_var" ]] && continue  # Skip comments or empty lines
            
            conn_str="${!env_var}"  # Get the actual connection string from the environment variable
            [ -z "$conn_str" ] && { log_message "ERROR: Environment variable $env_var not set"; echo -e "${RED}Error: $env_var not set${NC}"; continue; }
            
            db_name=$(echo "$conn_str" | cut -d'/' -f2)
            db_host=$(echo "$conn_str" | cut -d'@' -f2 | cut -d':' -f1)

            DB_SIZE_MB=$(get_db_size "$conn_str")  # Get the size of the database
            if [ $? -ne 0 ] || [ -z "$DB_SIZE_MB" ]; then
                log_message "ERROR: Failed to retrieve size for $db_name (check credentials or connectivity)"
                echo -e "${RED}Error: Could not retrieve size for $db_name${NC}"
                continue
            fi
            
            # Calculate size in GB or MB
            DB_SIZE=$(echo "scale=2; $DB_SIZE_MB / 1024" | bc)
            [ $(echo "$DB_SIZE_MB >= 1024" | bc -l) -eq 1 ] && DB_SIZE="${DB_SIZE} GB" || DB_SIZE="${DB_SIZE_MB} MB"

            # Get disk space information
            DATA_DIR="/var/lib/postgresql"
            [ ! -d "$DATA_DIR" ] && DATA_DIR="/"
            DISK_INFO=$(df -h "$DATA_DIR" | tail -1)
            USED=$(echo "$DISK_INFO" | awk '{print $3}')
            AVAILABLE=$(echo "$DISK_INFO" | awk '{print $4}')
            PERCENT=$(echo "$DISK_INFO" | awk '{print $5}')
            
            # Print out the status of each database
            echo "Database: $db_name"
            echo "Size: $DB_SIZE"
            echo "Disk Used: $USED"
            echo "Disk Available: $AVAILABLE"
            echo "Usage Percentage: $PERCENT"
            echo "----------------"
            log_message "DB: $db_name, Size: $DB_SIZE, Disk Used: $USED, Available: $AVAILABLE, Usage: $PERCENT"
            
            # If the size exceeds the threshold, send a Teams notification if we haven't already
            if [ $(echo "$DB_SIZE_MB >= $SIZE_THRESHOLD" | bc -l) -eq 1 ] && [ -z "${notified[$db_name]}" ]; then
                MESSAGE="WARNING: Database $db_name has reached $DB_SIZE (exceeded 10GB threshold)"
                send_teams_notification "$MESSAGE" "$db_name" "$db_host"
                echo -e "${RED}$MESSAGE${NC}"
                notified[$db_name]=true
            fi

            # Check if disk usage is over 90% and send a warning
            USED_PERCENT=$(echo "$PERCENT" | tr -d '%')
            if [ "$USED_PERCENT" -gt 90 ]; then
                log_message "WARNING: Disk space running low for $db_name (<10% available)"
                echo -e "${RED}WARNING: Disk space running low for $db_name!${NC}"
            fi
        done < "$CONFIG_FILE"
        sleep $CHECK_INTERVAL  # Pause for the defined check interval before running the check again
    done
}

# Gracefully handle script termination (e.g., when you press Ctrl+C)
trap 'echo -e "\nStopping monitor..."; log_message "Monitoring stopped"; exit 0' INT

# Start monitoring the databases
monitor_dbs
