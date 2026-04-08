# Task 3 – Operating System Hardening Concept

**Target OS:** Red Hat Enterprise Linux (RHEL) 9  
**Standard:** CIS Benchmark – RHEL 9 Level 1 & Level 2  
**Additional:** FIPS 140-2 Cryptographic Compliance  
**Approach:** Defence-in-Depth | Least Privilege | Minimal Attack Surface  

**References:**  
- https://www.cisecurity.org/benchmark/red_hat_linux  
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/security_hardening/  
- https://csrc.nist.gov/publications/detail/fips/140/2/final  

---

## 1. Objective

Define a structured, repeatable hardening process for RHEL-based operating system images used in ADB SAFEGATE environments — covering on-premises physical servers, virtual machines, and Kubernetes node hosts.

The goal is to reduce the attack surface, enforce compliance, and establish a baseline that can be audited, automated, and consistently reproduced across all deployments.

---

## 2. Defence-in-Depth Model

```
Physical/Cloud Layer   → Controlled physical and network access
OS Layer               → Hardened base image
Identity & Access      → Least privilege, MFA, SSH key-only
Network Layer          → firewalld, minimal open ports
Cryptography Layer     → FIPS 140-2 validated modules
Application Layer      → Secure configs, patching
Monitoring & Response  → auditd, AIDE, centralized logging
```

Hardening is not a one-time step — it is a **continuous process** applied at:
- Image build time (baseline)
- Deployment time (environment-specific config)
- Runtime (monitoring and patching)

---

## 3. FIPS 140-2 Cryptographic Compliance

### What is FIPS 140-2?

FIPS (Federal Information Processing Standard) 140-2 is a U.S. government security standard defining requirements for cryptographic modules. It ensures only validated, approved cryptographic algorithms are used across the system.

Reference: https://csrc.nist.gov/publications/detail/fips/140/2/final

### What FIPS 140-2 Enforces on RHEL

| Area | Change When FIPS Enabled |
|------|--------------------------|
| OpenSSL | Restricts to FIPS-validated cipher suites only |
| Blocked algorithms | MD5, RC4, DES, 3DES, SHA-1 (for signing) |
| Allowed algorithms | AES-128/256, SHA-256/384/512, RSA-2048+, ECDSA |
| TLS | Minimum TLS 1.2, TLS 1.3 preferred |
| SSH | Only FIPS-approved key exchange and MAC algorithms |
| Kernel | Uses FIPS-validated crypto modules |

### Why This Matters for ADB SAFEGATE

Airport systems connect to government-regulated networks and must meet compliance requirements. FIPS ensures all cryptographic operations use validated modules — critical for aviation security environments.

### Enabling FIPS Mode on RHEL 9

```bash
# Reference: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/security_hardening/assembly_installing-a-rhel-9-system-with-fips-mode-enabled_security-hardening

# Enable FIPS mode (requires reboot)
sudo fips-mode-setup --enable

# Reboot to activate
sudo reboot

# Verify after reboot
fips-mode-setup --check
# Expected: FIPS mode is enabled

# Verify kernel FIPS parameter
cat /proc/sys/crypto/fips_enabled
# Expected: 1

# Verify OpenSSL uses FIPS provider
openssl list -providers
```

### FIPS-Aligned SSH Configuration

```bash
# /etc/ssh/sshd_config – FIPS-compliant ciphers and MACs
Ciphers aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-256,hmac-sha2-512,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com
KexAlgorithms ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group14-sha256
```

---

## 4. Hardening Areas

### 4.1 Minimal OS Installation

**Principle:** Every package is a potential vulnerability. Install only what is required.

```bash
# Start from RHEL 9 Minimal Install – no GUI, no unnecessary services
dnf remove telnet rsh ypbind talk ntalk

# Disable unused filesystems
cat > /etc/modprobe.d/unused-filesystems.conf << EOF
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install udf /bin/true
EOF
```

**CIS Reference:** Section 1 – Initial Setup

---

### 4.2 Filesystem Hardening

| Mount Point | Options | Purpose |
|-------------|---------|---------|
| `/tmp` | `nodev,nosuid,noexec` | Prevent script execution in temp |
| `/var/tmp` | `nodev,nosuid,noexec` | Same as /tmp |
| `/home` | `nodev` | Prevent device files |
| `/dev/shm` | `nodev,nosuid,noexec` | Secure shared memory |

```bash
# /etc/fstab entry for /tmp
tmpfs /tmp tmpfs defaults,rw,nosuid,nodev,noexec,relatime 0 0

# Enable sticky bit on world-writable directories
df --local -P | awk '{if (NR!=1) print $6}' | \
  xargs -I '{}' find '{}' -xdev -type d -perm -0002 2>/dev/null | \
  xargs chmod a+t
```

**CIS Reference:** Section 1.1 – Filesystem Configuration

---

### 4.3 User and Access Control

```bash
# /etc/ssh/sshd_config – Full hardened SSH config
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 4
LoginGraceTime 60
IgnoreRhosts yes
HostbasedAuthentication no
PermitEmptyPasswords no
X11Forwarding no
AllowTcpForwarding no
ClientAliveInterval 300
ClientAliveCountMax 0
Banner /etc/issue.net

# Password policy – /etc/security/pwquality.conf
minlen = 14
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
maxrepeat = 3

# Account lockout – /etc/pam.d/system-auth
auth required pam_faillock.so preauth audit silent deny=5 unlock_time=900

# Sudo logging – /etc/sudoers.d/hardening
Defaults logfile="/var/log/sudo.log"
Defaults log_input, log_output
Defaults use_pty
```

**CIS Reference:** Section 5 – Access, Authentication and Authorization

---

### 4.4 Network Hardening

**Important:** RHEL uses `firewalld` — NOT `ufw` (which is Ubuntu only).

```bash
# Enable firewalld
systemctl enable --now firewalld

# Set default zone to drop (deny all inbound by default)
firewall-cmd --set-default-zone=drop

# Allow only required services
firewall-cmd --permanent --zone=public --add-service=ssh
firewall-cmd --reload
firewall-cmd --list-all

# Kernel network security – /etc/sysctl.d/60-hardening.conf
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv6.conf.all.disable_ipv6 = 1

sysctl --system

# Disable unused network protocols
cat > /etc/modprobe.d/unused-protocols.conf << EOF
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
EOF
```

**CIS Reference:** Section 3 – Network Configuration

---

### 4.5 Service Hardening

```bash
# Disable unnecessary services
systemctl disable --now avahi-daemon cups rpcbind nfs-server \
  vsftpd httpd dovecot samba squid ypserv
```

**CIS Reference:** Section 2 – Services

---

### 4.6 Patch Management

```bash
# Apply all updates
dnf update -y

# Enable automatic security updates
dnf install dnf-automatic -y

# /etc/dnf/automatic.conf
# upgrade_type = security
# apply_updates = yes

systemctl enable --now dnf-automatic.timer
```

---

### 4.7 SELinux Enforcement

```bash
# Verify enforcing mode
getenforce
# Expected: Enforcing

# /etc/selinux/config
SELINUX=enforcing
SELINUXTYPE=targeted

# NEVER disable SELinux in production
# Check denials
ausearch -m avc -ts recent
```

**CIS Reference:** Section 1.6 – SELinux

---

### 4.8 Audit and Logging

```bash
systemctl enable --now auditd

# /etc/audit/rules.d/hardening.rules
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k sudoers
-w /var/log/lastlog -p wa -k logins
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=1000 -k privileged
-a always,exit -F arch=b64 -S connect -k network_connect
-e 2
```

---

### 4.9 File Integrity Monitoring (AIDE)

```bash
dnf install aide -y
aide --init
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
echo "0 5 * * * root /usr/sbin/aide --check" >> /etc/crontab
```

---

## 5. Automation

### Option A – Ansible (Recommended for scale)

```bash
# Reference: https://github.com/ansible-lockdown/RHEL9-CIS
ansible-galaxy install ansible-lockdown.RHEL9-CIS
ansible-playbook -i inventory hardening.yml --check  # dry run
ansible-playbook -i inventory hardening.yml           # apply
```

### Option B – Packer (Golden images)

Build a hardened base image used for all deployments — every server starts from a known-good, FIPS-compliant state.

### Option C – OpenSCAP (Compliance scanning)

```bash
# Reference: https://www.open-scap.org/
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --results results.xml \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# Generate HTML report
oscap xccdf generate report results.xml > hardening-report.html
```

---

## 6. CIS Compliance Summary

| CIS Section | Area | Level | Status |
|-------------|------|-------|--------|
| 1.1 | Filesystem configuration | L1 | Covered |
| 1.6 | SELinux | L1 | Covered |
| 2 | Service hardening | L1 | Covered |
| 3 | Network configuration | L1 | Covered |
| 4 | Logging and auditing | L2 | Covered |
| 5 | Access control | L1 | Covered |
| 6 | System maintenance | L1 | Covered |
| – | FIPS 140-2 | Crypto | Covered |

---

## 7. Hardening Process Flow

```
Minimal RHEL Install
      │
      ▼
Enable FIPS Mode → fips-mode-setup --enable → reboot
      │
      ▼
Apply CIS Baseline → packages, filesystem, network (firewalld)
      │
      ▼
Identity & Access → SSH hardening, PAM, sudo
      │
      ▼
Monitoring → auditd, AIDE, centralized logging
      │
      ▼
Compliance Scan → OpenSCAP CIS profile
      │
      ▼
Approved Golden Image → deployed to all environments
```

---

## 8. Key Principles

1. **FIPS 140-2** – cryptographic compliance at kernel and OpenSSL level
2. **Minimal footprint** – less software = smaller attack surface
3. **Least privilege** – every account gets only what it needs
4. **SELinux enforcing** – mandatory access control at OS level
5. **firewalld not ufw** – RHEL uses firewalld (ufw is Ubuntu only)
6. **Audit everything** – logs are your forensic trail
7. **Automate** – Ansible and Packer ensure repeatability at scale
8. **Scan and verify** – OpenSCAP measures compliance continuously

---

## References

- [CIS RHEL 9 Benchmark](https://www.cisecurity.org/benchmark/red_hat_linux)
- [FIPS 140-2 Standard](https://csrc.nist.gov/publications/detail/fips/140/2/final)
- [RHEL 9 Security Hardening Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/security_hardening/)
- [RHEL FIPS Mode Setup](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/security_hardening/assembly_installing-a-rhel-9-system-with-fips-mode-enabled_security-hardening)
- [OpenSCAP](https://www.open-scap.org/)
- [Ansible RHEL9-CIS Role](https://github.com/ansible-lockdown/RHEL9-CIS)
- [NIST SP 800-123](https://csrc.nist.gov/publications/detail/sp/800-123/final)
