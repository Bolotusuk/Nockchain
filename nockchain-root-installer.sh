#!/bin/bash

# Nockchain Optimized Mining Installation Script (ROOT VERSION)
# Optimized for Ubuntu 22.04 VPS Mining
# Author: AI Assistant
# Version: 1.0 (Root-enabled)
# WARNING: Running as root is not recommended for security reasons

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
MINING_PUBKEY="3h6rsTmSpQGPF9eTiD1KK4qkKo3a1EdJ9BaE3itdUqhnDL2Hjh4Z6JPaFBHjjcicvadrxKcUsoVMJb1EkNREd3k5HLao6XSE2NV7tmuEKzAySZG713WGQoWCSJaC4dvmpBx3"
NOCKCHAIN_REPO="https://github.com/zorp-corp/nockchain"
INSTALL_DIR="/root/nockchain"  # Changed to root directory
MINERS_COUNT=4  # Number of miner instances to run
MIN_RAM_GB=16   # Minimum RAM requirement in GB (reduced for maximum compatibility)

# Peer list for better connectivity
PEER_LIST=(
    "/ip4/95.216.102.60/udp/3006/quic-v1"
    "/ip4/65.108.123.225/udp/3006/quic-v1"
    "/ip4/65.109.156.108/udp/3006/quic-v1"
    "/ip4/65.21.67.175/udp/3006/quic-v1"
    "/ip4/65.109.156.172/udp/3006/quic-v1"
    "/ip4/34.174.22.166/udp/3006/quic-v1"
    "/ip4/34.95.155.151/udp/30000/quic-v1"
    "/ip4/34.18.98.38/udp/30000/quic-v1"
    "/ip4/96.230.252.205/udp/3006/quic-v1"
    "/ip4/94.205.40.29/udp/3006/quic-v1"
    "/ip4/159.112.204.186/udp/3006/quic-v1"
    "/ip4/217.14.223.78/udp/3006/quic-v1"
)

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# Function to check system requirements
check_system_requirements() {
    print_header "Checking System Requirements"
    
    # Root warning
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root - this is not recommended for security reasons"
        print_warning "Consider creating a regular user account for mining"
        sleep 3
    fi
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot determine OS version"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]] || [[ "$VERSION_ID" != "22.04" ]]; then
        print_warning "This script is optimized for Ubuntu 22.04. Current OS: $ID $VERSION_ID"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check RAM
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_ram_gb=$((total_ram_kb / 1024 / 1024))
    
    print_status "Total RAM: ${total_ram_gb}GB"
    
    if [[ $total_ram_gb -lt $MIN_RAM_GB ]]; then
        print_error "Insufficient RAM. Required: ${MIN_RAM_GB}GB, Available: ${total_ram_gb}GB"
        print_warning "Nockchain mining requires significant RAM. Consider upgrading your VPS."
        read -p "Continue with limited RAM? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        # Reduce miner count for very low RAM systems
        MINERS_COUNT=1
        print_warning "Reduced miner instances to 1 due to limited RAM"
    elif [[ $total_ram_gb -lt 64 ]]; then
        print_warning "RAM is below optimal 64GB. Adjusting miner configuration for better performance."
        # Optimize for systems with different RAM levels
        if [[ $total_ram_gb -ge 48 ]]; then
            MINERS_COUNT=3
            print_status "Set miner instances to 3 for ${total_ram_gb}GB RAM"
        elif [[ $total_ram_gb -ge 32 ]]; then
            MINERS_COUNT=2
            print_status "Set miner instances to 2 for ${total_ram_gb}GB RAM"
        elif [[ $total_ram_gb -ge 24 ]]; then
            MINERS_COUNT=2
            print_status "Set miner instances to 2 for ${total_ram_gb}GB RAM (with swap optimization)"
        else
            MINERS_COUNT=1
            print_status "Set miner instances to 1 for ${total_ram_gb}GB RAM (with large swap)"
        fi
    fi
    
    # Check CPU cores
    cpu_cores=$(nproc)
    print_status "CPU Cores: $cpu_cores"
    
    # Optimize miner count based on CPU cores
    if [[ $cpu_cores -lt $MINERS_COUNT ]]; then
        MINERS_COUNT=$cpu_cores
        print_status "Adjusted miner instances to $MINERS_COUNT based on CPU cores"
    fi
    
    # Check disk space
    available_space=$(df / | awk 'NR==2 {print $4}')
    available_space_gb=$((available_space / 1024 / 1024))
    
    print_status "Available disk space: ${available_space_gb}GB"
    
    if [[ $available_space_gb -lt 100 ]]; then
        print_error "Insufficient disk space. Required: 100GB, Available: ${available_space_gb}GB"
        exit 1
    fi
}

# Function to optimize system settings
optimize_system() {
    print_header "Optimizing System Settings"
    
    # Enable memory overcommit
    print_status "Enabling memory overcommit..."
    sysctl -w vm.overcommit_memory=1
    echo 'vm.overcommit_memory=1' | tee -a /etc/sysctl.conf
    
    # Optimize swap settings based on RAM
    print_status "Optimizing swap settings..."
    if [[ $total_ram_gb -lt 32 ]]; then
        # More aggressive swap usage for low RAM systems
        sysctl -w vm.swappiness=30
        echo 'vm.swappiness=30' | tee -a /etc/sysctl.conf
        print_status "Set swap aggressiveness to 30 for low RAM system"
    else
        # Conservative swap usage for higher RAM systems
        sysctl -w vm.swappiness=10
        echo 'vm.swappiness=10' | tee -a /etc/sysctl.conf
        print_status "Set swap aggressiveness to 10 for adequate RAM system"
    fi
    
    # Increase file descriptor limits
    print_status "Increasing file descriptor limits..."
    echo "* soft nofile 65536" | tee -a /etc/security/limits.conf
    echo "* hard nofile 65536" | tee -a /etc/security/limits.conf
    
    # Optimize network settings
    print_status "Optimizing network settings..."
    sysctl -w net.core.rmem_max=134217728
    sysctl -w net.core.wmem_max=134217728
    sysctl -w net.ipv4.tcp_rmem="4096 65536 134217728"
    sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728"
    
    # Create swap if needed and RAM is limited
    if [[ $total_ram_gb -lt 64 ]]; then
        print_status "Creating additional swap space for better performance..."
        if [[ ! -f /swapfile ]]; then
            # Calculate swap size based on available RAM - more aggressive for lower RAM
            if [[ $total_ram_gb -ge 48 ]]; then
                swap_size="16G"
            elif [[ $total_ram_gb -ge 32 ]]; then
                swap_size="20G"  # Increased for better performance
            elif [[ $total_ram_gb -ge 24 ]]; then
                swap_size="24G"  # Large swap for medium RAM systems
            elif [[ $total_ram_gb -ge 16 ]]; then
                swap_size="32G"  # Very large swap for low RAM systems
            else
                swap_size="40G"  # Maximum swap for very low RAM
            fi
            
            print_status "Creating ${swap_size} swap file..."
            fallocate -l $swap_size /swapfile
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
            print_status "${swap_size} swap file created"
        fi
    fi
}

# Function to install dependencies
install_dependencies() {
    print_header "Installing Dependencies"
    
    # Update system
    print_status "Updating system packages..."
    apt-get update -y
    apt-get upgrade -y
    
    # Install essential packages
    print_status "Installing essential packages..."
    apt-get install -y \
        curl \
        iptables \
        build-essential \
        git \
        wget \
        lz4 \
        jq \
        make \
        gcc \
        nano \
        automake \
        autoconf \
        tmux \
        htop \
        nvme-cli \
        libgbm1 \
        pkg-config \
        libssl-dev \
        libleveldb-dev \
        tar \
        clang \
        bsdmainutils \
        ncdu \
        unzip \
        libclang-dev \
        llvm-dev \
        screen \
        python3 \
        python3-pip
    
    # Install Rust for root
    print_status "Installing Rust..."
    if ! command -v rustc &> /dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source /root/.cargo/env
        export PATH="/root/.cargo/bin:$PATH"
    else
        print_status "Rust already installed"
    fi
    
    # Verify Rust installation
    if ! command -v rustc &> /dev/null; then
        print_error "Rust installation failed"
        exit 1
    fi
    
    print_status "Rust version: $(rustc --version)"
}

# Function to clone and build Nockchain
build_nockchain() {
    print_header "Building Nockchain"
    
    # Remove old installation
    if [[ -d "$INSTALL_DIR" ]]; then
        print_status "Removing old Nockchain installation..."
        rm -rf "$INSTALL_DIR"
    fi
    
    # Clone repository
    print_status "Cloning Nockchain repository..."
    git clone "$NOCKCHAIN_REPO" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Copy environment file
    print_status "Setting up environment..."
    cp .env_example .env
    
    # Update .env with mining pubkey
    sed -i "s/MINING_PUBKEY=.*/MINING_PUBKEY=$MINING_PUBKEY/" .env
    
    # Install hoonc compiler
    print_status "Installing Hoon compiler..."
    make install-hoonc
    export PATH="/root/.cargo/bin:$PATH"
    
    # Build the project
    print_status "Building Nockchain (this may take a while)..."
    make build
    
    # Install wallet and nockchain binaries
    print_status "Installing Nockchain wallet..."
    make install-nockchain-wallet
    export PATH="/root/.cargo/bin:$PATH"
    
    print_status "Installing Nockchain node..."
    make install-nockchain
    export PATH="/root/.cargo/bin:$PATH"
    
    # Verify installation
    if ! command -v nockchain &> /dev/null; then
        print_error "Nockchain installation failed"
        exit 1
    fi
    
    if ! command -v nockchain-wallet &> /dev/null; then
        print_error "Nockchain wallet installation failed"
        exit 1
    fi
    
    print_status "Nockchain built successfully!"
}

# Function to setup wallet
setup_wallet() {
    print_header "Setting Up Wallet"
    
    cd "$INSTALL_DIR"
    export PATH="/root/.cargo/bin:$PATH"
    
    # Check if wallet already exists
    if [[ -f "/root/.nockchain/wallet.dat" ]]; then
        print_status "Wallet already exists, skipping wallet generation"
        return
    fi
    
    # Generate new wallet if using default pubkey
    if [[ "$MINING_PUBKEY" == "3h6rsTmSpQGPF9eTiD1KK4qkKo3a1EdJ9BaE3itdUqhnDL2Hjh4Z6JPaFBHjjcicvadrxKcUsoVMJb1EkNREd3k5HLao6XSE2NV7tmuEKzAySZG713WGQoWCSJaC4dvmpBx3" ]]; then
        print_warning "Using provided public key for mining"
        print_warning "If you want to use your own wallet, generate one with: nockchain-wallet keygen"
    fi
    
    # Backup keys if they exist
    print_status "Creating wallet backup..."
    if command -v nockchain-wallet &> /dev/null; then
        nockchain-wallet export-keys 2>/dev/null || true
    fi
}

# Function to create optimized mining script
create_mining_scripts() {
    print_header "Creating Optimized Mining Scripts"
    
    cd "$INSTALL_DIR"
    
    # Create peer string
    peer_args=""
    for peer in "${PEER_LIST[@]}"; do
        peer_args="$peer_args --peer $peer"
    done
    
    # Create individual miner scripts
    for i in $(seq 1 $MINERS_COUNT); do
        miner_dir="miner$i"
        mkdir -p "$miner_dir"
        
        cat > "$miner_dir/start_miner.sh" << EOF
#!/bin/bash

# Miner $i startup script
cd "$INSTALL_DIR/$miner_dir"

# Clean old data
rm -rf ./.data.nockchain .socket/nockchain_npc.sock

# Set environment
export PATH="/root/.cargo/bin:\$PATH"
export RUST_LOG=info,nockchain=info,nockchain_libp2p_io=info,libp2p=info,libp2p_quic=info
export MINIMAL_LOG_FORMAT=true

# Memory optimizations for low RAM systems
if [[ $total_ram_gb -lt 32 ]]; then
    export RUST_MIN_STACK=2097152  # 2MB stack size
    export MALLOC_ARENA_MAX=2      # Limit memory arenas
    ulimit -v $((total_ram_gb * 1024 * 1024 * 3 / 4))  # Limit virtual memory to 75% of RAM
fi

# Enable memory overcommit
sysctl -w vm.overcommit_memory=1

# Start mining
echo "Starting Nockchain Miner $i..."
echo "Mining to pubkey: $MINING_PUBKEY"
echo "Peers: ${#PEER_LIST[@]} configured"

nockchain --mine \\
    --mining-pubkey $MINING_PUBKEY \\
    $peer_args
EOF
        
        chmod +x "$miner_dir/start_miner.sh"
    done
    
    # Create master control script
    cat > "mining_control.sh" << EOF
#!/bin/bash

# Nockchain Mining Control Script
INSTALL_DIR="$INSTALL_DIR"
MINERS_COUNT=$MINERS_COUNT

case "\$1" in
    start)
        echo "Starting \$MINERS_COUNT miners..."
        for i in \$(seq 1 \$MINERS_COUNT); do
            echo "Starting miner \$i..."
            screen -dmS "miner\$i" bash "\$INSTALL_DIR/miner\$i/start_miner.sh"
            sleep 2
        done
        echo "All miners started!"
        echo "Use 'screen -ls' to see running miners"
        echo "Use 'screen -r miner1' to attach to miner 1"
        ;;
    stop)
        echo "Stopping all miners..."
        for i in \$(seq 1 \$MINERS_COUNT); do
            screen -XS "miner\$i" quit 2>/dev/null || true
        done
        echo "All miners stopped!"
        ;;
    restart)
        \$0 stop
        sleep 5
        \$0 start
        ;;
    status)
        echo "Miner Status:"
        screen -ls | grep miner || echo "No miners running"
        ;;
    logs)
        if [[ -n "\$2" ]]; then
            screen -r "miner\$2"
        else
            echo "Usage: \$0 logs <miner_number>"
            echo "Available miners: 1-\$MINERS_COUNT"
        fi
        ;;
    balance)
        cd "\$INSTALL_DIR/miner1"
        export PATH="/root/.cargo/bin:\$PATH"
        echo "Checking wallet balance..."
        nockchain-wallet --nockchain-socket .socket/nockchain_npc.sock list-notes
        ;;
    *)
        echo "Nockchain Mining Control"
        echo "Usage: \$0 {start|stop|restart|status|logs <miner_number>|balance}"
        echo ""
        echo "Commands:"
        echo "  start    - Start all miners"
        echo "  stop     - Stop all miners"
        echo "  restart  - Restart all miners"
        echo "  status   - Show miner status"
        echo "  logs N   - View logs for miner N"
        echo "  balance  - Check wallet balance"
        ;;
esac
EOF
    
    chmod +x "mining_control.sh"
    
    # Create system service
    cat > "/tmp/nockchain-mining.service" << EOF
[Unit]
Description=Nockchain Mining Service
After=network.target

[Service]
Type=forking
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/mining_control.sh start
ExecStop=$INSTALL_DIR/mining_control.sh stop
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    mv "/tmp/nockchain-mining.service" "/etc/systemd/system/"
    systemctl daemon-reload
    
    print_status "Mining scripts created successfully!"
}

# Function to create monitoring script
create_monitoring() {
    print_header "Creating Monitoring Tools"
    
    cd "$INSTALL_DIR"
    
    cat > "monitor.sh" << EOF
#!/bin/bash

# Nockchain Mining Monitor
INSTALL_DIR="$INSTALL_DIR"

while true; do
    clear
    echo "=================================="
    echo "Nockchain Mining Monitor"
    echo "=================================="
    echo "Time: \$(date)"
    echo ""
    
    echo "System Resources:"
    echo "CPU Usage: \$(top -bn1 | grep "Cpu(s)" | awk '{print \$2}' | cut -d'%' -f1)%"
    echo "Memory: \$(free -h | awk 'NR==2{printf "%.1f/%.1f GB (%.2f%%)", \$3/1024/1024, \$2/1024/1024, \$3*100/\$2}')"
    echo "Disk: \$(df -h / | awk 'NR==2{printf "%s/%s (%s)", \$3, \$2, \$5}')"
    echo ""
    
    echo "Mining Status:"
    miner_count=\$(screen -ls | grep -c miner || echo 0)
    echo "Active Miners: \$miner_count/$MINERS_COUNT"
    
    if [[ \$miner_count -gt 0 ]]; then
        echo ""
        echo "Miner Processes:"
        screen -ls | grep miner | while read line; do
            echo "  \$line"
        done
    fi
    
    echo ""
    echo "Network Connections:"
    netstat -an | grep :3006 | wc -l | xargs echo "P2P Connections:"
    
    echo ""
    echo "Press Ctrl+C to exit monitor"
    sleep 10
done
EOF
    
    chmod +x "monitor.sh"
    
    print_status "Monitoring tools created!"
}

# Function to display final instructions
show_final_instructions() {
    print_header "Installation Complete!"
    
    echo -e "${GREEN}Nockchain mining setup completed successfully!${NC}"
    echo ""
    echo -e "${YELLOW}Mining Configuration:${NC}"
    echo "  • Mining Pubkey: $MINING_PUBKEY"
    echo "  • Miner Instances: $MINERS_COUNT"
    echo "  • Peer Connections: ${#PEER_LIST[@]} configured"
    echo ""
    echo -e "${YELLOW}Quick Start Commands:${NC}"
    echo "  • Start mining:    cd $INSTALL_DIR && ./mining_control.sh start"
    echo "  • Stop mining:     cd $INSTALL_DIR && ./mining_control.sh stop"
    echo "  • Check status:    cd $INSTALL_DIR && ./mining_control.sh status"
    echo "  • View logs:       cd $INSTALL_DIR && ./mining_control.sh logs 1"
    echo "  • Check balance:   cd $INSTALL_DIR && ./mining_control.sh balance"
    echo "  • Monitor system:  cd $INSTALL_DIR && ./monitor.sh"
    echo ""
    echo -e "${YELLOW}System Service:${NC}"
    echo "  • Enable auto-start: systemctl enable nockchain-mining"
    echo "  • Start service:     systemctl start nockchain-mining"
    echo "  • Check service:     systemctl status nockchain-mining"
    echo ""
    echo -e "${YELLOW}Important Notes:${NC}"
    echo "  • Mining performance scales with available RAM and CPU"
    echo "  • Systems with 16-32GB RAM will use large swap files for optimization"
    echo "  • Monitor your system resources regularly"
    echo "  • Backup your wallet keys regularly"
    echo "  • Check logs for mining activity and errors"
    echo "  • Lower RAM systems may have slower mining but will still function"
    echo ""
    echo -e "${GREEN}Happy Mining! 🚀${NC}"
    echo ""
    echo -e "${CYAN}To start mining now, run:${NC}"
    echo -e "${CYAN}cd $INSTALL_DIR && ./mining_control.sh start${NC}"
}

# Main installation function
main() {
    print_header "Nockchain Optimized Mining Installer (ROOT VERSION)"
    echo -e "${CYAN}This script will install and optimize Nockchain for mining on Ubuntu 22.04${NC}"
    echo -e "${CYAN}Mining Pubkey: $MINING_PUBKEY${NC}"
    echo ""
    
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}WARNING: Running as root is not recommended for security reasons!${NC}"
        echo -e "${YELLOW}Consider creating a regular user account for mining operations.${NC}"
        echo ""
    fi
    
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    
    # Run installation steps
    check_system_requirements
    optimize_system
    install_dependencies
    build_nockchain
    setup_wallet
    create_mining_scripts
    create_monitoring
    show_final_instructions
}

# Run main function
main "$@" 
