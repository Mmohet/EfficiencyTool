#!/bin/bash

# CONFIG
APP_REGEX="(Cursor)"
SWAP_THRESHOLD_MB=200     # Trigger if swap delta is this high
PRESSURE_THRESHOLD=20     # Trigger if RAM pressure is this high
CHECK_INTERVAL=60         # Seconds

# Initialize
prev_swap=$(sysctl -n vm.swapusage | awk '{print $7}' | sed 's/M//')
declare -a assigned_pids=()

# Function to resolve known process patterns to AppleScript app names
get_applescript_name() {
  local process_path="$1"
  case "$process_path" in
    *Code*) echo "Visual Studio Code" ;;
    *cursor*) echo "Visual Studio Code" ;; # cursor.app often means VSCodium variant
    *Slack*) echo "Slack" ;;
    *Chrome*) echo "Google Chrome" ;;
    *) echo "$(basename "$process_path" | sed 's/\.app//')" ;;
  esac
}
while true; do
    timestamp=$(date "+%H:%M")
    echo "[$timestamp] Checking memory and processes..."

    # --- Check Swap Delta ---
    current_swap=$(sysctl -n vm.swapusage | awk '{print $7}' | sed 's/M//')
    delta_swap=$(echo "$current_swap - $prev_swap" | bc)
    echo "Swap delta: $delta_swap MB"

    # --- Check Memory Pressure ---
    mem_pressure=$(top -l 1 | grep -E "^PhysMem" | awk '{print $8}' | sed 's/%.*//')
    echo "RAM pressure: ${mem_pressure}%"

    # Trigger if either condition met
    swap_trigger=$(echo "$delta_swap >= $SWAP_THRESHOLD_MB" | bc)
    pressure_trigger=$(echo "$mem_pressure >= $PRESSURE_THRESHOLD" | bc)

    if [[ "$swap_trigger" -eq 0 && "$pressure_trigger" -eq 0 ]]; then
        echo "No memory pressure or high swap activity. Sleeping..."
        sleep $CHECK_INTERVAL
        continue
    fi

    # Update swap baseline
    prev_swap=$current_swap

    echo "Triggered: Cleaning up windows and moving processes to efficiency cores."

    # Get matching PIDs
    pids=$(ps aux | grep -E "$APP_REGEX" | grep -v grep | grep -v GPU | grep -v server | awk '{print $2}')

    for pid in $pids; do
        if [[ ! " ${assigned_pids[@]} " =~ " ${pid} " ]]; then
            taskpolicy -B -p $pid
            assigned_pids+=($pid)

            full_path=$(ps -p $pid -o comm=)
            process_name=$(get_applescript_name "$full_path")
            echo "[$timestamp] Optimized '$process_name' (PID $pid)"

            # AppleScript: Close windows
            osascript <<EOF
tell application "$process_name"
	try
		close every window
	end try
end tell
EOF
        fi
    done

    echo "[$timestamp] Done. Sleeping for $CHECK_INTERVAL seconds..."
    sleep $CHECK_INTERVAL
done
