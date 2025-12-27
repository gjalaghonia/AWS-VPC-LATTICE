# Screenshots for VPC Lattice Blog

This folder contains all screenshots for the blog post:  
**"Microservices Networking on AWS: Before and After VPC Lattice"**

---

## 🎯 Purpose

These screenshots provide **visual proof** of the architectural differences between:
- **Traditional Setup:** Microservices networking using Application Load Balancer
- **VPC Lattice Setup:** Microservices networking using AWS VPC Lattice

The screenshots show the **before and after** comparison that makes the blog post compelling and credible.

---

## 📁 Folder Structure

```
screenshots/
├── traditional/          # Traditional ALB-based setup screenshots
└── lattice/              # VPC Lattice setup screenshots
```

---

## 📸 Traditional Setup - What These Show

These screenshots demonstrate the **Traditional ALB-based architecture**.

### Components Captured:

**1. Application Load Balancer**
- Shows the ALB exists and is internal
- DNS name pattern: `internal-vpc-lattice-lab-alb-*.elb.amazonaws.com`
- Proves ALB is required for service-to-service communication

**2. Target Group Health**
- Backend targets are healthy
- Registered IPs visible
- ALB successfully routing to backend

**3. Security Groups (The Complexity!)**
- **3 Security Groups** with chained rules
- Frontend SG → ALB SG → Backend SG
- **Implicit trust model:** If security groups allow, traffic flows
- Multiple ingress/egress rules to manage

**4. ECS Services**
- Both frontend and backend services running
- ALB target group attachment required

**5. Working Proof** ⭐
- Curl to ALB DNS succeeds
- Connection to internal ALB IP (10.0.x.x)
- Response: "Hello from Backend Service!"

### What This Proves:
- ✅ More components (ALB, Target Group, 3 SGs)
- ✅ Security group chaining required
- ✅ Access is implicit (network-based only)
- ✅ Works, but more complex

---

## 📸 VPC Lattice Setup - What These Show

These screenshots demonstrate the **VPC Lattice architecture** and what's different/simpler.

### Components Captured:

**1. VPC Lattice Service Network**
- New concept: Service mesh layer
- Auth type visible (NONE for demo)
- VPC associations shown

**2. VPC Lattice Service**
- Backend service registered in Lattice
- DNS name pattern: `backend-*.vpc-lattice-svcs.us-east-1.on.aws`
- **Different DNS pattern** than traditional ALB
- No ALB needed!

**3. Service Associations**
- Shows how VPC and services connect
- Service network provides discovery
- Simpler than manual DNS management

**4. Target Group with Registered Targets**
- Healthy backend targets
- Manual IP registration (unlike ALB auto-discovery)
- Health checks from link-local range (169.254.0.0/16)

**5. Security Groups (Simpler!)**
- **Only 2 Security Groups** vs 3 in traditional
- No chaining needed
- Backend allows from VPC CIDR + link-local
- **Simpler model**

**6. ECS Services**
- Same services as traditional
- No ALB dependency

**7. Working Proof** ⭐
- Curl to VPC Lattice service DNS succeeds
- Connection to link-local IP (169.254.171.0) - VPC Lattice endpoint
- Response: Same "Hello from Backend Service!"
- **No ALB, same result!**

### What This Proves:
- ✅ Fewer components (no ALB!)
- ✅ Simpler security groups (2 instead of 3)
- ✅ Built-in service discovery
- ✅ Can choose auth model (NONE or AWS_IAM)
- ✅ Same functionality, different paradigm

---

## 🎯 The Critical Comparisons

Your screenshots visually prove these key differences:

### 1. **Components Eliminated**
- Traditional: ALB + Target Group + 3 Security Groups
- VPC Lattice: No ALB + No Target Group + 2 Security Groups
- **Saved:** Infrastructure complexity

### 2. **Security Model**
- Traditional: 3-way SG chaining (Frontend → ALB → Backend)
- VPC Lattice: Direct VPC association, simpler rules
- **Saved:** Security group management complexity

### 3. **Service Discovery**
- Traditional: ALB DNS (`*.elb.amazonaws.com`)
- VPC Lattice: Service DNS (`*.vpc-lattice-svcs.*.on.aws`)
- **Gained:** Built-in service mesh discovery

### 4. **Connection Path**
- Traditional: Internal ALB IP (10.0.x.x)
- VPC Lattice: Link-local IP (169.254.171.0)
- **Different:** But both work!

### 5. **Access Control**
- Traditional: Security groups only (implicit)
- VPC Lattice: Choice of NONE (network) or AWS_IAM (explicit)
- **Gained:** Flexibility in security model

---

## ✅ Screenshot Status

### Traditional Setup: ✅ COMPLETE
- `ALB-INTERNAL.png` - ALB console
- `TG.png` - Target Group health
- `Frontend-SG.png` - Frontend security group
- `ALB-SG-INBOUND.png` - ALB inbound rules
- `ALB-SG-OUTBOUND.png` - ALB outbound rules
- `Backend-SG.png` - Backend security group
- `ECS.png` - ECS cluster services
- `CURL-TEST.png` ⭐ - Working proof!

**Key Proof:** 8 screenshots showing ALB-based architecture complexity

### VPC Lattice Setup: ✅ COMPLETE
- `Larice-service-networks.png` - Service network
- `Latice-services.png` - Lattice service
- `Latice-Service-assosiation.png` - VPC/service associations
- `Latice-TG.png` - Target Group with registered targets
- `ECS.png` - ECS cluster services
- `CURL-LATICE.png` ⭐ - Working proof!

**Key Proof:** 6 screenshots showing simpler VPC Lattice architecture

---

## 🎓 What These Screenshots Collectively Prove

**The Blog's Main Point:**
> "Same functionality, different model - and the new model is simpler."

**Visual Evidence:**
1. ✅ Traditional needs ALB - VPC Lattice doesn't
2. ✅ Traditional needs 3 SGs - VPC Lattice needs 2
3. ✅ Traditional has implicit trust - VPC Lattice can be explicit
4. ✅ Both work - but VPC Lattice is architecturally simpler

**The Question Answered:**
- Traditional: "Can frontend reach backend?" (network question)
- VPC Lattice: "Is frontend allowed to call backend?" (service question)

**The Value:**
- Not "better" or "worse"
- **Different mental model**
- Service-driven vs infrastructure-driven
- That's the insight!

---

## 💡 Using Screenshots in Your Blog

### For Introduction:
- Use Traditional CURL-TEST to show "this is how we do it today"

### For Problem Statement:
- Show Traditional security group chaining (complexity)
- Show multiple components (ALB, TG, 3 SGs)

### For Solution:
- Show VPC Lattice service network (new concept)
- Show simplified security groups
- Show working curl (same result, simpler path)

### For Comparison:
- Side-by-side: Traditional SGs vs Lattice SGs
- Side-by-side: ALB DNS vs Lattice service DNS
- Side-by-side: curl output showing different connection IPs

### For Conclusion:
- VPC Lattice CURL-LATICE showing it works without ALB

---

**All screenshots captured and documented!** 📸✅

Ready to be inserted into blog post for visual proof of architectural differences.
