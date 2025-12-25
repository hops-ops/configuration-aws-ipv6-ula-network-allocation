# aws-ipv6-ula-network-allocation

Bridge between IPAM (address space) and Network (infrastructure). Reserves ULA IPv6 VPC and subnet CIDRs via IPAM pool allocations.

## Purpose

IPv6ULANetworkAllocation creates per-network pools and allocations from a regional ULA IPAM pool, then exposes the allocated CIDRs in status for aws-network to consume.

ULA (Unique Local Address) uses the fd00::/8 private address space, similar to IPv4's RFC 1918 addresses.

## Pool Hierarchy

```
aws-ipam creates:
├── Global ULA Pool /32 (fd00:1234::/32)
└── Regional Pools /40 or /44 (children of global)
      └── us-east-1 pool (fd00:1234:0000::/40)

IPv6ULANetworkAllocation creates (per network):
└── VPC Pool (child of regional)
      └── VPCIpamPoolCidr (gets /48 from regional)
      │
      ├── Private Subnet Pool (child of VPC pool)
      │     └── VPCIpamPoolCidr (VPC's /48)
      │     └── allocationDefaultNetmaskLength: 64 (AWS requirement)
      │     └── VPCIpamPoolCidrAllocation × N (per AZ)
      │
      └── Public Subnet Pool (child of VPC pool)
            └── VPCIpamPoolCidr (VPC's /48)
            └── allocationDefaultNetmaskLength: 64 (AWS requirement)
            └── VPCIpamPoolCidrAllocation × N (per AZ)
```

## Observed-State Gating Flow

Templates execute in order, each gating on the previous step:

```
20-vpc-pool.yaml.gotmpl
    │ Creates: VPCIpamPool, VPCIpamPoolCidr
    ▼
10-observed-values.yaml.gotmpl
    │ Checks: VPC pool ready, extracts pool ID + CIDR
    ▼
30-subnet-pools.yaml.gotmpl
    │ Creates: Private pool, Public pool, PoolCidrs
    │ Gated on: $vpcPoolFullyReady
    ▼
40-subnet-allocations.yaml.gotmpl
    │ Creates: VPCIpamPoolCidrAllocation per subnet
    │ Gated on: $subnetPoolsFullyReady
    ▼
99-status.yaml.gotmpl
    │ Reads all allocation CIDRs, outputs status
```

## API

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IPv6ULANetworkAllocation
metadata:
  name: prod-east
  namespace: infra
spec:
  # Required: regional ULA pool ID from aws-ipam status
  regionalPoolId: ipam-pool-0123456789abcdef0

  aws:
    providerConfig: default
    region: us-east-1

  vpc:
    netmaskLength: 48  # VPC CIDR size

  subnets:
    availabilityZones: [a, b, c]
    types:
      public:
        netmaskLength: 64  # AWS requires /64 for IPv6
      private:
        netmaskLength: 64  # AWS requires /64 for IPv6

status:
  ready: true
  cidr: "fd00:1234:5678::/48"
  vpcPoolId: ipam-pool-xxx
  privatePoolId: ipam-pool-yyy
  publicPoolId: ipam-pool-zzz
  subnets:
    public-a: "fd00:1234:5678:100::/64"
    public-b: "fd00:1234:5678:101::/64"
    public-c: "fd00:1234:5678:102::/64"
    private-a: "fd00:1234:5678:1::/64"
    private-b: "fd00:1234:5678:2::/64"
    private-c: "fd00:1234:5678:3::/64"
```

## Development

```bash
make render:all     # Render all examples
make validate:all   # Validate all examples
make test           # Run KCL tests
make e2e            # Run E2E tests
```

## Key Conventions

- Uses `.m.` namespaced API versions for Crossplane 2.0 compatibility
- All templates use `setResourceNameAnnotation` for observed-state tracking
- IPAM does all CIDR math - no calculations in templates
- Status exposes CIDRs for downstream consumers (aws-network, aws-globalnetwork)
- AWS requires /64 for all IPv6 subnets - this is enforced in the schema

## Avoid Upbound-hosted packages

Favor `crossplane-contrib` packages over Upbound-hosted ones due to paid-account restrictions.
