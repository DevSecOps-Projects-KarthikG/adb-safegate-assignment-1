# ADB SAFEGATE – Complete Execution Steps
## End-to-End Command Reference | Tested and Confirmed

**Candidate:** Kartik Gundu  
**Environment:** Ubuntu 22.04 LTS (WSL2 on Windows 11)  
**Cluster:** k3s v1.34.6+k3s1 | Dashboard: v2.7.0 | Docker: 28.2.2 | Trivy: 0.69.3

---

## PART 1 – ENVIRONMENT SETUP

### Step 1.1 – Enable WSL2 on Windows 11

Run in **PowerShell as Administrator** on Windows:

```powershell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
wsl --set-default-version 2
wsl --update
wsl --install -d Ubuntu-22.04
```

If WSL2 service stops between sessions, run this in PowerShell Admin before opening Ubuntu:

```powershell
sc.exe config WslService start= auto
sc.exe start WslService
```

### Step 1.2 – Update Ubuntu

```bash
sudo apt update && sudo apt upgrade -y
```

### Step 1.3 – Verify Ubuntu Version

```bash
cat /etc/os-release | grep -E "NAME|VERSION"
# Ubuntu 22.04 LTS

uname -a
# Linux ... x86_64 GNU/Linux
```

---

## PART 2 – TOOL INSTALLATION + VERSION VERIFICATION

### Step 2.1 – Install Docker

```bash
sudo apt-get install -y docker.io
sudo service docker start

# Verify
docker --version
# Docker version 28.2.2

sudo service docker status
sudo docker run hello-world
```

### Step 2.2 – Install k3s

```bash
curl -sfL https://get.k3s.io | sh -

# Verify
k3s --version
# k3s version v1.34.6+k3s1
```

### Step 2.3 – Install Trivy

```bash
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin

# Verify
trivy --version
# Version: 0.69.3
```

### Step 2.4 – Install Ansible

```bash
sudo apt install ansible -y

# Verify
ansible --version
# ansible 2.10.x
```

### Step 2.5 – Install Lynis

```bash
sudo apt install lynis -y

# Verify
lynis --version
# 3.0.7
```

### Step 2.6 – All Tools Summary Check

```bash
echo "Docker:  $(docker --version)"
echo "k3s:     $(k3s --version | head -1)"
echo "Trivy:   $(trivy --version | head -1)"
echo "Ansible: $(ansible --version | head -1)"
echo "Lynis:   $(lynis --version)"
echo "Python:  $(python3 --version)"
echo "Git:     $(git --version)"
```

---

## PART 3 – TASK 1: KUBERNETES CLUSTER (COMPLETE STEPS)

### Step 3.1 – Start k3s Server

```bash
# Start k3s in background
sudo k3s server --write-kubeconfig-mode=644 > /tmp/k3s.log 2>&1 &

# Wait for k3s to fully start (45 seconds)
echo "Waiting 45 seconds for k3s..."
sleep 45
```

### Step 3.2 – Configure kubeconfig

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config

# Make permanent
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
source ~/.bashrc
```

### Step 3.3 – Verify Cluster Node

```bash
kubectl get nodes
```

Expected output:
```
NAME             STATUS   ROLES           AGE   VERSION
karthik-vostro   Ready    control-plane   Xm    v1.34.6+k3s1
```

### Step 3.4 – Verify All System Pods

```bash
kubectl get pods -A
```

Expected output:
```
NAMESPACE     NAME                                   READY   STATUS
kube-system   coredns-xxx                            1/1     Running
kube-system   metrics-server-xxx                     1/1     Running
kube-system   traefik-xxx                            1/1     Running
kube-system   svclb-traefik-xxx                      2/2     Running
```

### Step 3.5 – k3s Architecture Note (KEY)

> In k3s, `kube-apiserver` and `kube-controller-manager` run as **embedded processes** inside the k3s binary — NOT as separate Kubernetes pods. This is by design.  
> Reference: https://docs.k3s.io/architecture

View control plane logs via:

```bash
# kube-apiserver logs
sudo journalctl -u k3s --no-pager | grep -i "apiserver" | tail -30

# kube-controller-manager logs
sudo journalctl -u k3s --no-pager | grep -i "controller" | tail -30

# kube-scheduler logs
sudo journalctl -u k3s --no-pager | grep -i "scheduler" | tail -30

# All k3s logs
sudo journalctl -u k3s --no-pager | tail -50
```

### Step 3.6 – Deploy Kubernetes Dashboard (GUI Tool)

```bash
# Deploy Dashboard v2.7.0
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Wait for dashboard to be ready
kubectl wait \
  --namespace kubernetes-dashboard \
  --for=condition=ready pod \
  --selector=k8s-app=kubernetes-dashboard \
  --timeout=120s

# Verify dashboard pods
kubectl get pods -n kubernetes-dashboard
```

Expected:
```
NAME                                         READY   STATUS
kubernetes-dashboard-6c7b75ffc-xxxxx         1/1     Running
dashboard-metrics-scraper-5ffb7d645f-xxxxx   1/1     Running
```

### Step 3.7 – Create Admin Service Account

```bash
# From repo
kubectl apply -f k8s-cluster/admin-user.yaml

# Verify
kubectl get serviceaccount admin-user -n kubernetes-dashboard
kubectl get clusterrolebinding admin-user
```

### Step 3.8 – Generate Dashboard Login Token

```bash
kubectl -n kubernetes-dashboard create token admin-user
# Copy the long token string printed — you will paste it in the dashboard
```

### Step 3.9 – Access Dashboard in Browser

**Terminal 1** — start proxy (keep open):

```bash
kubectl proxy --address='0.0.0.0' --accept-hosts='.*'
# Output: Starting to serve on [::]:8001
```

**Browser** — open this URL:

```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

Login: select **Token** → paste token → **Sign In**

**View pod logs in Dashboard:**

```
Left menu → Workloads → Pods
Namespace dropdown → kube-system
Click any pod → Logs icon (top right)
Switch namespace → hello-app → click hello-app pod → Logs
```

### Step 3.10 – Run CIS Kubernetes Benchmark

```bash
# Deploy kube-bench
kubectl apply -f k8s-cluster/kube-bench-job.yaml

# Wait for completion
kubectl wait --for=condition=complete job/kube-bench --timeout=120s

# View results
kubectl logs job/kube-bench

# Summary only
kubectl logs job/kube-bench | grep -E "== Summary|PASS|FAIL|WARN" | tail -20

# Cleanup
kubectl delete job/kube-bench
```

### Step 3.11 – Common kubectl Commands Reference

```bash
# Nodes
kubectl get nodes
kubectl get nodes -o wide
kubectl describe node karthik-vostro

# Pods
kubectl get pods -A
kubectl get pods -n hello-app
kubectl get pods -A -o wide
kubectl describe pod <pod-name> -n hello-app

# Logs
kubectl logs <pod-name> -n hello-app
kubectl logs <pod-name> -n hello-app -f           # follow
kubectl logs <pod-name> -n hello-app --tail=50    # last 50 lines
kubectl logs <pod-name> -n hello-app --previous   # previous container

# Services
kubectl get svc -A
kubectl get svc -n hello-app

# Deployments
kubectl get deployments -A
kubectl describe deployment hello-app -n hello-app

# Namespaces
kubectl get namespaces

# Events (debugging)
kubectl get events -n hello-app --sort-by='.lastTimestamp'

# All resources
kubectl get all -n hello-app

# Cluster info
kubectl cluster-info
```

### Step 3.12 – Exec into Pod

```bash
# Open shell
kubectl exec -it <pod-name> -n hello-app -- /bin/sh

# Run single command
kubectl exec <pod-name> -n hello-app -- id
kubectl exec <pod-name> -n hello-app -- env
kubectl exec <pod-name> -n hello-app -- cat /app/app.py
```

### Step 3.13 – Create Additional Resources (Interview Demos)

#### Create Nginx Pod (3 methods)

```bash
# Method 1: Imperative
kubectl run nginx --image=nginx --port=80
kubectl get pod nginx
kubectl delete pod nginx

# Method 2: With namespace
kubectl run nginx-test --image=nginx --port=80 -n hello-app
kubectl get pods -n hello-app
kubectl delete pod nginx-test -n hello-app

# Method 3: YAML (declarative — best practice)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
    - name: nginx
      image: nginx:latest
      ports:
        - containerPort: 80
EOF

kubectl get pods
kubectl describe pod nginx-pod
kubectl port-forward pod/nginx-pod 8080:80 &
curl http://localhost:8080
kubectl delete pod nginx-pod
```

#### Create Nginx Deployment + Service

```bash
# Create deployment
kubectl create deployment nginx-deploy --image=nginx --replicas=2

# Expose as NodePort service
kubectl expose deployment nginx-deploy \
  --port=80 \
  --target-port=80 \
  --type=NodePort \
  --name=nginx-service

# Check
kubectl get deployment nginx-deploy
kubectl get service nginx-service
kubectl get pods -l app=nginx-deploy

# Scale
kubectl scale deployment nginx-deploy --replicas=3
kubectl get pods -l app=nginx-deploy

# Scale back
kubectl scale deployment nginx-deploy --replicas=1

# Cleanup
kubectl delete deployment nginx-deploy
kubectl delete service nginx-service
```

#### Create ConfigMap and Secret

```bash
# ConfigMap
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=info

kubectl get configmap app-config
kubectl describe configmap app-config

# Secret
kubectl create secret generic app-secret \
  --from-literal=DB_PASSWORD=securepassword

kubectl get secret app-secret
kubectl get secret app-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 --decode

# Cleanup
kubectl delete configmap app-config
kubectl delete secret app-secret
```

#### Scaling Hello App

```bash
kubectl scale deployment hello-app --replicas=3 -n hello-app
kubectl get pods -n hello-app
kubectl scale deployment hello-app --replicas=1 -n hello-app
```

#### Rolling Update + Rollback

```bash
# Rollout history
kubectl rollout history deployment/hello-app -n hello-app

# Check rollout status
kubectl rollout status deployment/hello-app -n hello-app

# Rollback to previous
kubectl rollout undo deployment/hello-app -n hello-app
```

---

## PART 4 – TASK 2: DOCKER + SECURITY (COMPLETE STEPS)

### Step 4.1 – Build the Secure Image

```bash
cd /path/to/adb-safegate-assignment/docker/

sudo docker build -t hello-app:latest .

# View image
sudo docker images | grep hello-app
```

### Step 4.2 – Verify Security (Non-Root UID)

```bash
# Check user running inside container
sudo docker run --rm hello-app:latest id
# Expected: uid=10001(appuser) gid=10001(appgroup) groups=10001(appgroup)

sudo docker run --rm hello-app:latest whoami
# Expected: appuser
```

### Step 4.3 – Run Container Securely

```bash
sudo docker run -d \
  --name hello-world-secure \
  --read-only \
  --tmpfs /tmp \
  -p 5000:5000 \
  hello-app:latest

# Test endpoints
curl http://localhost:5000
# Expected: Hello, World! – ADB SAFEGATE DevOps Engineer Assignment

curl http://localhost:5000/health
# Expected: {"service":"hello-app","status":"ok"}

# Stop and remove
sudo docker stop hello-world-secure
sudo docker rm hello-world-secure
```

### Step 4.4 – Trivy Vulnerability Scan

```bash
# Full scan
sudo trivy image hello-app:latest

# Critical + High only
sudo trivy image --severity CRITICAL,HIGH hello-app:latest

# Ignore unfixed (no upstream patch available)
sudo trivy image --severity CRITICAL,HIGH --ignore-unfixed hello-app:latest

# JSON report
sudo trivy image --format json --output trivy-report.json hello-app:latest

# SBOM generation (CycloneDX)
sudo trivy image --format cyclonedx --output sbom.json hello-app:latest
```

**Confirmed scan results:**

```
CRITICAL:           0
HIGH (OS):          6  — ncurses, systemd — no upstream fix available
HIGH (Python app):  0  — flask==3.1.3 is clean
Python layer:       0 CRITICAL, 0 HIGH
```

**Interview answer for remaining HIGHs:**  
> "All 6 HIGH findings are in debian base OS packages with `status: affected` — no fixed version exists upstream. The Python application layer is completely clean. Flask was upgraded from 3.0.3 to 3.1.3 to fix CVE-2026-27205. These OS findings are monitored and updated when patches release — standard production practice."

### Step 4.5 – Deploy to Kubernetes

```bash
# Load image into k3s (imagePullPolicy: Never uses local image)
sudo docker save hello-app:latest | sudo k3s ctr images import -

# Verify image loaded
sudo k3s ctr images ls | grep hello-app

# Apply all K8s resources
kubectl apply -f deployment.yaml

# Verify
kubectl get pods -n hello-app
kubectl get svc -n hello-app

# Test via NodePort
curl http://localhost:30080
# Expected: Hello, World! – ADB SAFEGATE DevOps Engineer Assignment

curl http://localhost:30080/health
# Expected: {"service":"hello-app","status":"ok"}
```

### Step 4.6 – Verify K8s Security Context

```bash
# Check security context on running pod
kubectl get pod \
  -n hello-app \
  -o jsonpath='{.items[0].spec.securityContext}' | python3 -m json.tool

# Exec and verify UID
kubectl exec -it \
  $(kubectl get pod -n hello-app -o jsonpath='{.items[0].metadata.name}') \
  -n hello-app -- id
# Expected: uid=10001(appuser) gid=10001(appgroup)
```

### Step 4.7 – Port Forward (Alternative Access)

```bash
# Forward pod port to local
kubectl port-forward \
  svc/hello-app-service 8080:80 -n hello-app

curl http://localhost:8080
curl http://localhost:8080/health
```

---

## PART 5 – TASK 3: OS HARDENING (COMPLETE STEPS)

### Step 5.1 – Review Hardening Concept

```bash
cat os-hardening/hardening-concept.md
```

### Step 5.2 – Lynis Compliance Scan (Ubuntu demo)

```bash
sudo apt install lynis -y
lynis --version
# 3.0.7

# Run full audit
sudo lynis audit system

# View hardening index
sudo lynis audit system --quiet | grep "Hardening index"

# View warnings and suggestions
sudo cat /var/log/lynis.log | grep -E "Warning|Suggestion" | head -20
```

### Step 5.3 – Ansible Dry Run

```bash
cd os-hardening/ansible/

# Check inventory
cat inventory

# Dry run — no changes made (check mode)
ansible-playbook -i inventory hardening.yml --check

# Verbose dry run
ansible-playbook -i inventory hardening.yml --check -v

# Run specific sections only
ansible-playbook -i inventory hardening.yml --tags "ssh" --check
ansible-playbook -i inventory hardening.yml --tags "firewall" --check
ansible-playbook -i inventory hardening.yml --tags "selinux" --check
ansible-playbook -i inventory hardening.yml --tags "audit" --check
```

### Step 5.4 – FIPS 140-2 (RHEL 9 — not available on Ubuntu)

```bash
# On RHEL 9 ONLY — these commands do not work on Ubuntu
sudo fips-mode-setup --enable
sudo reboot

# After reboot — verify FIPS is active
fips-mode-setup --check
# Expected: FIPS mode is enabled

cat /proc/sys/crypto/fips_enabled
# Expected: 1

openssl list -providers
# Expected: fips provider listed

# On Ubuntu — command not found (EXPECTED BEHAVIOR)
# fips-mode-setup is a RHEL-specific tool (dracut-fips package)
```

### Step 5.5 – firewalld (RHEL — not Ubuntu)

```bash
# On RHEL 9 ONLY:
sudo systemctl enable --now firewalld
sudo firewall-cmd --set-default-zone=drop
sudo firewall-cmd --permanent --zone=public --add-service=ssh
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
sudo firewall-cmd --state

# NOTE: Ubuntu uses ufw. RHEL uses firewalld exclusively.
# Our hardening concept and Ansible playbook use firewalld (correct for RHEL).
```

### Step 5.6 – SELinux (RHEL)

```bash
# On RHEL 9:
getenforce
# Expected: Enforcing

sestatus

# Check denials
sudo ausearch -m avc -ts recent

# Never disable SELinux — use audit2allow to create permissive rules
```

### Step 5.7 – OpenSCAP CIS Scan (RHEL production)

```bash
# Install OpenSCAP on RHEL
sudo dnf install openscap-scanner scap-security-guide -y

# Run CIS RHEL 9 benchmark
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --results results.xml \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# Generate HTML report
oscap xccdf generate report results.xml > hardening-report.html
```

---

## PART 6 – GITHUB PUSH

### Step 6.1 – Initialize and Push

```bash
cd /path/to/adb-safegate-assignment/

# Initialize git
git init

# Set identity
git config user.name "Kartik Gundu"
git config user.email "karthikgundu001@gmail.com"

# Stage all files
git add .

# Check what will be committed
git status

# Commit
git commit -m "ADB SAFEGATE DevOps Engineer Assignment - Complete Solution"

# Set branch
git branch -M main

# Add remote
git remote add origin https://github.com/KarthikGundu-CloudDevops/adb-safegate-assignment.git

# Push (use Personal Access Token as password)
git push -u origin main
```

> **Note:** GitHub password authentication is disabled. When prompted for password, use a **Personal Access Token**.  
> Generate at: github.com → Settings → Developer settings → Personal access tokens → Classic → select `repo` scope

### Step 6.2 – Add Collaborator @uk1988

```
GitHub → adb-safegate-assignment repo
→ Settings → Collaborators → Add people
→ Search: uk1988 → Add uk1988
```

### Step 6.3 – Update Repo (After Changes)

```bash
git add .
git commit -m "Update: description of changes"
git push origin main
```

---

## PART 7 – FULL DEMO SEQUENCE (Interview Ready)

Run these in order at interview start:

```bash
# 1. Start k3s
sudo k3s server --write-kubeconfig-mode=644 > /tmp/k3s.log 2>&1 &
sleep 45

# 2. Configure kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
export KUBECONFIG=~/.kube/config

# 3. Verify cluster
kubectl get nodes
kubectl get pods -A

# 4. Deploy hello app
kubectl apply -f docker/deployment.yaml
kubectl get pods -n hello-app

# 5. Test app
curl http://localhost:30080
curl http://localhost:30080/health

# 6. Show control plane logs (KEY — embedded process explanation)
sudo journalctl -u k3s --no-pager | grep -i "apiserver" | tail -20
sudo journalctl -u k3s --no-pager | grep -i "controller" | tail -20

# 7. Start dashboard proxy (new terminal)
kubectl proxy --address='0.0.0.0' --accept-hosts='.*'

# 8. Generate token
kubectl -n kubernetes-dashboard create token admin-user

# 9. Open browser → http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

# 10. Trivy scan
sudo trivy image hello-app:latest --severity CRITICAL,HIGH --ignore-unfixed

# 11. Verify non-root in K8s
kubectl exec -it \
  $(kubectl get pod -n hello-app -o jsonpath='{.items[0].metadata.name}') \
  -n hello-app -- id

# 12. Show Lynis compliance
sudo lynis audit system --quiet | grep "Hardening index"
```

---

## PART 8 – TROUBLESHOOTING

### k3s not starting

```bash
# Check if already running
ps aux | grep "k3s server" | grep -v grep

# Check log
tail -30 /tmp/k3s.log

# Port already in use — kill old process
sudo k3s-killall.sh
sleep 10
sudo k3s server --write-kubeconfig-mode=644 > /tmp/k3s.log 2>&1 &
sleep 45
```

### kubectl permission denied

```bash
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
export KUBECONFIG=~/.kube/config
kubectl get nodes
```

### kubectl returns empty

```bash
# KUBECONFIG not set
export KUBECONFIG=~/.kube/config
kubectl get nodes

# Or use sudo
sudo kubectl get nodes
```

### D: drive not mounted (WSL2)

```bash
sudo mkdir -p /mnt/d
sudo mount -t drvfs D: /mnt/d
ls /mnt/d/
```

### Dashboard token expired

```bash
# Generate new token (valid 1 hour)
kubectl -n kubernetes-dashboard create token admin-user

# Generate with 8 hour expiry
kubectl -n kubernetes-dashboard create token admin-user --duration=8h
```
