#!/bin/bash
# This script installs the Helix armv6 binary and runtime on a target device.
# Requirements: pigz, ssh, and rsync must be installed on the local machine.

clear && \

# ASCII Art Banner
cat << "EOF"

###x.        .|
d#####x,   ,v||
 '+#####v||||||
    ,v|||||+'.      _     _           _
 ,v|||||^'>####    | |   | |   ___   | | (_) __  __
|||||^'  .v####    | |___| |  /   \  | |  _  \ \/ /
||||=..v#####P'    |  ___  | /  ^  | | | | |  \  /
''v'>#####P'       | |   | | |  ---  | | | |  /  \
,######/P||x.      |_|   |_|  \___/  |_| |_| /_/\_\
####P' "x|||||,
|/'       'x|||    A post-modern modal text editor.
 '           '|

EOF

echo "*=====================*"
echo "| Helix ARMv6 Builder |"
echo "*=====================*"

# Prompt user to continue or quit
read -n 1 -s -r -p "Press any key to continue or press q to quit..." key
echo
if [[ $key == "q" ]]; then
    echo "Exiting script..."
    exit 0
fi

# Get required information
read -p "Enter number of threads to use for compression: " THREADS
read -p "Enter the IP address of the target device: " DEVICE_IP
read -p "Enter your username on the target device: " USER_NAME

# Define cleanup functions
cleanup_local() {
    echo "Cleaning up local temporary files..."
    if [ -f runtime.tar.gz ]; then
        rm -f runtime.tar.gz
    fi
    if [ -n "$SSH_AGENT_PID" ]; then
        ssh-agent -k
    fi
}

cleanup_remote() {
    echo "Cleaning up remote temporary files..."
    ssh -o ControlPath=$SSH_CONTROL_PATH ${USER_NAME}@${DEVICE_IP} "rm -f ~/runtime.tar.gz" 2>/dev/null
}

# Set cleanup trap
trap 'cleanup_local; cleanup_remote' EXIT

# Set up SSH multiplexing
SSH_CONTROL_PATH="/tmp/ssh-helix-install-%r@%h:%p"
ssh -o ControlMaster=yes -o ControlPath=$SSH_CONTROL_PATH -o ControlPersist=yes ${USER_NAME}@${DEVICE_IP} true

# Check for required local packages
echo "Checking for required local packages..."
for pkg in pigz ssh rsync; do
    if ! command -v $pkg &> /dev/null; then
        echo "Error: $pkg is not installed on local machine"
        exit 1
    fi
done

# Compress runtime directory
echo "Compressing runtime directory..."
tar --exclude runtime/grammars/sources -cvf - runtime | pigz -p ${THREADS} -v > runtime.tar.gz

# Perform installation
echo "Installing Helix..."
{
    # Copy files using the same SSH connection
    rsync -avz --progress -e "ssh -o ControlPath=$SSH_CONTROL_PATH" \
        target/arm-unknown-linux-gnueabi/opt/hx \
        runtime.tar.gz \
        ${USER_NAME}@${DEVICE_IP}:~ &&

    # Execute all installation commands in a single SSH session
    ssh -o ControlPath=$SSH_CONTROL_PATH ${USER_NAME}@${DEVICE_IP} "
        # 1. Create required directories
        sudo mkdir -p /usr/local/lib/helix &&
        sudo mkdir -p -v /home/neil/.config/helix/runtime &&

        # 2. Install binary and set permissions
        sudo mv ~/hx /usr/local/bin/ &&
        sudo chmod -v 755 /usr/local/bin/hx &&

        # 3. Install runtime files and set permissions
        sudo tar xvzf ~/runtime.tar.gz -C /usr/local/lib/helix/ &&
        sudo chmod -v -R 755 /usr/local/lib/helix &&
        sudo chown -v -R root:root /usr/local/lib/helix &&

        # 4. Configure environment variables
        sudo sed -i '/^HELIX_RUNTIME=/d' /etc/environment &&
        sudo sed -i '/^COLORTERM=/d' /etc/environment &&
        echo 'HELIX_RUNTIME=/usr/local/lib/helix/runtime' | sudo tee -a /etc/environment &&
        echo 'COLORTERM=truecolor' | sudo tee -a /etc/environment
    "
} && {
    echo ""
    echo "Installation complete!"
} || {
    echo ""
    echo "Installation failed!"
}

# Close SSH control connection
ssh -O exit -o ControlPath=$SSH_CONTROL_PATH ${USER_NAME}@${DEVICE_IP}
