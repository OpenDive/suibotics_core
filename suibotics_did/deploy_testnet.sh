#!/bin/bash

# Suibotics Core - Testnet Deployment Script
# This script deploys the Suibotics Core package to Sui testnet

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PACKAGE_NAME="suibotics_did"
GAS_BUDGET=100000000
DEPLOYMENT_LOG="deployment_$(date +%Y%m%d_%H%M%S).log"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Sui CLI installation
check_sui_cli() {
    print_status "Checking Sui CLI installation..."
    
    if ! command_exists sui; then
        print_error "Sui CLI is not installed. Please install it first:"
        echo "  brew install sui  # macOS"
        echo "  Or visit: https://docs.sui.io/guides/developer/getting-started/sui-install"
        exit 1
    fi
    
    local sui_version=$(sui --version 2>/dev/null | head -n1)
    print_success "Sui CLI found: $sui_version"
}

# Function to check and switch to testnet
setup_testnet() {
    print_status "Setting up testnet environment..."
    
    # Switch to testnet
    print_status "Switching to testnet..."
    sui client switch --env testnet
    
    # Check current environment - look for testnet with * in active column
    if ! sui client envs | grep -q "testnet.*\*"; then
        print_error "Failed to switch to testnet. Please check 'sui client envs' output."
        sui client envs
        exit 1
    fi
    
    print_success "Successfully switched to testnet"
}

# Function to check wallet and gas
check_wallet() {
    print_status "Checking wallet and gas balance..."
    
    # Check if wallet exists
    local active_address=$(sui client active-address 2>/dev/null || echo "")
    if [[ -z "$active_address" ]]; then
        print_error "No active wallet found. Please create or import a wallet first:"
        echo "  sui client new-address ed25519  # Create new wallet"
        echo "  sui client import <private-key>  # Import existing wallet"
        exit 1
    fi
    
    print_success "Active wallet: $active_address"
    
    # Check gas balance
    local gas_balance=$(sui client gas --json 2>/dev/null | jq -r '.[] | .mistBalance' | head -n1 2>/dev/null || echo "0")
    
    # Handle null or empty balance
    if [[ "$gas_balance" == "null" || -z "$gas_balance" ]]; then
        gas_balance=0
    fi
    
    print_status "Gas balance: $gas_balance MIST"
    
    # Convert MIST to SUI (1 SUI = 1,000,000,000 MIST)
    local sui_balance=$((gas_balance / 1000000000))
    
    if [[ $gas_balance -lt $GAS_BUDGET ]]; then
        print_warning "Insufficient gas balance. Required: $GAS_BUDGET MIST, Available: $gas_balance MIST"
        print_status "Requesting testnet faucet..."
        
        # Try faucet command
        if sui client faucet 2>&1 | grep -q "For testnet tokens"; then
            print_warning "Faucet requires web UI. Please visit: https://faucet.sui.io/"
            print_status "After getting tokens from the web faucet, press Enter to continue..."
            read -r
        else
            print_status "Faucet request sent, waiting for tokens..."
            sleep 5
        fi
        
        # Check balance again
        gas_balance=$(sui client gas --json 2>/dev/null | jq -r '.[] | .mistBalance' | head -n1 2>/dev/null || echo "0")
        if [[ "$gas_balance" == "null" || -z "$gas_balance" ]]; then
            gas_balance=0
        fi
        
        if [[ $gas_balance -lt $GAS_BUDGET ]]; then
            print_error "Still insufficient gas after faucet. Current balance: $gas_balance MIST"
            print_error "Please get more tokens from https://faucet.sui.io/ and try again."
            exit 1
        fi
    fi
    
    print_success "Sufficient gas available for deployment"
}

# Function to build and test the package
build_and_test() {
    print_status "Building and testing the package..."
    
    # Clean previous build
    if [[ -d "build" ]]; then
        print_status "Cleaning previous build..."
        rm -rf build/
    fi
    
    # Build the package
    print_status "Building Move package..."
    if ! sui move build 2>&1 | tee -a "$DEPLOYMENT_LOG"; then
        print_error "Build failed. Check the logs for details."
        exit 1
    fi
    
    print_success "Build completed successfully"
    
    # Run tests
    print_status "Running tests..."
    if ! sui move test 2>&1 | tee -a "$DEPLOYMENT_LOG"; then
        print_error "Tests failed. Please fix the issues before deployment."
        exit 1
    fi
    
    print_success "All tests passed"
}

# Function to deploy the package
deploy_package() {
    print_status "Deploying package to testnet..."
    
    # Create deployment command
    local deploy_cmd="sui client publish --gas-budget $GAS_BUDGET --json"
    
    print_status "Executing deployment command..."
    print_status "Command: $deploy_cmd"
    
    # Execute deployment and capture output
    local deployment_output
    if deployment_output=$(eval "$deploy_cmd" 2>&1); then
        echo "$deployment_output" | tee -a "$DEPLOYMENT_LOG"
        
        # Extract package ID from JSON output
        local package_id=$(echo "$deployment_output" | jq -r '.objectChanges[] | select(.type == "published") | .packageId' 2>/dev/null || echo "")
        local tx_digest=$(echo "$deployment_output" | jq -r '.digest' 2>/dev/null || echo "")
        
        if [[ -n "$package_id" ]]; then
            print_success "Package deployed successfully!"
            echo ""
            echo "=== DEPLOYMENT RESULTS ==="
            echo "Package ID: $package_id"
            echo "Transaction Digest: $tx_digest"
            echo "Network: testnet"
            echo "Timestamp: $(date)"
            echo ""
            
            # Save deployment info to file
            cat > "deployment_info.json" << EOF
{
  "package_id": "$package_id",
  "transaction_digest": "$tx_digest",
  "network": "testnet",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "package_name": "$PACKAGE_NAME",
  "gas_budget": $GAS_BUDGET
}
EOF
            
            print_success "Deployment information saved to deployment_info.json"
            
            # Show explorer links
            echo ""
            echo "=== EXPLORER LINKS ==="
            echo "Package: https://suiscan.xyz/testnet/object/$package_id"
            echo "Transaction: https://suiscan.xyz/testnet/tx/$tx_digest"
            
        else
            print_error "Deployment completed but could not extract package ID from output"
            echo "$deployment_output"
            exit 1
        fi
    else
        print_error "Deployment failed:"
        echo "$deployment_output" | tee -a "$DEPLOYMENT_LOG"
        exit 1
    fi
}

# Function to verify deployment
verify_deployment() {
    if [[ -f "deployment_info.json" ]]; then
        local package_id=$(jq -r '.package_id' deployment_info.json)
        
        print_status "Verifying deployment..."
        
        # Check if package exists on chain
        if sui client object "$package_id" >/dev/null 2>&1; then
            print_success "Package verification successful - package exists on testnet"
        else
            print_warning "Package verification failed - package not found on chain"
        fi
    fi
}

# Main deployment function
main() {
    echo ""
    echo "========================================"
    echo "  Suibotics Core - Testnet Deployment  "
    echo "========================================"
    echo ""
    
    print_status "Starting deployment process..."
    print_status "Deployment log: $DEPLOYMENT_LOG"
    echo ""
    
    # Log start time
    echo "Deployment started at: $(date)" > "$DEPLOYMENT_LOG"
    
    # Run deployment steps
    check_sui_cli
    setup_testnet
    check_wallet
    build_and_test
    deploy_package
    verify_deployment
    
    echo ""
    print_success "Deployment process completed successfully!"
    print_status "Check $DEPLOYMENT_LOG for detailed logs"
    echo ""
}

# Handle script interruption
trap 'print_error "Deployment interrupted by user"; exit 1' INT TERM

# Check if jq is available (for JSON parsing)
if ! command_exists jq; then
    print_warning "jq is not installed. Some features may not work properly."
    print_status "Install jq for better JSON parsing: brew install jq"
fi

# Run main function
main "$@" 