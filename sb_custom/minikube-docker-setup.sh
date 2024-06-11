#!/bin/bash

if [ $(lsb_release -is) = "Ubuntu" ]
then
    echo "Running on Ubuntu $(lsb_release -rs)"
else
    echo "I'm sorry, this script is made only for Ubuntu (confirmed on version 22)"
fi

### installing Docker
sudo apt-get update -y
sudo apt-get install ca-certificates curl gnupg lsb-release -y
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

sudo usermod -aG docker $USER
newgrp docker

### installing kubectl
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

### installing minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
sudo dpkg -i minikube_latest_amd64.deb

### installing Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod +x ./get_helm.sh
./get_helm.sh


# Modify inotify limits
sudo tee /etc/sysctl.d/55-custom-inotify.conf > /dev/null <<EOT
fs.inotify.max_user_instances = 1024
fs.inotify.max_user_watches = 1048576
EOT
sudo sysctl -p /etc/sysctl.d/55-custom-inotify.conf

rm -f minikube_latest_amd64.deb get_helm.sh

echo "Enabling bash autocompletion for new commands (ready to use in new shell)."
cat >> ~/.bashrc <<EOT

# Autocompletion for kubectl and friends
source <(kubectl completion bash)
source <(minikube completion bash)
source <(helm completion bash)
EOT

