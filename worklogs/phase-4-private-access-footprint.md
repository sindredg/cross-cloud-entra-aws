# Phase 4: Minimal AWS network and private target

**Date:** 2026-09-04

**Goal:** Deploy a private target and a connector host. Prove that only the connector can reach the target.

## Design

```mermaid
flowchart LR
    subgraph VPC["VPC, single AZ"]
        subgraph Routed["Connector subnet"]
            Conn["Windows connector<br/>no inbound rules"]
        end
        subgraph Isolated["Target subnet, no internet route"]
            Task["Grafana<br/>ARM64 Fargate"]
            EP["ecr.api, ecr.dkr, logs<br/>+ S3 gateway endpoints"]
        end
    end
    IGW["Internet gateway"] --- Conn
    Conn -->|"TCP 3000"| Task
    Task --> EP
```

- One Grafana OSS task pulls its image through interface endpoints. See [ADR-019](../decisions.md#adr-019-run-the-private-target-on-arm-fargate-behind-interface-endpoints) and [ADR-020](../decisions.md#adr-020-reuse-grafana-as-an-anonymous-private-target).
- The connector key pair is created outside Terraform, so no private key enters state. Create it before the first apply.

![Key pair created with the AWS CLI, private key written outside the repository](../docs/images/phase-4-01-key-pair-created.png)

![Terraform apply adds 40 resources](../docs/images/phase-4-02-apply-complete.png)

## Build the image

The target can't reach Docker Hub, so the pinned image is mirrored to ECR. The workstation and task are both ARM64.

![docker login fails with "The stub received bad data"](../docs/images/phase-4-03-docker-credential-helper-failure.png)

| Symptom | Cause | Fix |
| --- | --- | --- |
| `docker login` fails: "The stub received bad data" | Docker config names the Windows `desktop.exe` helper, but the engine is native Linux | Use a temporary `DOCKER_CONFIG` for login and delete it on exit |

![Native ARM64 build of the pinned Grafana image](../docs/images/phase-4-04-image-build.png)

![Image layers pushed to the project ECR repository](../docs/images/phase-4-05-image-pushed.png)

![ECR lists the pushed image under the latest tag](../docs/images/phase-4-06-ecr-image-listed.png)

## Validation

The connector is running and the ECS service is steady.

![Connector instance running in eu-north-1a](../docs/images/phase-4-07-connector-instance-running.png)

![ECS cluster with one running task](../docs/images/phase-4-08-ecs-cluster.png)

![Service active with one running task on Fargate](../docs/images/phase-4-09-ecs-service-active.png)

The connector security group has no inbound rules. Outbound rules:

| Port | Destination |
| --- | --- |
| 80, 443 | Microsoft endpoints and CRLs |
| 3000 | Target security group |
| 53 | VPC resolver |
| 123 | Time |
| 1688 | Windows activation |

![Connector security group: no inbound rules, itemised outbound rules](../docs/images/phase-4-10-connector-sg-no-inbound.png)

Only the connector route table reaches the internet gateway. The third route table is the unused VPC default.

![VPC resource map: only the connector route table reaches the internet gateway](../docs/images/phase-4-11-vpc-resource-map.png)

An HTTP request from the connector to the task returned 200. This confirms the VPC route, both security group rules, and Grafana listening on 3000.

![Invoke-WebRequest from the connector to the target returns 200](../docs/images/phase-4-12-connector-reaches-target.png)

## Limits

- The request crossed the VPC directly. It didn't use Global Secure Access.
- `Invoke-WebRequest` follows redirects, so 200 alone doesn't prove anonymous access. Phase 5 confirms it in the browser.
- Fargate assigns a new IP when a task is replaced (`10.20.1.65` became `10.20.1.63`). Check the IP before you create the application segment.
