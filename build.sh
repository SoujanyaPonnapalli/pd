#!/bin/bash

# PD (Placement Driver) Build Script
# This script installs Go 1.23 and builds the PD repository
# This script is idempotent - it can be run multiple times safely

set -e  # Exit on any error

echo "=== PD Build Script ==="
echo "This script will install Go 1.23 and build the PD repository"
echo "This script is idempotent and can be run multiple times safely."
echo

# Check if we're in the right directory
if [ ! -f "go.mod" ] || [ ! -f "Makefile" ]; then
    echo "Error: This script must be run from the PD repository root directory"
    echo "Please make sure you're in the directory containing go.mod and Makefile"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if Go version is compatible
check_go_version() {
    local version=$1
    if [[ "$version" == 1.23* ]] || [[ "$version" == 1.24* ]] || [[ "$version" == 1.25* ]]; then
        return 0  # true
    else
        return 1  # false
    fi
}

# Check if Go is already installed and is the right version
GO_INSTALLED=false
if command_exists go; then
    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    echo "Found Go version: $GO_VERSION"
    
    if check_go_version "$GO_VERSION"; then
        echo "Go version $GO_VERSION is compatible. Skipping Go installation."
        GO_INSTALLED=true
    else
        echo "Go version $GO_VERSION is not compatible. Need Go 1.23 or higher."
        echo "Will install Go 1.23..."
    fi
else
    echo "Go is not installed. Will install Go 1.23..."
fi

# Install Go 1.23 if needed
if [ "$GO_INSTALLED" = false ]; then
    echo
    echo "=== Installing Go 1.23 ==="
    
    # Check if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        echo "This script requires sudo access to install Go and unzip."
        echo "Please run with sudo or ensure you have sudo privileges."
        exit 1
    fi
    
    # Check if Go 1.23 is already installed in /usr/local/go
    if [ -f "/usr/local/go/bin/go" ]; then
        LOCAL_GO_VERSION=$(/usr/local/go/bin/go version | awk '{print $3}' | sed 's/go//')
        if check_go_version "$LOCAL_GO_VERSION"; then
            echo "Go 1.23+ is already installed in /usr/local/go. Adding to PATH..."
            GO_INSTALLED=true
        else
            echo "Found incompatible Go version in /usr/local/go. Will reinstall..."
        fi
    fi
    
    if [ "$GO_INSTALLED" = false ]; then
        # Download Go 1.23 (only if not already downloaded)
        GO_TARBALL="go1.23.0.linux-amd64.tar.gz"
        if [ ! -f "$GO_TARBALL" ]; then
            echo "Downloading Go 1.23..."
            wget https://go.dev/dl/$GO_TARBALL
        else
            echo "Go 1.23 tarball already exists. Skipping download."
        fi
        
        # Install Go
        echo "Installing Go 1.23..."
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf $GO_TARBALL
        
        # Clean up downloaded file
        rm -f $GO_TARBALL
        
        echo "Go 1.23 installed successfully!"
    fi
    
    # Add Go to PATH (only if not already there)
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        echo "Added Go to ~/.bashrc"
    else
        echo "Go is already in ~/.bashrc"
    fi
    
    # Source bashrc to make go available in current session
    export PATH=$PATH:/usr/local/go/bin
fi

# Verify Go installation
echo
echo "=== Verifying Go Installation ==="
go version

# Install required system dependencies
echo
echo "=== Installing System Dependencies ==="
if ! command_exists unzip; then
    echo "Installing unzip..."
    sudo apt update
    sudo apt install -y unzip
else
    echo "unzip is already installed."
fi

# Check if binaries already exist and are recent
echo
echo "=== Checking Existing Build ==="
if [ -f "bin/pd-server" ] && [ -f "bin/pd-ctl" ] && [ -f "bin/pd-recover" ]; then
    echo "PD binaries already exist in bin/ directory."
    
    # Check if binaries are recent (less than 1 hour old)
    BINARY_AGE=$(find bin/ -name "pd-*" -mmin +60 2>/dev/null | wc -l)
    if [ "$BINARY_AGE" -eq 0 ]; then
        echo "Binaries are recent. Skipping rebuild."
        echo
        echo "=== Build Status ==="
        echo "PD is already built and ready to use!"
        echo "The following binaries are available in the 'bin' directory:"
        echo "  - pd-server: Main PD server binary"
        echo "  - pd-ctl: PD control tool"
        echo "  - pd-recover: PD recovery tool"
        echo
        echo "To run PD server, you can use:"
        echo "  ./bin/pd-server --name=\"pd\" --data-dir=\"pd\" --client-urls=\"http://localhost:2379\" --peer-urls=\"http://localhost:2380\""
        echo
        echo "For more information, see the README.md file."
        exit 0
    else
        echo "Binaries are older than 1 hour. Will rebuild."
    fi
else
    echo "PD binaries not found. Will build from scratch."
fi

# Build PD
echo
echo "=== Building PD ==="
echo "This may take a few minutes..."

# Clean previous build artifacts (but keep bin directory)
if [ -d "bin" ]; then
    echo "Cleaning previous build artifacts..."
    rm -f bin/pd-*
fi

# Run the build
make

echo
echo "=== Build Complete! ==="
echo "The following binaries have been created in the 'bin' directory:"
echo "  - pd-server: Main PD server binary"
echo "  - pd-ctl: PD control tool"
echo "  - pd-recover: PD recovery tool"
echo
echo "To run PD server, you can use:"
echo "  ./bin/pd-server --name=\"pd\" --data-dir=\"pd\" --client-urls=\"http://localhost:2379\" --peer-urls=\"http://localhost:2380\""
echo
echo "For more information, see the README.md file." 