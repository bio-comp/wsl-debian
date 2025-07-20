#!/bin/bash
#
# One-shot script to set up a comprehensive scientific & creative development environment on Debian WSL.
# This is a "kitchen sink" script installing a wide range of tools.
#
# Sections:
#   1. System Foundation & Core Tools
#   2. Development Languages & Runtimes
#   3. Python Ecosystem
#   4. DevOps, Cloud & Containers
#   5. Databases & Data Stores
#   6. Scientific & Creative Suite
#   7. AI/ML & Kubernetes
#   8. Terminal Modernization
#   9. GPU Computing (Conditional)
#

# Exit immediately if a command exits with a non-zero status.
set -e

# Get the actual username (important for WSL)
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

# --- Helper Functions ---
print_header() {
  echo -e "\n\n=================================================="
  echo "    $1"
  echo "=================================================="
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to safely add apt repository
add_apt_repo() {
    local repo_file="$1"
    local keyring="$2"
    local key_url="$3"
    local repo_line="$4"
    
    if [ ! -f "$repo_file" ]; then
        echo "Adding repository: $repo_file"
        if [ -n "$key_url" ]; then
            curl -fsSL "$key_url" | sudo gpg --dearmor -o "$keyring"
        fi
        echo "$repo_line" | sudo tee "$repo_file"
        sudo chmod 644 "$keyring" "$repo_file" 2>/dev/null || true
    else
        echo "Repository already exists: $repo_file"
    fi
}

# --- Cleanup any previous broken installations ---
print_header "Initial Cleanup: Fixing any previous installation issues"

# Clean up broken pyenv installations
if [ -d "/root/.pyenv" ] && [ "$EUID" -ne 0 ]; then
    echo "⚠ WARNING: Found pyenv installation in /root/.pyenv"
    echo "Cleaning up problematic pyenv installation..."
    sudo rm -rf /root/.pyenv
    echo "✓ Removed /root/.pyenv"
fi

# Clean up broken repository files
echo "Cleaning up any broken repository configurations..."
for broken_repo in "/etc/apt/sources.list.d/pgdg.list" "/etc/apt/sources.list.d/neo4j.list"; do
    if [ -f "$broken_repo" ]; then
        if ! grep -q "signed-by" "$broken_repo" 2>/dev/null; then
            echo "Removing potentially broken repository: $broken_repo"
            sudo rm -f "$broken_repo"
        fi
    fi
done

# Clean up any broken package installations
sudo apt-get clean
sudo apt-get autoremove -y

# --- 1. System Foundation & Core Tools ---
print_header "Step 1: Updating System & Installing Base Tools"
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y \
    build-essential pkg-config libssl-dev git curl wget ca-certificates gnupg \
    apt-transport-https unzip stow cmake clang zsh jq poppler-utils imagemagick \
    valgrind lsb-release software-properties-common

# --- 2. Development Languages & Runtimes ---
print_header "Step 2: Installing Language Toolchains (Java, Rust, Node, Clojure)"

## Java (for GATK, Clojure, etc.)
sudo apt-get install -y openjdk-17-jdk

## Rust via rustup
if ! command_exists rustup; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # Source cargo env for current session
    export PATH="$ACTUAL_HOME/.cargo/bin:$PATH"
else
    echo "Rust is already installed."
fi

## Node.js & TypeScript via nvm
if [ ! -d "$ACTUAL_HOME/.nvm" ]; then
    echo "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    # Source nvm for current session
    export NVM_DIR="$ACTUAL_HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    nvm install --lts
    nvm use --lts
    npm install -g typescript
else
    echo "nvm is already installed."
fi

## Clojure
if ! command_exists clojure; then
    echo "Installing Clojure..."
    curl -L -o /tmp/clojure-install.sh https://download.clojure.org/install/linux-install.sh
    chmod +x /tmp/clojure-install.sh
    sudo /tmp/clojure-install.sh
    rm -f /tmp/clojure-install.sh
else
    echo "Clojure is already installed."
fi

# --- 3. Python Ecosystem ---
print_header "Step 3: Installing Python Tools (pyenv, Poetry, uv, TheFuck)"

# Check for problematic pyenv installations
if [ -d "/root/.pyenv" ] && [ "$EUID" -ne 0 ]; then
    echo "⚠ WARNING: Found pyenv installation in /root/.pyenv"
    echo "This typically happens when the script was previously run with sudo."
    echo "Cleaning up problematic pyenv installation..."
    sudo rm -rf /root/.pyenv
    echo "✓ Removed /root/.pyenv"
fi

# Check for broken pyenv installation in user directory
PYENV_ALREADY_INSTALLED=false
if [ -d "$ACTUAL_HOME/.pyenv" ]; then
    echo "⚠ Found existing pyenv installation at $ACTUAL_HOME/.pyenv"
    # Check if it's a working installation
    if [ ! -x "$ACTUAL_HOME/.pyenv/bin/pyenv" ]; then
        echo "Installation appears to be broken or incomplete. Removing..."
        rm -rf "$ACTUAL_HOME/.pyenv"
        echo "✓ Removed broken pyenv installation"
    else
        # Check if pyenv command works
        if ! "$ACTUAL_HOME/.pyenv/bin/pyenv" --version >/dev/null 2>&1; then
            echo "pyenv command is not working properly. Removing..."
            rm -rf "$ACTUAL_HOME/.pyenv"
            echo "✓ Removed non-functional pyenv installation"
        else
            echo "Found working pyenv installation, skipping installation."
            export PYENV_ROOT="$ACTUAL_HOME/.pyenv"
            export PATH="$PYENV_ROOT/bin:$PATH"
            eval "$(pyenv init --path)"
            eval "$(pyenv init -)"
            PYENV_ALREADY_INSTALLED=true
        fi
    fi
fi

# Also check for other common problematic locations
for problematic_dir in "/home/root/.pyenv"; do
    if [ -d "$problematic_dir" ]; then
        echo "⚠ Found problematic pyenv installation at $problematic_dir, cleaning up..."
        sudo rm -rf "$problematic_dir" 2>/dev/null || rm -rf "$problematic_dir"
        echo "✓ Removed $problematic_dir"
    fi
done

if ! command_exists pyenv && [ "$PYENV_ALREADY_INSTALLED" = false ]; then
    echo "Installing pyenv dependencies..."
    sudo apt-get install -y make libbz2-dev libffi-dev libgdbm-dev liblzma-dev \
        libncurses5-dev libreadline-dev libsqlite3-dev libxml2-dev libxmlsec1-dev \
        llvm tk-dev uuid-dev zlib1g-dev
    
    echo "Installing pyenv..."
    # Ensure we're installing to the correct user directory
    export PYENV_ROOT="$ACTUAL_HOME/.pyenv"
    
    # Run the pyenv installer with explicit environment
    if PYENV_ROOT="$ACTUAL_HOME/.pyenv" curl https://pyenv.run | bash; then
        echo "✓ pyenv installed successfully"
    else
        echo "❌ pyenv installation failed"
        echo "Manual cleanup may be required. Try running:"
        echo "  rm -rf $ACTUAL_HOME/.pyenv"
        echo "  rm -rf /root/.pyenv"
        echo "Then re-run the script."
        exit 1
    fi
    
    # Add pyenv to PATH for current session
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    
    # Ensure proper ownership
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$PYENV_ROOT"
    
    # Install latest stable Python
    echo "Installing latest Python version..."
    LATEST_PYTHON=$(pyenv install -l | grep -E "^\s*3\.(11|12)\.[0-9]+$" | grep -v dev | tail -n 1 | xargs)
    if [ -n "$LATEST_PYTHON" ]; then
        echo "Installing Python $LATEST_PYTHON..."
        pyenv install "$LATEST_PYTHON"
        pyenv global "$LATEST_PYTHON"
        echo "✓ Python $LATEST_PYTHON installed and set as global"
    else
        echo "⚠ Could not determine latest Python version"
    fi
elif [ "$PYENV_ALREADY_INSTALLED" = true ]; then
    echo "✓ Using existing pyenv installation"
else
    echo "pyenv is already installed and available in PATH."
    export PYENV_ROOT="$ACTUAL_HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
fi

# Install Poetry
if ! command_exists poetry; then
    echo "Installing Poetry..."
    curl -sSL https://install.python-poetry.org | python3 -
fi

# Install uv
if ! command_exists uv; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Install Python packages as the actual user, not root
echo "Installing Python packages..."
if [ "$EUID" -eq 0 ]; then
    # If running as root, install for the actual user
    sudo -u "$ACTUAL_USER" -H bash -c "
        export PATH=\"$ACTUAL_HOME/.pyenv/bin:\$PATH\"
        eval \"\$(pyenv init --path)\"
        eval \"\$(pyenv init -)\"
        pip install --user qiskit openmm thefuck
    "
else
    # If running as regular user
    pip install --user qiskit openmm thefuck
fi

# --- 4. DevOps, Cloud & Containers ---
print_header "Step 4: Installing Editors, DevOps, Nix & Cloud Tools"

## Add external repositories safely
sudo mkdir -p /etc/apt/keyrings

# VS Code
add_apt_repo "/etc/apt/sources.list.d/vscode.list" \
    "/usr/share/keyrings/microsoft-archive-keyring.gpg" \
    "https://packages.microsoft.com/keys/microsoft.asc" \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main"

# Docker
add_apt_repo "/etc/apt/sources.list.d/docker.list" \
    "/etc/apt/keyrings/docker.gpg" \
    "https://download.docker.com/linux/debian/gpg" \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

# Google Cloud (using new signing method)
add_apt_repo "/etc/apt/sources.list.d/google-cloud-sdk.list" \
    "/usr/share/keyrings/cloud.google.gpg" \
    "https://packages.cloud.google.com/apt/doc/apt-key.gpg" \
    "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main"

## Update and install from repos
sudo apt-get update
sudo apt-get install -y code neovim emacs \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    google-cloud-sdk

# Add user to docker group
sudo usermod -aG docker "$ACTUAL_USER"

## AWS CLI
if ! command_exists aws; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    cd /tmp && unzip -o awscliv2.zip && sudo ./aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws/
fi

## Nix Package Manager
if ! command_exists nix; then
    echo "Installing Nix..."
    
    # Check for and stop any running Nix processes
    echo "Checking for running Nix processes..."
    if pgrep -f "nix-daemon\|nix-store\|nix" >/dev/null 2>&1; then
        echo "⚠ Found running Nix processes. Stopping them..."
        sudo pkill -f "nix-daemon" 2>/dev/null || true
        sudo pkill -f "nix-store" 2>/dev/null || true
        sudo pkill -f "nix" 2>/dev/null || true
        sleep 2
        
        # Force kill if still running
        sudo pkill -9 -f "nix-daemon" 2>/dev/null || true
        sudo pkill -9 -f "nix-store" 2>/dev/null || true
        sudo pkill -9 -f "nix" 2>/dev/null || true
        echo "✓ Stopped Nix processes"
    fi
    
    # Stop and disable nix-daemon service if it exists
    if systemctl is-active --quiet nix-daemon 2>/dev/null; then
        echo "Stopping nix-daemon service..."
        sudo systemctl stop nix-daemon.socket nix-daemon.service 2>/dev/null || true
        sudo systemctl disable nix-daemon.socket nix-daemon.service 2>/dev/null || true
    fi
    
    # Check for and clean up ALL previous Nix installation backup files
    echo "⚠ Checking for previous Nix installation backup files..."
    
    # List of all possible backup files that Nix creates
    declare -a backup_files=(
        "/etc/bash.bashrc.backup-before-nix"
        "/etc/bashrc.backup-before-nix"
        "/etc/profile.d/nix.sh.backup-before-nix"
        "/etc/zshrc.backup-before-nix"
        "/etc/zsh/zshrc.backup-before-nix"
    )
    
    # Check and clean up each backup file
    backup_found=false
    for backup_file in "${backup_files[@]}"; do
        if [ -f "$backup_file" ]; then
            backup_found=true
            echo "Found backup file: $backup_file"
            
            # Create a timestamped backup of both current and backup files
            current_file="${backup_file%.backup-before-nix}"
            timestamp=$(date +%Y%m%d_%H%M%S)
            
            if [ -f "$current_file" ]; then
                sudo cp "$current_file" "/tmp/$(basename $current_file).current.$timestamp" 2>/dev/null || true
            fi
            sudo cp "$backup_file" "/tmp/$(basename $backup_file).$timestamp" 2>/dev/null || true
            
            # Check if the backup file has Nix content (it shouldn't)
            if grep -qi "nix" "$backup_file" 2>/dev/null; then
                echo "⚠ WARNING: Found Nix content in $backup_file. This suggests a broken previous installation."
                echo "Proceeding with caution..."
            fi
            
            # Restore the backup (this is what Nix installer wants)
            sudo mv "$backup_file" "$current_file"
            echo "✓ Restored $backup_file to $current_file"
        fi
    done
    
    if [ "$backup_found" = true ]; then
        echo "✓ Cleaned up previous Nix installation backup files"
    else
        echo "No previous Nix backup files found"
    fi
    
    # Also clean up user-level Nix files if they exist
    user_backup_files=(
        "$ACTUAL_HOME/.bash_profile.backup-before-nix"
        "$ACTUAL_HOME/.bashrc.backup-before-nix"
        "$ACTUAL_HOME/.zshrc.backup-before-nix"
        "$ACTUAL_HOME/.profile.backup-before-nix"
    )
    
    for user_backup in "${user_backup_files[@]}"; do
        if [ -f "$user_backup" ]; then
            echo "Cleaning up user-level backup: $user_backup"
            current_user_file="${user_backup%.backup-before-nix}"
            [ -f "$current_user_file" ] && cp "$user_backup" "$current_user_file" 2>/dev/null || true
            rm -f "$user_backup"
        fi
    done
    
    # Remove broken Nix installation completely
    if [ -d "/nix" ]; then
        echo "⚠ Found existing /nix directory. Removing broken Nix installation..."
        
        # Unmount any nix stores that might be mounted
        sudo umount /nix/store 2>/dev/null || true
        
        # Remove the entire nix directory
        sudo rm -rf /nix
        echo "✓ Removed broken Nix installation"
    fi
    
    # Clean up nix users and groups from any previous installation
    echo "Cleaning up any previous Nix users and groups..."
    for i in $(seq 1 32); do
        nixbld_user="nixbld$i"
        if id "$nixbld_user" >/dev/null 2>&1; then
            sudo userdel "$nixbld_user" 2>/dev/null || true
        fi
    done
    
    if getent group nixbld >/dev/null 2>&1; then
        sudo groupdel nixbld 2>/dev/null || true
    fi
    
    # Remove systemd services
    sudo rm -f /etc/systemd/system/nix-daemon.service /etc/systemd/system/nix-daemon.socket
    sudo systemctl daemon-reload
    
    echo "✓ Cleaned up previous Nix installation completely"
    
    # Now attempt the installation
    echo "Starting fresh Nix installation..."
    if curl -L https://nixos.org/nix/install | sh -s -- --daemon; then
        echo "✓ Nix installed successfully"
        echo "Note: Nix will be available in new shell sessions"
    else
        echo "❌ Nix installation failed"
        echo "You may need to manually investigate /tmp for installation logs"
        echo "Continuing with the rest of the script..."
    fi
else
    echo "Nix is already installed."
fi

# --- 5. Databases & Data Stores ---
print_header "Step 5: Installing Databases (Postgres, MySQL, Redis, Neo4j)"

# Clean up any broken repository configurations
echo "Cleaning up potentially broken repository configurations..."
sudo rm -f /etc/apt/sources.list.d/pgdg.list.save
sudo rm -f /etc/apt/sources.list.d/neo4j.list.save

# PostgreSQL - fix common repository issues
add_apt_repo "/etc/apt/sources.list.d/pgdg.list" \
    "/usr/share/keyrings/postgresql.gpg" \
    "https://www.postgresql.org/media/keys/ACCC4CF8.asc" \
    "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main"

# Neo4j
add_apt_repo "/etc/apt/sources.list.d/neo4j.list" \
    "/usr/share/keyrings/neo4j.gpg" \
    "https://debian.neo4j.com/neotechnology.gpg.key" \
    "deb [signed-by=/usr/share/keyrings/neo4j.gpg] https://debian.neo4j.com stable 5"

## Install from repos (with error handling)
sudo apt-get update
if ! sudo apt-get install -y postgresql postgresql-contrib mysql-server redis-server; then
    echo "⚠ Some database packages failed to install. Continuing with available packages..."
fi

# Neo4j might not be available on all systems
if ! sudo apt-get install -y neo4j; then
    echo "⚠ Neo4j installation failed. You can install it manually later if needed."
fi

# --- 6. Scientific & Creative Suite ---
print_header "Step 6: Installing Scientific & Creative Tools"

## Scientific tools (check availability and use alternative sources)
echo "Installing available scientific tools..."
sudo apt-get install -y minimap2 samtools bedtools sra-toolkit || echo "Some basic scientific tools may not be available"

# Try to install additional scientific tools with better error handling
for tool in ncbi-blast+ gromacs lammps cp2k; do
    if sudo apt-get install -y "$tool" 2>/dev/null; then
        echo "✓ Installed $tool"
    else
        echo "⚠ $tool not available in current repositories"
    fi
done

# Handle entrez-direct separately (it's in a different package or needs manual install)
if ! sudo apt-get install -y entrez-direct 2>/dev/null; then
    echo "⚠ entrez-direct not available via apt. Installing manually..."
    if command_exists perl; then
        curl -fsSL https://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/install-edirect.sh | bash
        echo "✓ entrez-direct installed manually"
        echo "📝 Note: Add $ACTUAL_HOME/edirect to your PATH"
    else
        echo "⚠ entrez-direct requires Perl. Install with: sudo apt install perl"
    fi
fi

# Handle STAR aligner (often needs to be compiled from source)
if ! sudo apt-get install -y star 2>/dev/null; then
    echo "⚠ STAR aligner not available via apt. You may need to install from source:"
    echo "   https://github.com/alexdobin/STAR"
fi

## LaTeX
sudo apt-get install -y texlive-latex-base texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended

## Creative tools
sudo apt-get install -y gimp inkscape

## 3D Printing (PrusaSlicer AppImage) - get latest release
echo "Installing PrusaSlicer..."
mkdir -p "$ACTUAL_HOME/.local/bin"

# Get the latest release dynamically
PRUSA_LATEST=$(curl -s https://api.github.com/repos/prusa3d/PrusaSlicer/releases/latest | grep -o '"tag_name": "version_[^"]*"' | cut -d'"' -f4 | sed 's/version_//')
if [ -n "$PRUSA_LATEST" ]; then
    PRUSA_URL="https://github.com/prusa3d/PrusaSlicer/releases/download/version_${PRUSA_LATEST}/PrusaSlicer-${PRUSA_LATEST}+linux-x64-GTK3.AppImage"
    echo "Downloading PrusaSlicer $PRUSA_LATEST..."
    if wget -q --spider "$PRUSA_URL" && wget "$PRUSA_URL" -O "$ACTUAL_HOME/.local/bin/PrusaSlicer.AppImage"; then
        chmod +x "$ACTUAL_HOME/.local/bin/PrusaSlicer.AppImage"
        chown "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.local/bin/PrusaSlicer.AppImage"
        echo "✓ PrusaSlicer $PRUSA_LATEST installed"
    else
        echo "⚠ PrusaSlicer download failed - trying fallback version"
        # Fallback to a known working version
        FALLBACK_URL="https://github.com/prusa3d/PrusaSlicer/releases/download/version_2.8.0/PrusaSlicer-2.8.0+linux-x64-GTK3.AppImage"
        if wget "$FALLBACK_URL" -O "$ACTUAL_HOME/.local/bin/PrusaSlicer.AppImage" 2>/dev/null; then
            chmod +x "$ACTUAL_HOME/.local/bin/PrusaSlicer.AppImage"
            chown "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.local/bin/PrusaSlicer.AppImage"
            echo "✓ PrusaSlicer fallback version installed"
        else
            echo "⚠ PrusaSlicer installation failed completely"
        fi
    fi
else
    echo "⚠ Could not determine latest PrusaSlicer version"
fi

# --- 7. AI/ML & Kubernetes ---
print_header "Step 7: Installing Local AI & Kubernetes Tools"

## Kubernetes tools
if ! command_exists kind; then
    echo "Installing kind..."
    curl -Lo /tmp/kind "https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64"
    chmod +x /tmp/kind && sudo mv /tmp/kind /usr/local/bin/
fi

if ! command_exists kubectl; then
    echo "Installing kubectl..."
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x kubectl && sudo mv kubectl /usr/local/bin/
fi

## Reinforcement Learning System Dependencies
sudo apt-get install -y libsdl2-dev libosmesa6-dev patchelf

## Ollama
if ! command_exists ollama; then
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
fi

## llama.cpp
if [ ! -d "$ACTUAL_HOME/dev/llama.cpp" ]; then
    echo "Installing llama.cpp..."
    mkdir -p "$ACTUAL_HOME/dev"
    git clone https://github.com/ggerganov/llama.cpp.git "$ACTUAL_HOME/dev/llama.cpp"
    cd "$ACTUAL_HOME/dev/llama.cpp"
    
    # Check for NVIDIA GPU (more comprehensive check)
    HAS_NVIDIA_GPU=false
    if command_exists nvidia-smi; then
        if nvidia-smi >/dev/null 2>&1; then
            HAS_NVIDIA_GPU=true
            echo "✓ NVIDIA GPU detected via nvidia-smi"
        fi
    elif lspci | grep -i nvidia >/dev/null 2>&1; then
        HAS_NVIDIA_GPU=true
        echo "✓ NVIDIA GPU detected via lspci"
    elif [ -d "/proc/driver/nvidia" ]; then
        HAS_NVIDIA_GPU=true
        echo "✓ NVIDIA GPU detected via /proc/driver/nvidia"
    fi
    
    # Check for CUDA installation
    HAS_CUDA=false
    if command_exists nvcc; then
        HAS_CUDA=true
        echo "✓ CUDA compiler (nvcc) detected"
    elif [ -d "/usr/local/cuda" ]; then
        export PATH="/usr/local/cuda/bin:$PATH"
        if command_exists nvcc; then
            HAS_CUDA=true
            echo "✓ CUDA found in /usr/local/cuda"
        fi
    elif [ -d "/opt/cuda" ]; then
        export PATH="/opt/cuda/bin:$PATH"
        if command_exists nvcc; then
            HAS_CUDA=true
            echo "✓ CUDA found in /opt/cuda"
        fi
    fi
    
    # Use CMake build system (new required method)
    echo "Building llama.cpp using CMake..."
    mkdir -p build
    cd build
    
    if [ "$HAS_NVIDIA_GPU" = true ] && [ "$HAS_CUDA" = true ]; then
        echo "Building with CUDA support for your RTX 4090..."
        cmake .. -DLLAMA_CUDA=ON
    elif [ "$HAS_NVIDIA_GPU" = true ] && [ "$HAS_CUDA" = false ]; then
        echo "⚠ NVIDIA GPU detected but CUDA not found. Installing CUDA first..."
        echo "Building CPU version for now. You can rebuild after CUDA installation."
        cmake ..
    else
        echo "Building CPU version..."
        cmake ..
    fi
    
    # Build with appropriate number of cores
    NPROC=$(nproc 2>/dev/null || echo "4")
    make -j"$NPROC"
    
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/dev"
    cd - > /dev/null
    
    echo "✓ llama.cpp built successfully"
    if [ "$HAS_NVIDIA_GPU" = true ] && [ "$HAS_CUDA" = false ]; then
        echo "📝 Note: To rebuild with CUDA support after CUDA installation, run:"
        echo "   cd $ACTUAL_HOME/dev/llama.cpp/build && cmake .. -DLLAMA_CUDA=ON && make -j$NPROC"
    fi
fi

# --- 8. Terminal Modernization ---
print_header "Step 8: Installing Modern Terminal Tools"

## Install bat, fd, ripgrep, and try fastfetch
sudo apt-get install -y bat fd-find ripgrep

# Handle fastfetch separately (might not be in all repositories)
if ! sudo apt-get install -y fastfetch 2>/dev/null; then
    echo "⚠ fastfetch not available via apt. Installing from GitHub..."
    # Install fastfetch from GitHub releases
    FASTFETCH_VERSION=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
    if [ -n "$FASTFETCH_VERSION" ]; then
        FASTFETCH_URL="https://github.com/fastfetch-cli/fastfetch/releases/download/${FASTFETCH_VERSION}/fastfetch-linux-amd64.deb"
        echo "Installing fastfetch $FASTFETCH_VERSION..."
        if wget "$FASTFETCH_URL" -O /tmp/fastfetch.deb 2>/dev/null; then
            sudo dpkg -i /tmp/fastfetch.deb || sudo apt-get install -f -y
            rm -f /tmp/fastfetch.deb
            echo "✓ fastfetch installed from GitHub"
        else
            echo "⚠ fastfetch installation failed. Using neofetch as alternative..."
            sudo apt-get install -y neofetch 2>/dev/null || echo "No system info tool available"
        fi
    else
        echo "⚠ Could not determine fastfetch version. Using neofetch as fallback..."
        sudo apt-get install -y neofetch 2>/dev/null || echo "No system info tool available"
    fi
else
    echo "✓ fastfetch installed from repositories"
fi

# Create symlinks for better command names
mkdir -p "$ACTUAL_HOME/.local/bin"
ln -sf /usr/bin/batcat "$ACTUAL_HOME/.local/bin/bat" 2>/dev/null || true
ln -sf /usr/bin/fdfind "$ACTUAL_HOME/.local/bin/fd" 2>/dev/null || true

## Eza (modern ls replacement)
add_apt_repo "/etc/apt/sources.list.d/gierens.list" \
    "/etc/apt/keyrings/gierens.gpg" \
    "https://raw.githubusercontent.com/eza-community/eza/main/deb.asc" \
    "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main"

sudo apt-get update && sudo apt-get install -y eza

## Zoxide (smart cd)
if ! command_exists zoxide; then
    echo "Installing zoxide..."
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
fi

## Oh My Zsh & Plugins (only if not already installed)
if [ ! -d "$ACTUAL_HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    # Use a more reliable installation method
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    
    ZSH_CUSTOM="$ACTUAL_HOME/.oh-my-zsh/custom"
    
    # Install plugins if they don't exist
    [ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ] && \
        git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
    
    [ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ] && \
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
    
    [ ! -d "${ZSH_CUSTOM}/themes/powerlevel10k" ] && \
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM}/themes/powerlevel10k"
    
    # Fix ownership
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.oh-my-zsh"
fi

## .zshrc Configuration (backup existing)
if [ -f "$ACTUAL_HOME/.zshrc" ]; then
    cp "$ACTUAL_HOME/.zshrc" "$ACTUAL_HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
fi

cat <<'EOF' > "$ACTUAL_HOME/.zshrc"
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Theme: Powerlevel10k
ZSH_THEME="powerlevel10k/powerlevel10k"

# Add plugins
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

# Source Oh My Zsh
source $ZSH/oh-my-zsh.sh

# To customize Powerlevel10k, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# --- Tool Configuration ---
# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Rust
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# Poetry
[[ -f "$HOME/.local/bin/poetry" ]] && export PATH="$HOME/.local/bin:$PATH"

# CUDA (for RTX 4090 and deep learning)
if [ -d "/usr/local/cuda/bin" ]; then
    export PATH="/usr/local/cuda/bin:$PATH"
    export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
    export CUDA_HOME="/usr/local/cuda"
fi

# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

# Zoxide
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# TheFuck
command -v thefuck >/dev/null 2>&1 && eval "$(thefuck --alias)"

# Modern Tool Aliases
alias ls='eza --icons'
alias la='eza -a --icons'
alias ll='eza -l --icons'
alias l='eza -l --icons'
alias cat='bat --paging=never'

# GPU/AI Development Aliases
alias gpu-test='python3 ~/test_gpu.py'
alias gpu-info='nvidia-smi'
alias cuda-version='nvcc --version'

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"
EOF

chown "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.zshrc"

## Nerd Font Download
echo "Downloading Nerd Font..."
mkdir -p "$ACTUAL_HOME/.local/share/fonts"
if wget -q --spider "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip"; then
    wget "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip" -P "$ACTUAL_HOME/.local/share/fonts"
    unzip -o "$ACTUAL_HOME/.local/share/fonts/FiraCode.zip" -d "$ACTUAL_HOME/.local/share/fonts/FiraCodeNerdFont"
    rm -f "$ACTUAL_HOME/.local/share/fonts/FiraCode.zip"
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.local/share/fonts"
else
    echo "⚠ Font download failed - URL may be outdated"
fi

## Set Zsh as default shell
sudo chsh -s "$(which zsh)" "$ACTUAL_USER"

# --- 9. GPU Computing (Conditional) ---
print_header "Step 9: Checking for NVIDIA GPU & Installing CUDA"
if command_exists nvidia-smi; then
    echo "NVIDIA GPU detected. Installing CUDA Toolkit..."
    
    # Use modern GPG key method instead of deprecated apt-key
    wget -O /tmp/cuda-keyring.deb https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i /tmp/cuda-keyring.deb
    rm -f /tmp/cuda-keyring.deb
    
    sudo apt-get update
    sudo apt-get -y install cuda-toolkit
    
    # Optional: Install profilers if available
    sudo apt-get install -y nsight-systems nsight-compute 2>/dev/null || echo "⚠ Nsight profilers not available"
else
    echo "No NVIDIA GPU detected by nvidia-smi. Skipping CUDA installation."
fi

# --- Final Cleanup and Message ---
print_header "Final Cleanup"
sudo apt-get autoremove -y
sudo apt-get autoclean

# --- Final Message ---
print_header "Setup Complete! IMPORTANT NEXT STEPS:"
echo "✅ Zsh is now the default shell. Please CLOSE AND REOPEN YOUR TERMINAL."
echo "✅ When you reopen, the Powerlevel10k configuration wizard will start automatically. Follow its prompts."
echo ""
echo "❗ ACTION REQUIRED 1: CONFIGURE FONT ❗"
echo "   To get icons in your prompt, you MUST install a Nerd Font on your WINDOWS machine."
echo "   1. A recommended font, FiraCode Nerd Font, has been downloaded into WSL for you."
echo "   2. In Windows File Explorer, navigate to: \\\\wsl.localhost\\debian\\home\\$ACTUAL_USER\\.local\\share\\fonts\\FiraCodeNerdFont"
echo "   3. Right-click on 'FiraCodeNerdFontMono-Regular.ttf' and choose 'Install for all users'."
echo "   4. In Windows Terminal, go to Settings > Profiles > Debian > Appearance and change the 'Font face' to 'FiraCode Nerd Font Mono'."
echo ""
echo "❗ ACTION REQUIRED 2: CONFIGURE TERMINAL THEME ❗"
echo "   To get the Nord Theme with a black background:"
echo "   1. In Windows Terminal Settings, click 'Open JSON file'."
echo "   2. Find the 'schemes' array. Add the Nord color scheme JSON object to it."
echo "   3. In your Debian profile settings (in the JSON file), set 'colorScheme': 'Nord' and 'background': '#000000'."
echo ""
echo "❗ ACTION REQUIRED 3: RESTART FOR DOCKER ❗"
echo "   To use Docker without sudo, you need to restart WSL or log out and back in."
echo "   Run: wsl --shutdown (in Windows PowerShell) then restart your terminal."
echo ""
if [ "$HAS_NVIDIA_GPU" = true ]; then
echo "🚀 GPU DEVELOPMENT ENVIRONMENT READY! 🚀"
echo "   Your RTX 4090 is configured for:"
echo "   • CUDA development and compilation"
echo "   • PyTorch with GPU acceleration"
echo "   • TensorFlow with GPU support"
echo "   • LLM training and inference"
echo "   • Jupyter notebooks with GPU support"
echo ""
echo "   🧪 Test your GPU setup: python3 ~/test_gpu.py"
echo "   📊 Check GPU status: gpu-info (alias for nvidia-smi)"
echo "   🔧 CUDA version: cuda-version (alias for nvcc --version)"
echo ""
fi
echo "Other Notes:"
echo "- Databases: Services for Postgres, MySQL, Redis, and Neo4j are installed."
echo "- Run 'sudo mysql_secure_installation' to secure MySQL."
echo "- Neovim: Is installed but unconfigured. Consider using 'kickstart.nvim' for configuration."
echo "- Your original .zshrc was backed up with a timestamp if it existed."
echo "- llama.cpp: Ready for local LLM inference (rebuild with 'cd ~/dev/llama.cpp/build && make' after CUDA setup)"
echo ""
echo "🎉 Enjoy your powerful development environment! 🎉"
echo "Perfect for scientific computing, AI/ML development, and creative projects!"
