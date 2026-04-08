#!/bin/bash
# =============================================================================
# ADB SAFEGATE – k3s Single-Node Kubernetes Cluster Setup Script
# =============================================================================
# Description  : Installs k3s and deploys Kubernetes Dashboard (GUI)
# Tested On    : Ubuntu 22.04 LTS (WSL2 on Windows 11) – Confirmed working
# k3s Version  : v1.34.6+k3s1 (stable channel – installed April 2026)
# Dashboard    : v2.7.0
# Author       : Kartik Gundu
# Reference    : https://docs.k3s.io/quick-start
#                https://github.com/kubernetes/dashboard/tree/v2.7.0
#
# ARCHITECTURE NOTE:
# In k3s, kube-apiserver and kube-controller-manager run as embedded processes
# within the k3s binary – NOT as separate Kubernetes pods.
# Reference: https://docs.k3s.io/architecture
# Their logs are available via: sudo journalctl -u k3s
# =============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo -e "${BLUE}"
echo "========================================================"
echo "  ADB SAFEGATE – k3s Cluster Setup"
echo "  Ubuntu 22.04 LTS / WSL2"
echo "========================================================"
echo -e "${NC}"

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && err "Please run as root: sudo bash install-k3s.sh"
command -v curl &>/dev/null || apt-get install -y curl

# ── Step 1: Install k3s ───────────────────────────────────────────────────────
log "Step 1/6 – Installing k3s (stable channel)..."
log "Reference: https://docs.k3s.io/quick-start"
curl -sfL https://get.k3s.io | sh -
sleep 15

# ── Step 2: Configure kubeconfig ──────────────────────────────────────────────
log "Step 2/6 – Configuring kubeconfig..."
KUBE_USER=${SUDO_USER:-$(logname 2>/dev/null || echo "karthik")}
HOME_DIR=$(eval echo ~"$KUBE_USER")

mkdir -p "$HOME_DIR/.kube"
cp /etc/rancher/k3s/k3s.yaml "$HOME_DIR/.kube/config"
chown "$KUBE_USER:$KUBE_USER" "$HOME_DIR/.kube/config"
chmod 600 "$HOME_DIR/.kube/config"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

log "Verifying cluster node status..."
kubectl get nodes

# ── Step 3: Verify System Pods ────────────────────────────────────────────────
# NOTE: In k3s, kube-apiserver and kube-controller-manager run as embedded
# processes within the k3s binary – NOT as separate Kubernetes pods.
# This is by design. Reference: https://docs.k3s.io/architecture
# To view control plane logs use:
#   sudo journalctl -u k3s --no-pager | grep -i "apiserver" | tail -30
#   sudo journalctl -u k3s --no-pager | grep -i "controller" | tail -30
log "Step 3/6 – Verifying k3s system pods..."
sleep 10
kubectl get pods -n kube-system

# ── Step 4: Deploy Kubernetes Dashboard ───────────────────────────────────────
log "Step 4/6 – Deploying Kubernetes Dashboard v2.7.0..."
log "Reference: https://github.com/kubernetes/dashboard/tree/v2.7.0"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

log "Waiting for dashboard pod to be ready (up to 120s)..."
kubectl wait --namespace kubernetes-dashboard \
  --for=condition=ready pod \
  --selector=k8s-app=kubernetes-dashboard \
  --timeout=120s

# ── Step 5: Create Admin User ─────────────────────────────────────────────────
log "Step 5/6 – Creating admin service account..."
log "Reference: https://github.com/kubernetes/dashboard/blob/v2.7.0/docs/user/access-control/creating-sample-user.md"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/admin-user.yaml"

# ── Step 6: Generate Access Token ─────────────────────────────────────────────
log "Step 6/6 – Generating dashboard login token..."
sleep 5
echo ""
echo -e "${YELLOW}========================================================"
echo "  DASHBOARD ACCESS TOKEN (copy to log in):"
echo "========================================================"
echo -e "${NC}"
kubectl -n kubernetes-dashboard create token admin-user
echo ""

# ── Instructions ──────────────────────────────────────────────────────────────
echo -e "${GREEN}"
echo "========================================================"
echo "  SETUP COMPLETE – How to Access the Dashboard"
echo "========================================================"
echo ""
echo "  1. Open a NEW terminal and run:"
echo "     export KUBECONFIG=~/.kube/config"
echo "     sudo kubectl proxy --address='0.0.0.0' --accept-hosts='.*'"
echo ""
echo "  2. Open browser and go to:"
echo "     http://localhost:8001/api/v1/namespaces/kubernetes-dashboard"
echo "     /services/https:kubernetes-dashboard:/proxy/"
echo ""
echo "  3. Select Token, paste the token printed above, click Sign In"
echo ""
echo "  4. Control plane logs (k3s runs apiserver as embedded process):"
echo "     sudo journalctl -u k3s --no-pager | grep -i apiserver | tail -30"
echo "     sudo journalctl -u k3s --no-pager | grep -i controller | tail -30"
echo ""
echo "  5. Pod logs in Dashboard GUI:"
echo "     Workloads -> Pods -> Namespace: kube-system -> click pod -> Logs"
echo ""
echo "========================================================"
echo -e "${NC}"
