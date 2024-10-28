
#!/bin/bash

# Initialize HA Kubernetes Control Plane Nodes
sudo kubeadm init --control-plane-endpoint "<LOAD_BALANCER_IP>:6443" --upload-certs

# For additional control-plane nodes, join with certificates
sudo kubeadm join <LOAD_BALANCER_IP>:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH> \
  --control-plane --certificate-key <CERT_KEY>
