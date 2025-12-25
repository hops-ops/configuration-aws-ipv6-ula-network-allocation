import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1


_items = [
    # Test 1: Minimal example - initial render (no observed resources)
    # Should create VPC pool and CIDR with defaults
    # Note: minimal.yaml uses name "prod-east" and regionalPoolId "ipam-pool-0123456789abcdef0"
    metav1alpha1.CompositionTest{
        metadata.name: "test-ipv6-ula-allocation-minimal"
        spec = {
            compositionPath: "apis/ipv6ulanetworkallocations/composition.yaml"
            xrPath: "examples/ipv6ulanetworkallocations/minimal.yaml"
            xrdPath: "apis/ipv6ulanetworkallocations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                # VPC Pool - child of regional ULA pool
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-vpc"
                        labels: {
                            "hops.ops.com.ai/network-allocation": "prod-east"
                            "hops.ops.com.ai/pool-type": "vpc"
                        }
                    }
                    spec: {
                        managementPolicies: ["*"]
                        forProvider: {
                            addressFamily: "ipv6"
                            sourceIpamPoolId: "ipam-pool-0123456789abcdef0"
                            allocationDefaultNetmaskLength: 48
                            locale: "us-east-1"
                            region: "us-east-1"
                            tags: {
                                hops: "true"
                                "managed-by": "crossplane"
                                "address-family": "ipv6"
                            }
                        }
                        providerConfigRef: {
                            kind: "ProviderConfig"
                            name: "default"
                        }
                    }
                },
                # VPC Pool CIDR - allocates /48 from regional ULA pool
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-vpc"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        forProvider: {
                            netmaskLength: 48
                            region: "us-east-1"
                        }
                        providerConfigRef: {
                            kind: "ProviderConfig"
                            name: "default"
                        }
                    }
                }
            ]
        }
    },

    # Test 2: Standard example with explicit values
    metav1alpha1.CompositionTest{
        metadata.name: "test-ipv6-ula-allocation-standard"
        spec = {
            compositionPath: "apis/ipv6ulanetworkallocations/composition.yaml"
            xrPath: "examples/ipv6ulanetworkallocations/standard.yaml"
            xrdPath: "apis/ipv6ulanetworkallocations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-vpc"
                    }
                    spec: {
                        forProvider: {
                            addressFamily: "ipv6"
                            sourceIpamPoolId: "ipam-pool-0123456789abcdef0"
                            allocationDefaultNetmaskLength: 48
                            locale: "us-east-1"
                            region: "us-east-1"
                        }
                        providerConfigRef: {
                            kind: "ProviderConfig"
                            name: "default"
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-vpc"
                    }
                    spec: {
                        forProvider: {
                            netmaskLength: 48
                            region: "us-east-1"
                        }
                    }
                }
            ]
        }
    },

    # Test 3: With VPC pool ready - should create subnet pools
    metav1alpha1.CompositionTest{
        metadata.name: "test-ipv6-ula-allocation-step2-subnet-pools"
        spec = {
            compositionPath: "apis/ipv6ulanetworkallocations/composition.yaml"
            xrPath: "examples/ipv6ulanetworkallocations/standard.yaml"
            xrdPath: "apis/ipv6ulanetworkallocations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            observedResources: [
                # VPC Pool - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-vpc"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "vpc-pool"
                            "crossplane.io/composition-resource-name": "vpc-pool"
                        }
                    }
                    status: {
                        conditions: [
                            { type: "Ready", status: "True" }
                        ]
                        atProvider: {
                            id: "ipam-pool-vpc-0abc123def456"
                            arn: "arn:aws:ec2:us-east-1:123456789012:ipam-pool/ipam-pool-vpc-0abc123def456"
                        }
                    }
                },
                # VPC Pool CIDR - Ready with allocated ULA CIDR
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-vpc"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "vpc-pool-cidr"
                            "crossplane.io/composition-resource-name": "vpc-pool-cidr"
                        }
                    }
                    status: {
                        conditions: [
                            { type: "Ready", status: "True" }
                        ]
                        atProvider: {
                            id: "ipam-pool-cidr-vpc-0abc123"
                            cidr: "fd00:1234:5678::/48"
                        }
                    }
                }
            ]
            assertResources: [
                # VPC Pool still exists
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: { name: "prod-east-vpc" }
                },
                # Private Subnet Pool - child of VPC pool
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-private"
                        labels: {
                            "hops.ops.com.ai/network-allocation": "prod-east"
                            "hops.ops.com.ai/pool-type": "subnet-private"
                        }
                    }
                    spec: {
                        forProvider: {
                            addressFamily: "ipv6"
                            sourceIpamPoolId: "ipam-pool-vpc-0abc123def456"
                            allocationDefaultNetmaskLength: 64
                            locale: "us-east-1"
                            region: "us-east-1"
                        }
                    }
                },
                # Private Subnet Pool CIDR
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: { name: "prod-east-private" }
                    spec: {
                        forProvider: {
                            cidr: "fd00:1234:5678::/48"
                            region: "us-east-1"
                        }
                    }
                },
                # Public Subnet Pool - child of VPC pool
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-public"
                        labels: {
                            "hops.ops.com.ai/network-allocation": "prod-east"
                            "hops.ops.com.ai/pool-type": "subnet-public"
                        }
                    }
                    spec: {
                        forProvider: {
                            addressFamily: "ipv6"
                            sourceIpamPoolId: "ipam-pool-vpc-0abc123def456"
                            allocationDefaultNetmaskLength: 64
                            locale: "us-east-1"
                            region: "us-east-1"
                        }
                    }
                },
                # Public Subnet Pool CIDR
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: { name: "prod-east-public" }
                    spec: {
                        forProvider: {
                            cidr: "fd00:1234:5678::/48"
                            region: "us-east-1"
                        }
                    }
                }
            ]
        }
    },

    # Test 4: With subnet pools ready - should create allocations
    metav1alpha1.CompositionTest{
        metadata.name: "test-ipv6-ula-allocation-step3-allocations"
        spec = {
            compositionPath: "apis/ipv6ulanetworkallocations/composition.yaml"
            xrPath: "examples/ipv6ulanetworkallocations/standard.yaml"
            xrdPath: "apis/ipv6ulanetworkallocations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            observedResources: [
                # VPC Pool - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-vpc"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "vpc-pool"
                            "crossplane.io/composition-resource-name": "vpc-pool"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: {
                            id: "ipam-pool-vpc-0abc123def456"
                            arn: "arn:aws:ec2:us-east-1:123456789012:ipam-pool/ipam-pool-vpc-0abc123def456"
                        }
                    }
                },
                # VPC Pool CIDR - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-vpc"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "vpc-pool-cidr"
                            "crossplane.io/composition-resource-name": "vpc-pool-cidr"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: {
                            id: "ipam-pool-cidr-vpc-0abc123"
                            cidr: "fd00:1234:5678::/48"
                        }
                    }
                },
                # Private Subnet Pool - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-private"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-private"
                            "crossplane.io/composition-resource-name": "subnet-pool-private"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: {
                            id: "ipam-pool-private-0abc123def456"
                            arn: "arn:aws:ec2:us-east-1:123456789012:ipam-pool/ipam-pool-private-0abc123def456"
                        }
                    }
                },
                # Private Subnet Pool CIDR - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-private"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-private-cidr"
                            "crossplane.io/composition-resource-name": "subnet-pool-private-cidr"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-private-0abc123" }
                    }
                },
                # Public Subnet Pool - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-public"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-public"
                            "crossplane.io/composition-resource-name": "subnet-pool-public"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: {
                            id: "ipam-pool-public-0abc123def456"
                            arn: "arn:aws:ec2:us-east-1:123456789012:ipam-pool/ipam-pool-public-0abc123def456"
                        }
                    }
                },
                # Public Subnet Pool CIDR - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-public"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-public-cidr"
                            "crossplane.io/composition-resource-name": "subnet-pool-public-cidr"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-public-0abc123" }
                    }
                }
            ]
            assertResources: [
                # Private subnet allocations for AZs a, b, c - all /64 (AWS requirement)
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-private-a"
                        labels: {
                            "hops.ops.com.ai/network-allocation": "prod-east"
                            "hops.ops.com.ai/subnet-type": "private"
                            "hops.ops.com.ai/availability-zone": "a"
                        }
                    }
                    spec: {
                        forProvider: {
                            ipamPoolId: "ipam-pool-private-0abc123def456"
                            netmaskLength: 64
                            region: "us-east-1"
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-private-b"
                        labels: {
                            "hops.ops.com.ai/subnet-type": "private"
                            "hops.ops.com.ai/availability-zone": "b"
                        }
                    }
                    spec: {
                        forProvider: {
                            ipamPoolId: "ipam-pool-private-0abc123def456"
                            netmaskLength: 64
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-private-c"
                        labels: {
                            "hops.ops.com.ai/subnet-type": "private"
                            "hops.ops.com.ai/availability-zone": "c"
                        }
                    }
                    spec: {
                        forProvider: {
                            ipamPoolId: "ipam-pool-private-0abc123def456"
                            netmaskLength: 64
                        }
                    }
                },
                # Public subnet allocations for AZs a, b, c - all /64 (AWS requirement)
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-public-a"
                        labels: {
                            "hops.ops.com.ai/subnet-type": "public"
                            "hops.ops.com.ai/availability-zone": "a"
                        }
                    }
                    spec: {
                        forProvider: {
                            ipamPoolId: "ipam-pool-public-0abc123def456"
                            netmaskLength: 64
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-public-b"
                        labels: {
                            "hops.ops.com.ai/subnet-type": "public"
                            "hops.ops.com.ai/availability-zone": "b"
                        }
                    }
                    spec: {
                        forProvider: {
                            ipamPoolId: "ipam-pool-public-0abc123def456"
                            netmaskLength: 64
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-public-c"
                        labels: {
                            "hops.ops.com.ai/subnet-type": "public"
                            "hops.ops.com.ai/availability-zone": "c"
                        }
                    }
                    spec: {
                        forProvider: {
                            ipamPoolId: "ipam-pool-public-0abc123def456"
                            netmaskLength: 64
                        }
                    }
                }
            ]
        }
    },

    # Test 5: Custom sizes example (dev-west with /56 VPC instead of /48, only 2 AZs)
    metav1alpha1.CompositionTest{
        metadata.name: "test-ipv6-ula-allocation-custom-sizes"
        spec = {
            compositionPath: "apis/ipv6ulanetworkallocations/composition.yaml"
            xrPath: "examples/ipv6ulanetworkallocations/custom-sizes.yaml"
            xrdPath: "apis/ipv6ulanetworkallocations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: { name: "dev-west-vpc" }
                    spec: {
                        forProvider: {
                            addressFamily: "ipv6"
                            allocationDefaultNetmaskLength: 56
                            locale: "us-west-2"
                            region: "us-west-2"
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: { name: "dev-west-vpc" }
                    spec: {
                        forProvider: {
                            netmaskLength: 56
                            region: "us-west-2"
                        }
                    }
                }
            ]
        }
    },

    # Test 6: Full flow with all allocations ready - verify status
    metav1alpha1.CompositionTest{
        metadata.name: "test-ipv6-ula-allocation-complete-status"
        spec = {
            compositionPath: "apis/ipv6ulanetworkallocations/composition.yaml"
            xrPath: "examples/ipv6ulanetworkallocations/standard.yaml"
            xrdPath: "apis/ipv6ulanetworkallocations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            observedResources: [
                # VPC Pool - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-vpc"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "vpc-pool"
                            "crossplane.io/composition-resource-name": "vpc-pool"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: {
                            id: "ipam-pool-vpc-0abc123def456"
                            arn: "arn:aws:ec2:us-east-1:123456789012:ipam-pool/ipam-pool-vpc-0abc123def456"
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-vpc"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "vpc-pool-cidr"
                            "crossplane.io/composition-resource-name": "vpc-pool-cidr"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-vpc-0abc123", cidr: "fd00:1234:5678::/48" }
                    }
                },
                # Subnet Pools - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-private"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-private"
                            "crossplane.io/composition-resource-name": "subnet-pool-private"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-private-0abc123def456" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-private"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-private-cidr"
                            "crossplane.io/composition-resource-name": "subnet-pool-private-cidr"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-private-0abc123" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-public"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-public"
                            "crossplane.io/composition-resource-name": "subnet-pool-public"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-public-0abc123def456" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-public"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-public-cidr"
                            "crossplane.io/composition-resource-name": "subnet-pool-public-cidr"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-public-0abc123" }
                    }
                },
                # Subnet Allocations - Ready with ULA CIDRs
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-private-a"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-private-a"
                            "crossplane.io/composition-resource-name": "subnet-private-a"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-alloc-private-a", cidr: "fd00:1234:5678:0100::/64" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-private-b"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-private-b"
                            "crossplane.io/composition-resource-name": "subnet-private-b"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-alloc-private-b", cidr: "fd00:1234:5678:0101::/64" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-private-c"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-private-c"
                            "crossplane.io/composition-resource-name": "subnet-private-c"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-alloc-private-c", cidr: "fd00:1234:5678:0102::/64" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-public-a"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-public-a"
                            "crossplane.io/composition-resource-name": "subnet-public-a"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-alloc-public-a", cidr: "fd00:1234:5678:0000::/64" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-public-b"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-public-b"
                            "crossplane.io/composition-resource-name": "subnet-public-b"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-alloc-public-b", cidr: "fd00:1234:5678:0001::/64" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-public-c"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-public-c"
                            "crossplane.io/composition-resource-name": "subnet-public-c"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-alloc-public-c", cidr: "fd00:1234:5678:0002::/64" }
                    }
                }
            ]
            assertResources: [
                # XR status should be updated with all ULA CIDRs
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "IPv6ULANetworkAllocation"
                    metadata: {
                        name: "prod-east"
                    }
                    status: {
                        ready: True
                        cidr: "fd00:1234:5678::/48"
                        vpcPoolId: "ipam-pool-vpc-0abc123def456"
                        privatePoolId: "ipam-pool-private-0abc123def456"
                        publicPoolId: "ipam-pool-public-0abc123def456"
                        subnets: {
                            "private-a": "fd00:1234:5678:0100::/64"
                            "private-b": "fd00:1234:5678:0101::/64"
                            "private-c": "fd00:1234:5678:0102::/64"
                            "public-a": "fd00:1234:5678:0000::/64"
                            "public-b": "fd00:1234:5678:0001::/64"
                            "public-c": "fd00:1234:5678:0002::/64"
                        }
                    }
                }
            ]
        }
    }
]

items = _items
