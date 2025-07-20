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

# --- Helper Functions ---
print_header() {
  echo -e "\n\n=================================================="
  echo "    $1"
  echo "=================================================="
}

# --- 1. System Foundation & Core Tools ---
print_header "Step 1: Updating System & Installing Base Tools"
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y \
    build-essential pkg-config libssl-dev git curl wget ca-certificates gnupg \
    apt-transport-https unzip stow cmake clang zsh jq poppler-utils imagemagick \
    valgrind

# --- 2. Development Languages & Runtimes ---
print_header "Step 2: Installing Language Toolchains (Java, Rust, Node, Clojure)"
## Java (for GATK, Clojure, etc.)
sudo apt-get install -y openjdk-17-jdk
## Rust via rustup
if ! command -v rustup &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "Rust is already installed."
fi
## Node.js & TypeScript via nvm
export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
if ! command -v nvm &> /dev/null; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts
    npm install -g typescript
else
    echo "nvm is already installed."
fi
## Clojure
curl -L -o clojure-install.sh https://download.clojure.org/install/linux-install-1.11.3.1429.sh
chmod +x clojure-install.sh
sudo ./clojure-install.sh
rm clojure-install.sh

# --- 3. Python Ecosystem ---
print_header "Step 3: Installing Python Tools (pyenv, Poetry, uv, TheFuck)"
if ! command -v pyenv &> /dev/null; then
    sudo apt-get install -y libbz2-dev libffi-dev libgdbm-dev liblzma-dev libncurses5-dev libreadline-dev libsqlite3-dev libxml2-dev libxmlsec1-dev llvm tk-dev uuid-dev zlib1g-dev
    curl https://pyenv.run | bash
    export PATH="$HOME/.pyenv/bin:$PATH" && eval "$(pyenv init --path)"
    LATEST_PYTHON=$(pyenv install -l | grep -E "^\s*3\.(12|13)\.[0-9]+$" | tail -n 1)
    pyenv install "$LATEST_PYTHON" && pyenv global "$LATEST_PYTHON"
else
    echo "pyenv is already installed."
fi
curl -sSL https://install.python-poetry.org | python3 -
curl -LsSf https://astral.sh/uv/install.sh | sh
pip install qiskit openmm thefuck

# --- 4. DevOps, Cloud & Containers ---
print_header "Step 4: Installing Editors, DevOps, Nix & Cloud Tools"
## Add external repositories
# VS Code
if [ ! -f /etc/apt/sources.list.d/vscode.list ]; then
    curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
fi
# Docker
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list
fi
# Google Cloud
if [ ! -f /etc/apt/sources.list.d/google-cloud-sdk.list ]; then
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
fi
## Final install from repos
sudo apt-get update
sudo apt-get install -y code neovim emacs docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin google-cloud-sdk
sudo usermod -aG docker $USER
## AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip && sudo ./aws/install && rm -rf awscliv2.zip aws/
## Nix Package Manager
if ! command -v nix &> /dev/null; then
    curl -L https://nixos.org/nix/install | sh -s -- --daemon
    # Source nix for the rest of the script
    . /home/$USER/.nix-profile/etc/profile.d/nix.sh
else
    echo "Nix is already installed."
fi

# --- 5. Databases & Data Stores ---
print_header "Step 5: Installing Databases (Postgres, MySQL, Redis, Neo4j)"
## Add external repos
# PostgreSQL
if [ ! -f /etc/apt/sources.list.d/pgdg.list ]; then
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /usr/share/keyrings/postgresql.gpg
    sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
fi
# Neo4j
if [ ! -f /etc/apt/sources.list.d/neo4j.list ]; then
    curl -fsSL https://debian.neo4j.com/neotechnology.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/neo4j.gpg
    echo "deb [signed-by=/usr/share/keyrings/neo4j.gpg] https://debian.neo4j.com stable 5" | sudo tee /etc/apt/sources.list.d/neo4j.list
fi
## Install from repos
sudo apt-get update
sudo apt-get install -y postgresql mysql-server redis-server neo4j

# --- 6. Scientific & Creative Suite ---
print_header "Step 6: Installing Scientific & Creative Tools"
## Scientific
sudo apt-get install -y star minimap2 ncbi-blast+ samtools bedtools sra-toolkit entrez-direct gromacs lammps cp2k
## LaTeX
sudo apt-get install -y texlive-latex-base texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended
## Creative
sudo apt-get install -y gimp inkscape
## 3D Printing (PrusaSlicer AppImage)
mkdir -p "$HOME/.local/bin"
wget "https://github.com/prusa3d/PrusaSlicer/releases/download/version_2.7.4/PrusaSlicer-2.7.4+linux-x64-GTK3-202404051647.AppImage" -O "$HOME/.local/bin/PrusaSlicer.AppImage"
chmod +x "$HOME/.local/bin/PrusaSlicer.AppImage"

# --- 7. AI/ML & Kubernetes ---
print_header "Step 7: Installing Local AI & Kubernetes Tools"
## Kubernetes (kind & kubectl)
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64" && chmod +x ./kind && sudo mv ./kind /usr/local/bin/
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin/
## Reinforcement Learning System Dependencies
sudo apt-get install -y libsdl2-dev libosmesa6-dev patchelf
## Ollama & llama.cpp
curl -fsSL https://ollama.com/install.sh | sh
mkdir -p "$HOME/dev" && git clone https://github.com/ggerganov/llama.cpp.git "$HOME/dev/llama.cpp"
cd "$HOME/dev/llama.cpp"
if command -v nvcc &> /dev/null; then make LLAMA_CUDA=1; else make; fi
cd -

# --- 8. Terminal Modernization ---
print_header "Step 8: Installing Modern Terminal Tools"
## CLI Tools
sudo apt-get install -y bat fd-find ripgrep fastfetch
mkdir -p ~/.local/bin
ln -sf /usr/bin/batcat ~/.local/bin/bat
ln -sf /usr/bin/fdfind ~/.local/bin/fd
sudo mkdir -p /etc/apt/keyrings && wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
sudo apt-get update && sudo apt-get install -y eza
## Zoxide
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
## Oh My Zsh & Plugins
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
## .zshrc Configuration
cat <<'EOF' > "$HOME/.zshrc"
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
# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

# Zoxide
eval "$(zoxide init zsh)"

# TheFuck
eval "$(thefuck --alias)"

# Modern Tool Aliases
alias ls='eza --icons'
alias la='eza -a --icons'
alias ll='eza -l --icons'
alias l='eza -l --icons'
alias cat='bat --paging=never'

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"
EOF
## Nerd Font Download
mkdir -p ~/.local/share/fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip -P ~/.local/share/fonts
unzip -o ~/.local/share/fonts/FiraCode.zip -d ~/.local/share/fonts/FiraCodeNerdFont
rm ~/.local/share/fonts/FiraCode.zip
## Set Zsh as default shell
sudo chsh -s $(which zsh) $USER

# --- 9. GPU Computing (Conditional) ---
print_header "Step 9: Checking for NVIDIA GPU & Installing CUDA"
if command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA GPU detected. Installing CUDA Toolkit and Nsight profilers..."
    wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-wsl-ubuntu.pin
    sudo mv cuda-wsl-ubuntu.pin /etc/apt/preferences.d/cuda-repository-pin-600
    sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/3bf863cc.pub
    echo "deb http://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/ /" | sudo tee /etc/apt/sources.list.d/cuda.list
    sudo apt-get update
    sudo apt-get -y install cuda-toolkit nsight-systems nsight-compute
else
    echo "No NVIDIA GPU detected by nvidia-smi. Skipping CUDA installation."
fi

# --- Final Message ---
print_header "Setup Complete! IMPORTANT NEXT STEPS:"
echo "✅ Zsh is now the default shell. Please CLOSE AND REOPEN YOUR TERMINAL."
echo "✅ When you reopen, the Powerlevel10k configuration wizard will start automatically. Follow its prompts."
echo ""
echo "❗ ACTION REQUIRED 1: CONFIGURE FONT ❗"
echo "   To get icons in your prompt, you MUST install a Nerd Font on your WINDOWS machine."
echo "   1. A recommended font, FiraCode Nerd Font, has been downloaded into WSL for you."
echo "   2. In Windows File Explorer, navigate to the path: \\wsl.localhost\debian\home\$USER\.local\share\fonts\FiraCodeNerdFont"
echo "   3. Right-click on 'Fira Code Regular Nerd Font Complete.ttf' and choose 'Install for all users'."
echo "   4. In Windows Terminal, go to Settings > Profiles > Debian > Appearance and change the 'Font face' to 'FiraCode Nerd Font'."
echo ""
echo "❗ ACTION REQUIRED 2: CONFIGURE TERMINAL THEME ❗"
echo "   To get the Nord Theme with a black background:"
echo "   1. In Windows Terminal Settings, click 'Open JSON file'."
echo "   2. Find the 'schemes' array. Add the Nord color scheme JSON object to it. You can find it by searching for 'Windows Terminal Nord theme'."
echo "   3. In your Debian profile settings (in the JSON file), set 'colorScheme': 'Nord' and 'background': '#000000'."
echo ""
echo "Other Notes:"
echo "- Databases: Services for Postgres, MySQL, Redis, and Neo4j are installed. You may need to run 'sudo mysql_secure_installation'."
echo "- Neovim: Is installed but unconfigured. Look into setting up a config with Lua or starting with 'kickstart.nvim'."
echo "- Nix: To use Nix, you will need to start a new shell session."
