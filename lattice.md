# VPC Lattice Service Networking

**Architecture:** Frontend → VPC Lattice Service Network → Backend


---

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                        │
│                                                                 │
│  ┌────────────────────┐         ┌──────────────────────┐      │
│  │  Public Subnet     │         │  Private Subnet      │      │
│  │  10.0.0.0/24       │         │  10.0.10.0/24        │      │
│  │                    │         │                      │      │
│  │  ┌──────────────┐  │         │  ┌────────────────┐ │      │
│  │  │   Bastion    │  │         │  │  Frontend ECS  │ │      │
│  │  │  (Testing)   │  │         │  │   (Fargate)    │ │      │
│  │  └──────┬───────┘  │         │  └────────┬───────┘ │      │
│  │         │          │         │           │         │      │
│  │    [SSH/SSM]      │         │           │         │      │
│  │         │          │         │           │         │      │
│  │         │          │         │      [Service Call] │      │
│  │         │          │         │           │         │      │
│  │         │          │         │           ▼         │      │
│  │         │          │    ┌─────────────────────────┐│      │
│  │         │          │    │ VPC Lattice Service Net ││      │
│  │         │          │    │   (169.254.171.0)       ││      │
│  │         │          │    │   Intelligent Routing   ││      │
│  │         │          │    └──────────┬──────────────┘│      │
│  │         │          │               │               │      │
│  │         └──────────┼───────────────┘               │      │
│  │                    │               │               │      │
│  └────────────────────┘               ▼               │      │
│                                  ┌─────────────┐      │      │
│  ┌────────────────────┐          │  Backend    │      │      │
│  │  Private Subnet    │          │ Registered  │      │      │
│  │  10.0.11.0/24      │          │  Targets    │      │      │
│  │                    │          └─────┬───────┘      │      │
│  │  ┌──────────────┐  │                │              │      │
│  │  │  Backend ECS │◄─┼────────────────┘              │      │
│  │  │  (Fargate)   │  │                               │      │
│  │  │ Port: 5678   │  │                               │      │
│  │  └──────────────┘  │                               │      │
│  └────────────────────┘                               │      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

Security Groups (Simplified):
┌─────────────────┐              ┌─────────────────┐
│  Frontend SG    │─────────────▶│   Backend SG    │
│ (No chaining!)  │              │ (VPC + link-    │
└─────────────────┘              │  local allowed) │
                                 └─────────────────┘

VPC Lattice Service Network (Logical Layer):
┌──────────────────────────────────────────────────┐
│  Service Network: vpc-lattice-lab-service-network│
│  Auth Type: NONE (demo) / AWS_IAM (production)   │
│                                                   │
│  ┌─────────────────────────────────────────┐    │
│  │  Service: backend                        │    │
│  │  DNS: backend-*.vpc-lattice-svcs.*.aws  │    │
│  │  Listener: HTTP:80                       │    │
│  │  Targets: Backend ECS tasks (IP)         │    │
│  └─────────────────────────────────────────┘    │
│                                                   │
│  Associated VPC: vpc-057eec434cea545ff           │
└──────────────────────────────────────────────────┘
```

---

## 📊 Components Created

### Infrastructure
- ✅ **VPC:** 10.0.0.0/16
- ✅ **Subnets:**
  - 2 Public subnets (10.0.0.0/24, 10.0.1.0/24)
  - 2 Private subnets (10.0.10.0/24, 10.0.11.0/24)
- ✅ **NAT Gateways:** 2 (for outbound internet)
- ✅ **Internet Gateway:** 1

### Compute
- ✅ **ECS Cluster:** vpc-lattice-lab-cluster
- ✅ **Frontend Service:** 1 task (nginx container)
- ✅ **Backend Service:** 1 task (http-echo container)
- ✅ **Bastion Instance:** t2.micro (for testing)

### VPC Lattice Components (New!)
- ✅ **Service Network:** vpc-lattice-lab-service-network
- ✅ **Service:** backend
- ✅ **Target Group:** vpc-lattice-lab-backend-tg (IP type)
- ✅ **Listener:** HTTP:80 → Backend targets
- ✅ **VPC Association:** Links VPC to service network
- ✅ **Auth Policy:** Configured (but using auth_type = NONE for demo)

### Security
- ✅ **2 Security Groups** (vs 3 in traditional):
  1. `vpc-lattice-lab-frontend-lattice-sg`
  2. `vpc-lattice-lab-backend-sg`
- ✅ **Simpler rules** (no chaining!)

### What's Missing (Compared to Traditional):
- ❌ **No Application Load Balancer**
- ❌ **No ALB Target Group**
- ❌ **No ALB Security Group**
- ❌ **No Security Group chaining**

---

## 🔍 CLI Analysis

### 1. Inspect VPC Lattice Service Network

```bash
# Get service network details
aws vpc-lattice list-service-networks \
  --region us-east-1 \
  --query 'items[?name==`vpc-lattice-lab-service-network`]'

# Output:
{
  "id": "sn-0ef31da83d4caa0ab",
  "name": "vpc-lattice-lab-service-network",
  "arn": "arn:aws:vpc-lattice:us-east-1:648832444881:servicenetwork/sn-0ef31da83d4caa0ab"
}
```

```bash
# Get detailed service network info
aws vpc-lattice get-service-network \
  --service-network-identifier sn-0ef31da83d4caa0ab \
  --region us-east-1

# Shows:
# - Auth type: NONE
# - Number of services: 1
# - Number of VPCs: 1
```

---

### 2. Inspect VPC Lattice Service

```bash
# List services
aws vpc-lattice list-services \
  --region us-east-1 \
  --query 'items[*].{Name:name,DNS:dnsEntry.domainName,AuthType:authType}'

# Output:
{
  "Name": "backend",
  "DNS": "backend-071ee12b9279df069.7d67968.vpc-lattice-svcs.us-east-1.on.aws",
  "AuthType": "NONE"
}
```

```bash
# Get backend service details
aws vpc-lattice get-service \
  --service-identifier svc-071ee12b9279df069 \
  --region us-east-1 \
  --query '{Name:name,DNS:dnsEntry.domainName,AuthType:authType,Status:status}'

# Shows service configuration
```

---

### 3. Check Service Associations

```bash
# List VPC associations
aws vpc-lattice list-service-network-vpc-associations \
  --service-network-identifier sn-0ef31da83d4caa0ab \
  --region us-east-1 \
  --query 'items[*].{VPC:vpcId,Status:status}'

# Output:
{
  "VPC": "vpc-057eec434cea545ff",
  "Status": "ACTIVE"
}
```

```bash
# List service associations
aws vpc-lattice list-service-network-service-associations \
  --service-network-identifier sn-0ef31da83d4caa0ab \
  --region us-east-1 \
  --query 'items[*].{Service:serviceId,DNS:dnsEntry.domainName,Status:status}'

# Shows backend service is associated
```

---

### 4. Check Target Group Health

```bash
# List targets in VPC Lattice target group
aws vpc-lattice list-targets \
  --target-group-identifier tg-07b23d1e7969b1085 \
  --region us-east-1 \
  --query 'items[*].{IP:id,Port:port,Status:status}' \
  --output table

# Output:
# ┌─────────────┬──────┬──────────┐
# │ IP          │ Port │ Status   │
# ├─────────────┼──────┼──────────┤
# │ 10.0.11.17  │ 5678 │ HEALTHY  │
# │ 10.0.10.53  │ 5678 │ HEALTHY  │
# └─────────────┴──────┴──────────┘
```

```bash
# Get target group configuration
aws vpc-lattice get-target-group \
  --target-group-identifier tg-07b23d1e7969b1085 \
  --region us-east-1 \
  --query 'config.{Port:port,Protocol:protocol,HealthCheck:healthCheck}'

# Shows:
# - Port: 5678
# - Protocol: HTTP
# - Health check configuration
```

---

### 5. Analyze Security Groups

```bash
# List security groups for VPC Lattice setup
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=vpc-057eec434cea545ff" "Name=tag:Scenario,Values=lattice" \
  --region us-east-1 \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId}' \
  --output table

# Output:
# ┌──────────────────┬──────────────────────────────┐
# │ ID               │ Name                         │
# ├──────────────────┼──────────────────────────────┤
# │ sg-xxxx          │ frontend-lattice-sg          │
# │ sg-yyyy          │ backend-sg                   │
# └──────────────────┴──────────────────────────────┘
# 
# Notice: Only 2 security groups! (vs 3 in traditional)
```

```bash
# Analyze backend security group
aws ec2 describe-security-groups \
  --group-names vpc-lattice-lab-backend-sg \
  --region us-east-1 \
  --query 'SecurityGroups[0].IpPermissions[*].{From:FromPort,To:ToPort,Protocol:IpProtocol,Source:IpRanges[*].CidrIp}'

# Shows:
# - Allow from VPC CIDR (10.0.0.0/16) on port 5678
# - Allow from link-local (169.254.0.0/16) on port 5678
# 
# The link-local range is VPC Lattice's endpoint range for health checks
```

---

### 6. Test from Bastion

```bash
# Connect to bastion
aws ssm start-session \
  --target i-02de3aed2d9ec5714 \
  --region us-east-1

# Test VPC Lattice service
curl http://backend-071ee12b9279df069.7d67968.vpc-lattice-svcs.us-east-1.on.aws

# Response:
# Hello from Backend Service! This is the response you requested.

# Verbose output
curl -v http://backend-071ee12b9279df069.7d67968.vpc-lattice-svcs.us-east-1.on.aws

# Key observations:
# - Resolved to: 169.254.171.0 (VPC Lattice link-local endpoint)
# - HTTP/1.1 200 OK
# - No ALB in the path!
```

---

## 📈 Traffic Flow Analysis

### Request Path (VPC Lattice)
```
1. Bastion (10.0.x.x)
   │
   ├─→ [DNS Resolution: backend.vpc-lattice-svcs.*.on.aws → 169.254.171.0]
   │
2. VPC Lattice Endpoint (169.254.171.0:80)
   │
   ├─→ [VPC Lattice Service Network: Intelligent routing]
   ├─→ [Auth Check: auth_type = NONE, allow based on VPC association]
   ├─→ [Target Selection: Pick healthy backend target]
   │
3. Backend ECS Task (10.0.11.17:5678)
   │
   ├─→ [Security Group: backend-sg allows from VPC + link-local]
   │
4. http-echo Container
   │
   └─→ Response: "Hello from Backend Service!"
```

### Key Differences from Traditional:
```
Traditional Path:
Bastion → ALB (10.0.11.90) → Backend (10.0.x.x)
         [3 SG hops]

VPC Lattice Path:
Bastion → Lattice Endpoint (169.254.171.0) → Backend (10.0.x.x)
         [No SG chaining needed!]
```

---

## 🔑 Key Observations

### 1. Trust Model: **Can Be Explicit or Network-Based**

**With `auth_type = "NONE"` (Demo):**
```
Frontend can call backend because:
- VPC is associated with service network
- Security groups allow traffic
- No ALB needed

→ Similar to Traditional, but simpler (no ALB!)
```

**With `auth_type = "AWS_IAM"` (Production):**
```
Frontend can call backend ONLY if:
- IAM auth policy explicitly allows it
- Request is signed with SigV4
- Caller has proper IAM permissions

→ Explicit authorization (not available in Traditional!)
```

### 2. Components Needed (Much Simpler!)

```
To connect Frontend → Backend with VPC Lattice:
✓ VPC Lattice Service Network
✓ VPC Lattice Service (backend)
✓ VPC Association
✓ 2 Security Groups (no chaining!)
✓ Built-in service discovery

Eliminated from Traditional:
✗ Application Load Balancer
✗ Target Group (ALB-specific)
✗ ALB Security Group
✗ Security Group chaining
```

### 3. Service Discovery (Built-In!)

```
Traditional:
- Must know ALB DNS name
- DNS: internal-vpc-lattice-lab-alb-*.elb.amazonaws.com
- Manual configuration

VPC Lattice:
- Service DNS automatically generated
- DNS: backend-*.vpc-lattice-svcs.us-east-1.on.aws
- Built-in discovery (no manual DNS setup)
```

### 4. Mental Model Shift

```
Question: "Is Frontend allowed to call Backend?"

Traditional Answer:
"Frontend can reach Backend via ALB if security groups permit"
→ Focus on CONNECTIVITY

VPC Lattice Answer (with AWS_IAM):
"Frontend is explicitly authorized to invoke Backend service"
→ Focus on AUTHORIZATION

VPC Lattice Answer (with NONE):
"Frontend can reach Backend via service network"
→ Focus on SERVICES (not infrastructure)
```

---

## 🔐 Authentication Deep Dive

### The Journey: What Happened During Testing

**Initial Deployment (auth_type = "AWS_IAM"):**
```bash
curl http://backend-*.vpc-lattice-svcs.us-east-1.on.aws

# Result:
HTTP/1.1 403 Forbidden
AccessDeniedException: User: anonymous is not authorized to perform: 
vpc-lattice-svcs:Invoke
```

**Why:** 
- VPC Lattice connected (169.254.171.0) ✅
- But IAM auth failed ❌
- Curl doesn't sign requests with AWS credentials
- **VPC Lattice denied by default**

**Final Configuration (auth_type = "NONE"):**
```bash
curl http://backend-*.vpc-lattice-svcs.us-east-1.on.aws

# Result:
HTTP/1.1 200 OK
Hello from Backend Service! This is the response you requested.
```

**Why:**
- No IAM authentication required
- Simple curl works (like ALB)
- Keeps demo focused on architecture

### The Lesson

**This 403 → 200 journey demonstrates:**
1. ✅ VPC Lattice **offers choice** in auth model
2. ✅ VPC Lattice **denies by default** with AWS_IAM
3. ✅ Access must be **explicitly granted** (not implicit)
4. ✅ This is **more secure** than traditional (when using AWS_IAM)

**For the blog:**
> "The 403 error wasn't a failure - it was VPC Lattice proving that access control is **explicit**, not implicit. Traditional ALB would have routed the traffic without asking questions."

---

## 💰 Cost Breakdown

### Hourly Costs (VPC Lattice Setup)
```
Component                    Cost/Hour
─────────────────────────────────────
NAT Gateways (2)             $0.09
VPC Lattice Service Network  $0.025
ECS Fargate (2 tasks)        $0.04
Bastion (t2.micro)           $0.01
────────────────────────────────────
TOTAL                        ~$0.17/hour

Note: No ALB cost! (~$0.025/hour saved vs traditional)
```

**For 1-hour test:** ~$0.17  
**Comparison:** Same cost as Traditional (~$0.17/hour)

---

## 🔍 What's Different (Technical Details)

### VPC Lattice Endpoint Discovery

```bash
# Resolve VPC Lattice service DNS
dig backend-071ee12b9279df069.7d67968.vpc-lattice-svcs.us-east-1.on.aws

# Returns:
# IPv4: 169.254.171.0
# IPv6: fd00:ec2:80::a9fe:ab00

# This is a link-local address managed by VPC Lattice
# NOT an ALB internal IP (10.0.x.x)
```

### Security Group Configuration

**Backend Security Group:**
```hcl
# Must allow from TWO CIDR ranges:
ingress {
  from_port   = 5678
  to_port     = 5678
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR
}

ingress {
  from_port   = 5678
  to_port     = 5678
  protocol    = "tcp"
  cidr_blocks = ["169.254.0.0/16"]  # VPC Lattice link-local
}
```

**Why both ranges:**
- `10.0.0.0/16` - Traffic from VPC (service calls)
- `169.254.0.0/16` - VPC Lattice health checks and routing

**Traditional (for comparison):**
```hcl
# Only allows from ALB security group
ingress {
  from_port              = 5678
  to_port                = 5678
  protocol               = "tcp"
  source_security_group_id = aws_security_group.alb.id
}
```

### Target Registration

```bash
# VPC Lattice requires manual IP registration
aws vpc-lattice register-targets \
  --target-group-identifier tg-07b23d1e7969b1085 \
  --targets id=10.0.11.17,port=5678 \
  --region us-east-1

# Check registered targets
aws vpc-lattice list-targets \
  --target-group-identifier tg-07b23d1e7969b1085 \
  --region us-east-1

# Note: Unlike ALB, VPC Lattice IP targets don't auto-register from ECS
# In production, use Lambda or service discovery for dynamic registration
```

---

## 📊 Comparison: Traditional vs VPC Lattice

| Aspect | Traditional (ALB) | VPC Lattice |
|--------|------------------|-------------|
| **Load Balancer** | Required (ALB) | Not needed ✅ |
| **Service Discovery** | ALB DNS | Built-in (service DNS) |
| **DNS Pattern** | `*.elb.amazonaws.com` | `*.vpc-lattice-svcs.*.on.aws` |
| **Connection IP** | Internal ALB (10.0.x.x) | Link-local (169.254.x.x) |
| **Security Groups** | 3 (chained) | 2 (simplified) ✅ |
| **SG Rules** | 6+ with chaining | Fewer, no chaining ✅ |
| **Auth Options** | Network-based only | Network OR IAM-based ✅ |
| **Access Model** | Implicit (SG = allow) | Explicit (with AWS_IAM) ✅ |
| **Target Registration** | Auto (ECS integration) | Manual (for IP type) |
| **Mental Model** | "Can it connect?" | "Is it allowed?" ✅ |
| **Components** | More | Fewer ✅ |
| **Complexity** | Higher | Lower ✅ |

---

## 🎯 Summary: VPC Lattice Model

### ✅ Pros
- No ALB needed for east-west traffic
- Simpler security group model
- Built-in service discovery
- Choice of auth models (NONE or AWS_IAM)
- Explicit access control option (IAM-based)
- Fewer components to manage
- Service-focused mental model

### ⚠️ Considerations
- Relatively new service (2022)
- Manual target registration for IP-based targets
- Requires understanding of service mesh concepts
- Auth with AWS_IAM adds complexity (but also security)

### 💡 When to Use
- Microservices architectures
- Service mesh requirements
- Need for explicit authorization
- Want to eliminate internal ALBs
- Focus on service-to-service communication

---

## 🔄 What Changed From Traditional

### Components Eliminated:
- ❌ Application Load Balancer
- ❌ ALB Target Group
- ❌ ALB Security Group
- ❌ Security Group chaining complexity

### Components Added:
- ✅ VPC Lattice Service Network
- ✅ VPC Lattice Service
- ✅ VPC Lattice Target Group (simpler than ALB TG)
- ✅ Service-to-service discovery (built-in)

### Security Model Evolved:
- ❌ Removed: Implicit trust via SG chaining
- ✅ Added: Option for explicit IAM-based authorization
- ✅ Added: Built-in deny-by-default (with AWS_IAM)

### Mental Model Shift:
- **Before:** "Does the network path exist?"
- **After:** "Is this service allowed to call that service?"

---

## 🧠 Lab Takeaway

VPC Lattice doesn't make Traditional "wrong."

It **models the problem differently**.

**Traditional:**
- Infrastructure-driven
- "Can frontend **reach** backend?" (network question)
- Answer: "Yes, via ALB"

**VPC Lattice:**
- Service-driven
- "Is frontend **allowed to call** backend?" (service question)
- Answer: "Yes, via service network policy"

**Both work. Different paradigm.**

That's the insight.

---

## 📸 Screenshots Location

All VPC Lattice screenshots are in: `/screenshots/lattice/`

### Current Screenshots:
- `Larice-service-networks.png` - Service network concept
- `Latice-services.png` - Backend service registered
- `Latice-Service-assosiation.png` - VPC and service associations
- `Latice-TG.png` - Target group with healthy targets
- `ECS.png` - ECS services (same as traditional)
- `CURL-LATICE.png` ⭐ - Working proof!

---

## 💻 Key Commands for Blog

### Show VPC Lattice Resources:
```bash
# Service network
aws vpc-lattice list-service-networks --region us-east-1

# Services
aws vpc-lattice list-services --region us-east-1

# Target health
aws vpc-lattice list-targets \
  --target-group-identifier <tg-id> \
  --region us-east-1
```

### Test Connectivity:
```bash
# From bastion
curl http://backend-*.vpc-lattice-svcs.us-east-1.on.aws

# Verbose (shows 169.254.171.0 connection)
curl -v http://backend-*.vpc-lattice-svcs.us-east-1.on.aws
```

---

## 🎓 What This Setup Demonstrates

### 1. **Service Mesh Without Sidecars**
- VPC Lattice is a **managed service mesh**
- No Envoy/Istio sidecars needed
- AWS-native solution

### 2. **Explicit Service Relationships**
- Service network defines boundary
- Services explicitly registered
- Access can be explicitly controlled (AWS_IAM)

### 3. **Simplified Operations**
- No ALB lifecycle management
- No target group registration complexity (for ALB type)
- Built-in service discovery
- Fewer security groups

### 4. **Flexibility in Security**
- Choose network-based (NONE) or identity-based (AWS_IAM)
- Traditional ALB: network-based only
- **More options = better fit for different requirements**

---

## 🔐 Production Recommendations

### For Production, Use:

**1. `auth_type = "AWS_IAM"`**
```hcl
resource "aws_vpclattice_service" "backend" {
  auth_type = "AWS_IAM"
}

resource "aws_vpclattice_auth_policy" "backend" {
  policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::account:role/FrontendServiceRole"
      }
      Action = "vpc-lattice-svcs:Invoke"
      Resource = "*"
    }]
  })
}
```

**Benefits:**
- Explicit authorization
- CloudTrail audit logs
- Caller identity known
- Defense-in-depth security

**2. ALB Target Type (Instead of IP)**
```hcl
resource "aws_vpclattice_target_group" "backend" {
  type = "ALB"  # Points to existing ALB
  # Automatic target discovery, no manual registration
}
```

---

**Status:** VPC Lattice setup documented ✅  
**Ready for:** Blog post comparison section →

