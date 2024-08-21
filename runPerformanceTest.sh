#!/bin/bash

# Configuration
SERVER_ADDRESS="localhost"
SERVER_PORT=8080
SNIPPET_COUNT=1000
CACHE_TEST_FREQUENCY=10  # 1/10th of the snippets will be retrieved multiple times
INTERVAL_MS=100          # Default interval in milliseconds
CONCURRENT_REQUESTS=1    # Default to sequential retrieval

# Parse command-line arguments
while getopts ":a:p:i:c:s" opt; do
  case $opt in
    a) SERVER_ADDRESS="$OPTARG"
    ;;
    p) SERVER_PORT="$OPTARG"
    ;;
    i) INTERVAL_MS="$OPTARG"
    ;;
    c) CONCURRENT_REQUESTS="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
        exit 1
    ;;
  esac
done

# Convert interval from milliseconds to seconds for sleep command
INTERVAL_SEC=$(echo "scale=3; $INTERVAL_MS/1000" | bc)

# Pre-define 1000 snippets of text
snippets=()
for ((i=0; i<$SNIPPET_COUNT; i++)); do
  snippets+=("This is pre-defined snippet number $((i+1))")
done

# Function to create snippets
create_snippets() {
  for ((i=0; i<$SNIPPET_COUNT; i++)); do
    request="CREATE /snippets/snippet_${i}.txt ${snippets[$i]}"
    echo -e "$request\n" | nc "$SERVER_ADDRESS" "$SERVER_PORT"
    echo "Created snippet $i"
    sleep $INTERVAL_SEC
  done
}

# Function to retrieve snippets, with some retrieved multiple times
retrieve_snippet() {
  local i=$1
  request="SHOW /snippets/snippet_${i}.txt"
  echo -e "$request\n" | nc "$SERVER_ADDRESS" "$SERVER_PORT"
  echo "Retrieved snippet $i"

  # Every 10th snippet will be retrieved again to test caching
  if (( i % CACHE_TEST_FREQUENCY == 0 )); then
    echo -e "$request\n" | nc "$SERVER_ADDRESS" "$SERVER_PORT"
    echo "Retrieved snippet $i again for caching test"
  fi
}

# Function to delete snippets
delete_snippets() {
  for ((i=0; i<$SNIPPET_COUNT; i++)); do
    request="DELETE /snippets/snippet_${i}.txt"
    echo -e "$request\n" | nc "$SERVER_ADDRESS" "$SERVER_PORT"
    echo "Deleted snippet $i"
    sleep $INTERVAL_SEC
  done
}

# Function to run retrieval operations concurrently
run_retrieve_concurrently() {
  for ((i=0; i<$SNIPPET_COUNT; i++)); do
    (
      retrieve_snippet "$i" &
      sleep $INTERVAL_SEC
    )
    if (( i % CONCURRENT_REQUESTS == 0 )); then
      wait
    fi
  done
  wait
}

# Main function to run the test
main() {
  echo "Creating 1000 snippets..."
  create_snippets

  echo "Retrieving 1000 snippets (with caching test)..."
  run_retrieve_concurrently

  echo "Deleting 1000 snippets..."
  delete_snippets

  echo "Test completed."
}

# Run the main function
main