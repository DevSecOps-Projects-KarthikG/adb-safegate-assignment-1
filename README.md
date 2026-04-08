# ADB SAFEGATE – DevOps Engineer Homework Assignment

**Candidate:** Kartik Gundu  
**GitHub:** [KarthikGundu-CloudDevops](https://github.com/KarthikGundu-CloudDevops)  
**Role:** DevOps Engineer  
**Submitted:** April 2026  

---

## Assignment Overview

| Task | Description | Folder |
|------|-------------|--------|
| 1 | Single-node Kubernetes cluster + GUI Dashboard | `k8s-cluster/` |
| 2 | Secure Python Hello World – Dockerfile | `docker/` |
| 3 | OS Hardening Concept – RHEL 9 + CIS + FIPS | `os-hardening/` |

---

## Repository Structure

```
adb-safegate-assignment/
├── README.md                          ← This file
├── k8s-cluster/
│   ├── install-k3s.sh                 ← Automated k3s setup script
│   ├── admin-user.yaml                ← Dashboard ServiceAccount + RBAC
│   ├── kube-bench-job.yaml            ← CIS K8s benchmark scanner
│   └── README.md                      ← Step-by-step setup guide
├── docker/
│   ├── Dockerfile                     ← Multi-stage secure Python container
│   ├── app.py                         ← Flask Hello World + /health endpoint
│   ├── requirements.txt               ← Pinned deps (flask==3.1.3)
│   ├── deployment.yaml                ← K8s Deployment + Service + NetworkPolicy
│   └── README.md                      ← Build, scan, deploy guide
└── os-hardening/
    ├── hardening-concept.md           ← RHEL 9 CIS L1+L2 + FIPS 140-2 concept
    └── ansible/
        ├── hardening.yml              ← Ansible automation playbook
        └── inventory                  ← Target host inventory template
```

---

## Environment (Tested and Confirmed)

| Component | Version | Reference |
|-----------|---------|-----------|
| OS | Ubuntu 22.04 LTS (WSL2) | https://ubuntu.com/download/server |
| k3s | v1.34.6+k3s1 | https://docs.k3s.io/quick-start |
| Kubernetes Dashboard | v2.7.0 | https://github.com/kubernetes/dashboard/tree/v2.7.0 |
| Docker | 28.2.2 | https://docs.docker.com/engine/install/ubuntu/ |
| Trivy | 0.69.3 | https://aquasecurity.github.io/trivy/latest/getting-started/installation/ |
| Python base image | 3.11-slim | https://hub.docker.com/_/python |
| Flask | 3.1.3 | https://flask.palletsprojects.com/ |

---

## How to Replicate – Step by Step

### Prerequisites – WSL2 on Windows

```powershell
# Run in PowerShell as Administrator on Windows
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
wsl --set-default-version 2
wsl --update
wsl --install -d Ubuntu-22.04
```

Then inside Ubuntu:

```bash
sudo apt update && sudo apt upgrade -y
```

---

### Task 1 – Kubernetes Cluster

```bash
# Clone repository
git clone https://github.com/KarthikGundu-CloudDevops/adb-safegate-assignment.git
cd adb-safegate-assignment

# Run automated setup script
chmod +x k8s-cluster/install-k3s.sh
sudo bash k8s-cluster/install-k3s.sh

# Configure kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
export KUBECONFIG=~/.kube/config

# Verify cluster
sudo kubectl get nodes
sudo kubectl get pods -A
```

**Access Kubernetes Dashboard (GUI):**

```bash
# Start proxy – keep this terminal open
sudo kubectl proxy --address='0.0.0.0' --accept-hosts='.*'
```

Open browser:
```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

Get login token:
```bash
sudo kubectl -n kubernetes-dashboard create token admin-user
```

**k3s Architecture Note:**  
In k3s, `kube-apiserver` and `kube-controller-manager` run as **embedded processes** within the k3s binary — not as separate Kubernetes pods. This is by design in k3s.  
Reference: https://docs.k3s.io/architecture  

View control plane logs:
```bash
sudo journalctl -u k3s --no-pager | grep -i "apiserver" | tail -30
sudo journalctl -u k3s --no-pager | grep -i "controller" | tail -30
```

---

### Task 2 – Docker Build + Security Scan + Deploy

```bash
cd docker/

# Install Docker
sudo apt-get install -y docker.io
sudo service docker start

# Build image
sudo docker build -t hello-app:latest .

# Verify non-root (expected: uid=10001)
sudo docker run --rm hello-app:latest id

# Run securely
sudo docker run -d --read-only --tmpfs /tmp -p 5000:5000 --name hello-world-secure hello-app:latest

# Test
curl http://localhost:5000
curl http://localhost:5000/health

# Install Trivy and scan
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
sudo trivy image hello-app:latest

# Deploy to Kubernetes
sudo docker save hello-app:latest | sudo k3s ctr images import -
sudo kubectl apply -f deployment.yaml
sudo kubectl get pods -n hello-app
sudo kubectl get svc -n hello-app
curl http://localhost:30080
curl http://localhost:30080/health
```

---

### Task 3 – OS Hardening

```bash
# Review the hardening concept
cat os-hardening/hardening-concept.md

# Run Ansible playbook (dry run – requires RHEL target host)
cd os-hardening/ansible/
ansible-playbook -i inventory hardening.yml --check

# Compliance scan on Ubuntu (for demo)
sudo apt install lynis -y
sudo lynis audit system

# Compliance scan on RHEL (production)
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --results results.xml \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml
```

---

## Security Summary

| Layer | Controls Applied |
|-------|-----------------|
| Container | Multi-stage build, non-root UID 10001, Trivy scanned (0 CRITICAL) |
| Kubernetes | RBAC, securityContext, NetworkPolicy, readOnlyRootFilesystem, drop ALL caps |
| OS | CIS RHEL 9 L1+L2, FIPS 140-2, SELinux enforcing, auditd, firewalld |
| Pipeline | SAST, SCA, DAST, SBOM awareness |

---

## Official References

| Tool | Reference |
|------|-----------|
| k3s | https://docs.k3s.io/quick-start |
| k3s Architecture | https://docs.k3s.io/architecture |
| Kubernetes Dashboard | https://github.com/kubernetes/dashboard/tree/v2.7.0 |
| Dashboard Access Control | https://github.com/kubernetes/dashboard/blob/v2.7.0/docs/user/access-control/creating-sample-user.md |
| Trivy | https://aquasecurity.github.io/trivy/latest/getting-started/installation/ |
| Docker Security | https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html |
| K8s securityContext | https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ |
| K8s NetworkPolicy | https://kubernetes.io/docs/concepts/services-networking/network-policies/ |
| CIS RHEL 9 Benchmark | https://www.cisecurity.org/benchmark/red_hat_linux |
| FIPS 140-2 | https://csrc.nist.gov/publications/detail/fips/140/2/final |
| RHEL Security Hardening | https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/security_hardening/ |
| OpenSCAP | https://www.open-scap.org/ |
| Ansible RHEL9-CIS | https://github.com/ansible-lockdown/RHEL9-CIS |
| kube-bench | https://github.com/aquasecurity/kube-bench |
