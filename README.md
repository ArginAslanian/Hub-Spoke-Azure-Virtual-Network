# Enterprise Hub & Spoke Cloud Architecture in Azure

## Objective
The goal of this project was to design, provision, and secure an enterprise-grade Hub and Spoke network topology within Microsoft Azure. This architecture centralizes security and management resources while isolating departmental workloads, demonstrating a zero-trust approach to internal cloud traffic.

## Tools & Technologies Used
* **Cloud Platform:** Microsoft Azure
* **Networking:** Azure Virtual Networks (VNet), VNet Peering, Azure Route Tables
* **Security:** Azure Firewall, Network Security Groups (NSGs)
* **Remote Access:** Azure Bastion
* **Compute:** Windows Server 2022 Virtual Machines
* **Automation:** Terraform (Infrastructure as Code)
* **Scripting:** PowerShell (Host-level firewall configuration)

## Architecture & Deployment

### 1. The Hub and Spoke Topology
At the core of this project is the Hub VNet, acting as the central point of connectivity and security. Three distinct Spoke VNets (HR, Finance, IT) were deployed to represent isolated departmental environments.

<img width="2778" height="2019" alt="RG-HubSpoke-Lab" src="https://github.com/user-attachments/assets/c96eec7a-4cec-4639-8ccf-c044adee43ed" />


### 2. Establishing Network Bridges
To connect the isolated environments, non-transitive VNet Peerings were established between the Hub and each Spoke. Traffic forwarding was explicitly enabled to allow the Hub to act as a secure middleman for inter-departmental communication.

<img width="1688" height="848" alt="Hub Peerings" src="https://github.com/user-attachments/assets/a68e9703-c685-48af-b008-96f1818489e5" />

### 3. Enforcing Custom Routing (User Defined Routes)
By default, peered Spoke networks can communicate directly. To enforce security inspection, a custom Route Table was created and associated with all Spoke subnets. A User Defined Route (UDR) was implemented to force all internal traffic (`10.0.0.0/16`) to the private IP of the central Azure Firewall.

<img width="1679" height="713" alt="Route Tables" src="https://github.com/user-attachments/assets/234d24c8-5698-4b62-9baa-b7cf261268a8" />

### 4. Centralized Firewall Inspection
With traffic forced into the Hub, an Azure Firewall was deployed to inspect all packets. A default-deny stance was maintained, with a specific Network Rule Collection created to explicitly allow ICMP (Ping) traffic strictly between the Spoke subnets.

<img width="1684" height="600" alt="Allow ICMP Firewall Rule" src="https://github.com/user-attachments/assets/a8ecff7b-7a04-488c-81a0-ac33dad62893" />

### 5. Secure Identity-Based Access
To completely eliminate the need for Public IP addresses on the workload VMs, Azure Bastion was deployed in the Hub. This allowed for secure, browser-based RDP sessions into the Spoke VMs across the peering connections, drastically reducing the external attack surface.

### 6. Validation and Testing
Windows Server 2022 VMs were provisioned in the IT and Finance Spokes. After configuring the local Windows Defender Firewalls via PowerShell to accept ICMP requests, a successful ping test was executed. The traffic originated in the IT Spoke, was routed to the Hub, inspected and allowed by the Azure Firewall, and delivered to the Finance Spoke.

<img width="1691" height="877" alt="VM in IT Spoke pinging VM in Finance - Bastion Connection" src="https://github.com/user-attachments/assets/87a01a1a-4267-46aa-a5f6-d9ee563b6b53" />
