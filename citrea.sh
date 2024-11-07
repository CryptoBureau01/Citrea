# !/bin/bash

curl -s https://raw.githubusercontent.com/CryptoBureau01/logo/main/logo.sh | bash
sleep 5

# Function to print info messages
print_info() {
    echo -e "\e[32m[INFO] $1\e[0m"
}

# Function to print error messages
print_error() {
    echo -e "\e[31m[ERROR] $1\e[0m"
}



#Function to check system type and root privileges
master_fun() {
    echo "Checking system requirements..."

    # Check if the system is Ubuntu
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" != "ubuntu" ]; then
            echo "This script is designed for Ubuntu. Exiting."
            exit 1
        fi
    else
        echo "Cannot detect operating system. Exiting."
        exit 1
    fi

    # Check if the user is root
    if [ "$EUID" -ne 0 ]; then
        echo "You are not running as root. Please enter root password to proceed."
        sudo -k  # Force the user to enter password
        if sudo true; then
            echo "Switched to root user."
        else
            echo "Failed to gain root privileges. Exiting."
            exit 1
        fi
    else
        echo "You are running as root."
    fi

    echo "System check passed. Proceeding to package installation..."
}


# Function to install dependencies
install_dependency() {
    print_info "<=========== Install Dependency ==============>"
    print_info "Updating and upgrading system packages, and installing curl..."
    sudo apt update && sudo apt upgrade -y && sudo apt install git wget curl -y 

    # Check if Docker is install
    print_info "Installing Docker..."
    # Download and run the custom Docker installation script
     wget https://raw.githubusercontent.com/CryptoBureau01/packages/main/docker.sh && chmod +x docker.sh && ./docker.sh
     # Check for installation errors
     if [ $? -ne 0 ]; then
        print_error "Failed to install Docker. Please check your system for issues."
        exit 1
     fi
     # Remove the docker.sh file after installation
     rm -f docker.sh


    # Docker Composer Setup
    print_info "Installing Docker Compose..."
    # Download and run the custom Docker Compose installation script
    wget https://raw.githubusercontent.com/CryptoBureau01/packages/main/docker-compose.sh && chmod +x docker-compose.sh && ./docker-compose.sh
    # Check for installation errors
    if [ $? -ne 0 ]; then
       print_error "Failed to install Docker Compose. Please check your system for issues."
       exit 1
    fi
    # Remove the docker-compose.sh file after installation
    rm -f docker-compose.sh


    # Check if geth is installed, if not, install it
    if ! command -v geth &> /dev/null
      then
         print_info "Geth is not installed. Installing now..."
    
    # Geth install
    snap install geth
    
    print_info "Geth installation complete."
    else
        print_info "Geth is already installed."
    fi

    # Print Docker and Docker Compose versions to confirm installation
    print_info "Checking Docker version..."
    docker --version

     print_info "Checking Docker Compose version..."
     docker-compose --version

    # Call the uni_menu function to display the menu
    master
}



# Function to set up the Citrea Node
setup_btc() {
    echo "Starting Citrea node setup..."

    sudo ufw allow 18443
    sudo ufw allow 18444
    sudo ufw enable
    
    # Step 1: Create the /root/citrea directory
    echo "Creating /root/citrea directory..."
    mkdir -p /root/citrea
    cd /root/citrea

    # Step 2: Download the Docker Compose file to /root/citrea
    echo "Downloading Docker Compose file to /root/citrea..."
    curl https://raw.githubusercontent.com/chainwayxyz/citrea/nightly/docker-compose.yml --output docker-compose.yml

    # Step 3: Start the node with Docker Compose
    echo "Starting the Citrea node with Docker Compose..."
    docker-compose -f docker-compose.yml up -d

    echo "Citrea node setup complete."

    # Call the uni_menu function to display the menu
    master
}



check_sync_status_btc() {
    # Get the blockchain info using JSON-RPC
    response=$(curl --user citrea:citrea --data-binary '{"jsonrpc": "1.0", "id": "curltest", "method": "getblockchaininfo", "params": []}' -H 'content-type: text/plain;' http://0.0.0.0:18443)

    # Extract chain, block number, and other information from the response
    chain=$(echo $response | jq -r '.result.chain')
    blocks=$(echo $response | jq -r '.result.blocks')

    # Check if node is fully synced
    if [[ "$blocks" -gt 0 ]]; then
        echo "Node is fully synced"
        echo "Status: Synced"
        echo "Chain: $chain"
        echo "Block Number: $blocks"
    else
        echo "Node is not fully synced yet"
    fi

    # Call the master function to display the menu
    master
}



# Function to setup the Citrea Testnet
setup_citrea() {
    # Create the testnet folder if it doesn't exist
    mkdir -p /root/citrea/testnet
    cd /root/citrea/testnet

    # Download the required files
    echo "Downloading rollup_config.toml..."
    curl https://raw.githubusercontent.com/chainwayxyz/citrea/nightly/resources/configs/testnet/rollup_config.toml --output rollup_config.toml

    echo "Downloading genesis.tar.gz..."
    curl https://static.testnet.citrea.xyz/genesis.tar.gz --output genesis.tar.gz

    # Extract the genesis tarball
    echo "Extracting genesis.tar.gz..."
    tar -xzvf genesis.tar.gz

    # Download the Citrea binary
    echo "Downloading citrea-v0.5.4-linux-amd64..."
    curl -L https://github.com/chainwayxyz/citrea/releases/download/v0.5.4/citrea-v0.5.4-linux-amd64 --output citrea-v0.5.4-linux-amd64

    # Give execute permissions to the binary
    chmod u+x ./citrea-v0.5.4-linux-amd64

    # Run the Citrea binary with the specified options
    echo "Running citrea node..."
    ./citrea-v0.5.4-linux-amd64 --da-layer bitcoin --rollup-config-path ./rollup_config.toml --genesis-paths ./genesis

    # Output a success message
    echo "Testnet setup is complete!"

    # Call the master function to display the menu
    master
}


citrea_sync_status() {
    # Send POST request to get sync status
    response=$(curl -X POST --header "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"citrea_syncStatus","params":[], "id":31}' http://0.0.0.0:8080)

    # Check if the response is empty
    if [[ -z "$response" || "$response" == "{}" ]]; then
        echo "Error: No response from the server or empty response."
        return
    fi
    
    # Extract relevant fields from the response
    l1_syncing=$(echo $response | jq -r '.result.l1Status.Syncing')
    l1_head_block_number=$(echo $l1_syncing | jq -r '.result.l1Status.Syncing.headBlockNumber')
    l1_synced_block_number=$(echo $l1_syncing | jq -r '.result.l1Status.Syncing.syncedBlockNumber')

    l2_syncing=$(echo $response | jq -r '.result.l2Status.Syncing')
    l2_head_block_number=$(echo $l2_syncing | jq -r '.result.l2Status.Syncing.headBlockNumber')
    l2_synced_block_number=$(echo $l2_syncing | jq -r '.result.l2Status.Syncing.syncedBlockNumber')

    # Check if L1 node is fully synced
    echo "L1-BTC Status:"
    if [[ "$l1_head_block_number" == "$l1_synced_block_number" ]]; then
        # If fully synced, print the status and the block numbers
        print_info "L1-BTC Node is fully synced: True" "$l1_head_block_number" "$l1_synced_block_number"
    else
        # If not synced, print the status and block numbers
        print_info "L1-BTC Node is fully synced: False" "$l1_head_block_number" "$l1_synced_block_number"
    fi

    # Check if L2 node is fully synced
    echo "L2-Citrea Status:"
    if [[ "$l2_head_block_number" == "$l2_synced_block_number" ]]; then
        # If fully synced, print the status and the block numbers
        print_info "L2-Citrea Node is fully synced: True" "$l2_head_block_number" "$l2_synced_block_number"
    else
        # If not synced, print the status and block numbers
        print_info "L2-Citrea Node is fully synced: False" "$l2_head_block_number" "$l2_synced_block_number"
    fi

    # Call the master function to display the menu
    master
}



btc_logs() {
    echo "Fetching the last 50 lines of logs for the node 'bitcoin-testnet4'..."
    docker logs --tail 50 -f bitcoin-testnet4

    # Call the master function to display the menu
    master
}


citrea_logs() {
    echo "Fetching the last 50 lines of logs for the node 'bitcoin-testnet4'..."
    docker logs --tail 50 -f full-node

    # Call the master function to display the menu
    master
}


stop_node() {
    echo "Node is Stop'..."
    docker stop bitcoin-testnet4
    docker stop full-node

    # Call the master function to display the menu
    master
}


start_node() {
    echo "Node is Start'..."
    docker start bitcoin-testnet4
    docker start full-node

    # Call the master function to display the menu
    master
}


refresh_node() {
    echo "Node is Refresh'..."
    docker restart bitcoin-testnet4
    docker restart full-node

    # Call the master function to display the menu
    master
}



# Function to display menu and prompt user for input
master() {
    print_info "==============================="
    print_info "    Citrea Node Tool Menu      "
    print_info "==============================="
    print_info ""
    print_info "1. Install-Dependency"
    print_info ""
    print_info "2. Setup-BTC"
    print_info "3. BTC-Sync-Status"
    print_info "4. BTC-Logs"
    print_info ""
    print_info "5. Setup-Citrea"
    print_info "6. Citrea-Sync-Stauts"
    print_info "7. Citrea-Logs"
    print_info ""
    print_info "8. Stop-Node"
    print_info "9. Start-Node"
    print_info "10. Refresh-Node"
    print_info ""
    print_info "11. Exit"
    print_info ""
    print_info "==============================="
    print_info "   Created By : CB-Master      "
    print_info "==============================="
    print_info ""
    
    read -p "Enter your choice (1 or 11): " user_choice

    case $user_choice in
        1)
            install_dependency
            ;;
        2)
            setup_btc
            ;;
        3) 
            check_sync_status_btc
            ;;
        4)
            btc_logs
            ;;
        5)
            setup_citrea
            ;;
        6)
            citrea_sync_status
            ;;
        7)
            citrea_logs
            ;;
        8)
            stop_node
            ;;
        9)
            start_node
            ;;
        10)
            refresh_node
            ;;
        11)
            exit 0  # Exit the script after breaking the loop
            ;;
        *)
            print_error "Invalid choice. Please enter 1 or 11 : "
            ;;
    esac
}

# Call the uni_menu function to display the menu
master_fun
master
