# aws-ipv6-ula-network-allocation

Crossplane configuration that bridges IPAM and Network by creating per-network IPAM pools and reserving ULA IPv6 CIDRs via `VPCIpamPoolCidrAllocation`. Exposes allocated CIDRs in status for downstream Network configurations to consume.

## Overview

This configuration implements the IPv6 ULA allocation layer in the four-entity networking model:

```
aws-ipam (global ULA pools)
    └── aws-ipv6-ula-network-allocation (per-network pools + allocations)
            └── aws-network (VPC + subnets using allocated CIDRs)
```

ULA (Unique Local Address) uses the fd00::/8 private address space, similar to IPv4's RFC 1918 addresses.

## Pool Hierarchy

The configuration creates a hierarchy of IPAM pools:

```
Regional Pool (from aws-ipam, e.g., /40 or /44)
└── VPC Pool (/48 default)
    ├── Private Subnet Pool
    │   └── Allocations per AZ (/64, AWS requirement)
    └── Public Subnet Pool
        └── Allocations per AZ (/64, AWS requirement)
```

## Usage

### Minimal Example

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IPv6ULANetworkAllocation
metadata:
  name: prod-east
  namespace: infra
spec:
  # Required: regional ULA pool ID from aws-ipam status
  regionalPoolId: ipam-pool-0123456789abcdef0
```

Uses defaults:
- VPC netmask: /48
- All subnets: /64 (AWS requirement for IPv6)
- AZs: a, b, c

### Standard Example

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IPv6ULANetworkAllocation
metadata:
  name: prod-east
  namespace: infra
spec:
  regionalPoolId: ipam-pool-0123456789abcdef0

  aws:
    providerConfig: default
    region: us-east-1

  vpc:
    netmaskLength: 48

  subnets:
    availabilityZones:
    - a
    - b
    - c
    types:
      public:
        netmaskLength: 64
      private:
        netmaskLength: 64
```

### Custom Sizes Example

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IPv6ULANetworkAllocation
metadata:
  name: dev-west
  namespace: infra
spec:
  regionalPoolId: ipam-pool-0123456789abcdef0

  aws:
    providerConfig: default
    region: us-west-2

  # Smaller VPC for dev - /56 instead of /48
  vpc:
    netmaskLength: 56

  # Only 2 AZs, but subnets must still be /64 (AWS requirement)
  subnets:
    availabilityZones:
    - a
    - b
    types:
      public:
        netmaskLength: 64
      private:
        netmaskLength: 64
```

## Status

Once all allocations are ready, the status exposes:

```yaml
status:
  ready: true
  cidr: "fd00:1234:5678::/48"
  vpcPoolId: "ipam-pool-vpc-12345"
  privatePoolId: "ipam-pool-private-12345"
  publicPoolId: "ipam-pool-public-12345"
  subnets:
    private-a: "fd00:1234:5678:1::/64"
    private-b: "fd00:1234:5678:2::/64"
    private-c: "fd00:1234:5678:3::/64"
    public-a: "fd00:1234:5678:100::/64"
    public-b: "fd00:1234:5678:101::/64"
    public-c: "fd00:1234:5678:102::/64"
```

## Spec Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `regionalPoolId` | string | (required) | ID of the regional ULA IPAM pool to allocate from |
| `aws.providerConfig` | string | `"default"` | AWS ProviderConfig name |
| `aws.region` | string | `"us-east-1"` | AWS region |
| `vpc.netmaskLength` | integer | `48` | VPC CIDR netmask (44-60) |
| `subnets.availabilityZones` | []string | `["a", "b", "c"]` | AZ suffixes |
| `subnets.types.public.netmaskLength` | integer | `64` | Public subnet netmask (must be 64) |
| `subnets.types.private.netmaskLength` | integer | `64` | Private subnet netmask (must be 64) |
| `managementPolicies` | []string | `["*"]` | Crossplane management policies |

## Observed-State Gating

The composition uses observed-state gating to create resources in stages:

1. **Stage 1**: VPC pool + CIDR (always created)
2. **Stage 2**: Subnet pools + CIDRs (after VPC pool ready)
3. **Stage 3**: Subnet allocations (after subnet pools ready)

This prevents premature resource creation and ensures CIDRs are properly allocated before dependent resources reference them.

## Development

```bash
# Render examples
make render:all

# Validate examples
make validate:all

# Run unit tests
make test

# Run E2E tests (requires AWS credentials)
make e2e
```

## Testing

### Unit Tests

Located in `tests/test-render/`, these test:
- Minimal example with defaults
- Standard example with explicit values
- Multi-step reconciliation with observed resources
- Status output with allocated CIDRs

### E2E Tests

Located in `tests/e2etest-ipv6ulanetworkallocations/`. Prerequisites:
1. Run `aws-ipam` E2E test first to create persistent IPAM with ULA pools
2. Copy AWS credentials to `tests/e2etest-ipv6ulanetworkallocations/secrets/aws-creds`
3. Update `_regional_pool_id` in `main.k` with your ULA pool ID

## Dependencies

- Requires `aws-ipam` to create regional ULA pools
- Used by `aws-network` for VPC/subnet CIDRs
- Part of `aws-globalnetwork` orchestration
