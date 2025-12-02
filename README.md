# Core Systems IaC: Okta + AWS EC2 CI/CD Pipeline

This repository contains an infrastructure-as-code and CI/CD design for managing:

- An **Okta instance** (groups, apps, and policies)  
- An **AWS EC2 “server set”** (networking + instances)

using a **GitOps-style** workflow. All changes are made via pull requests, validated in CI, and then applied to environments through an automated pipeline.

---

## 1. Goals

The design aims to:

1. Treat both **identity** (Okta) and **compute** (AWS EC2) as **code**.
2. Use **Git as the source of truth** for configuration.
3. Provide a **safe, auditable change process**:
   - Plan → review → apply  
   - Separate dev and prod(TODO) environments
   - Stricter controls for Okta (higher blast radius)
4. **small but realistic** solution for a corporate infrastructure context.

---

## 2. High-Level Overview

At a high level:

- Okta and AWS resources are defined in **Terraform**.
- When a change is opened as a **pull request**:
  - CI runs `terraform fmt` and `terraform validate`.
  - CI runs **plans** for:
    - Okta (dev tenant)
    - AWS (dev environment)
- Once the PR is reviewed and merged into `main`:
  - CI automatically **applies** changes to **dev** (Okta + AWS).
- Ideally promotion to **production** is done via **manual CI jobs**:
  - Separate jobs for Okta prod and AWS prod.
  - Okta prod requires manual intent because identity changes could be more sensitive.

---

## 3. CI/CD topology

![flowchart1](misc/flowchart1.png)


## AWS Infrastructure Overview

### 1. VPC – Private Network Boundary

- A dedicated **VPC** is created for this stack.
- No resources use the **default VPC**.
- This provides:
  - A clean routing and security boundary
  - Separation for future expansion (more subnets, services, environments)

---

### 2. Subnets – Public & Private

Inside the VPC, two subnets are defined:

- **Public subnet**
  - CIDR: `10.0.1.0/24`
  - Hosts the internet-facing EC2 instance

- **Private subnet**
  - CIDR: `10.0.2.0/24`
  - Reserved for internal services (e.g., databases, app services) if the stack is extended

---

### 3. Internet Access – Internet Gateway & Route Table

To allow the public subnet to reach the internet:

- **Internet Gateway (IGW)** is created and attached to the VPC.
- **Route table** for the VPC includes:
  - Default route: `0.0.0.0/0` → Internet Gateway
- The route table is **associated with the public subnet** only.

Result:  
Instances in the public subnet can reach the internet; private subnet stays isolated unless additional routing/NAT is added.

---

### 4. Security Group – Web Instance Firewall

A dedicated **security group** is defined for the EC2 instance:

- **Attached to:** same VPC

**Ingress rules:**

- HTTP: port `80` from `0.0.0.0/0`
- HTTPS: port `443` from `0.0.0.0/0`
- SSH: port `22` from `0.0.0.0/0` (demo-friendly; would be tightened in real use)

**Egress rule:**

- All outbound traffic allowed

Notes for real environments:

- Restrict SSH to:
  - A bastion host, or
  - Known IP ranges, or
  - Use SSM Session Manager instead of exposing port 22 to the world

---

### 5. EC2 Instance – Web Server

With networking and security in place, the EC2 instance is defined:

- **AMI:** Amazon Linux 2
- **Instance type:** `t3.micro` (small, cost-effective)
- **Placement:**
  - In the public subnet
  - Associated with the web security group

Terraform handles dependencies so the instance is created only after the VPC, subnets, IGW, route tables, and security groups exist.

In a real environment, additional configuration could be layered via:

- User data scripts
- Ansible
- SSM (Systems Manager) for config, agents, and application deployment

---

### 6. S3 Bucket – Terraform Remote State & Shared Infra

An **S3 bucket** is created to store the **Terraform remote state**.

This also demonstrates how shared infrastructure can be provisioned, such as:

- State buckets
- Logs
- Configuration storage

---

## Okta Configuration Overview

The Okta side focuses on:

- A high-security user cohort
- A baseline “Everyone” cohort
- App-specific authentication policies with different MFA/session behavior
- An OAuth web app bound to these policies

Everything is managed by Terraform and runs through the same CI/CD pipeline.

---

### 1. Okta Provider Configuration

Terraform is configured to talk to Okta via the Okta provider:

- **Variables:**
  - `org_name` – Okta org (e.g., `mycompany`)
  - `api_token` – API token (injected via variables/CI secrets)
  - `base_url` – Okta base domain (e.g., `okta.com`, `okta-emea.com`)

This lets Terraform manage Okta resources declaratively in the same workflow as AWS.

---

### 2. Baseline Cohort – Built-in “Everyone” Group

The built-in **Everyone** group is referenced via a **data source**:

- Terraform **does not create** this group; it already exists in the org.
- The name (from `var.everyone_group_name`) is used to look up its ID.

This group acts as the **baseline cohort**:

- All users fall back to this unless they are in a more restrictive group.
- Used later as the general policy target for the app’s MFA/session rules.

---

### 3. High-Security Cohort – Restricted Users Group

A dedicated high-security group is created, for example:

- **Name:** `restricted_users`
- **Description:** Users who require stricter MFA for a particular app

Typical examples:

- Admins
- Users accessing sensitive internal systems

Anyone added to this group automatically receives a **tighter** security posture for the app.

---

### 4. App-Specific Sign-On Policy

Instead of relying only on global org policies, an **app-level sign-on policy** is created:

- **Scope:** A single OAuth web application
- **Flag:** `catch_all = true` so it acts as the default policy for that app

Benefits:

- Policies can be tuned specifically for this app
- Changes here don’t affect all other apps in the org

---

### 5. Policy Rules – Different Behavior per Cohort

Within the app-specific policy, two rules are defined with different priorities.

#### Rule 1 – Restricted Users (Priority 1)

- **Target:** `restricted_users` group
- **Access:** `ALLOW`
- **factor_mode:** `"2FA"` → MFA always required
- **Re-auth / session settings:**
  - Short re-auth interval (e.g., every 2 hours)
  - Short inactivity timeout (e.g., 30 minutes)

**Effect:**  
High-risk users get stricter MFA and shorter sessions.

---

#### Rule 2 – Everyone (Priority 2)

- **Target:** `Everyone` group
- **Access:** `ALLOW`
- **factor_mode:** `"2FA"` → MFA required, but less aggressive
- **Re-auth / session settings:**
  - Longer re-auth interval (e.g., every 12 hours)
  - Longer inactivity timeout (e.g., 1 hour)

**Effect:**  
All other users get a baseline MFA requirement with more relaxed session length.

---

#### Evaluation Order

- Okta evaluates rules by **priority**:
  - If user is in `restricted_users` → Rule 1 applies (stricter).
  - Otherwise → Rule 2 applies (baseline).

---

### 6. OAuth 2.0 Web Application

An **OAuth 2.0 web app** is created in Okta and bound to the policy:

- Key binding:

  ```hcl
  authentication_policy = okta_app_signon_policy.app_auth_policy.id


**Prerequisites**
---
Terraform 1.14+ (tested with 1.14.x)  
AWS Access key ID with permissions to EC2FullAccess/S3FullAccess  
Okta API token with permissions to manage apps/policies

**Commands for Testing**
```text
# Clone or copy these files into a folder

# cd to correct directory (okta or aws)

# For Okta integration
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (or set TF_VAR_* envs)

# Validate the reorganized structure
terraform validate

# Format all files consistently
terraform fmt -recursive

# Plan to ensure no changes
terraform plan

# Apply if everything looks good
terraform apply
```

**resources**
---
https://registry.terraform.io/
