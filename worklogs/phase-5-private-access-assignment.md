# Phase 5: Entra Private Access and governed assignment

**Date:** 2026-09-05

**Goal:** Reach Grafana at `10.20.1.63:3000` inside the AWS VPC through Microsoft Entra Private Access, with no VPN, peering, or inbound port.

**Result:** Working. `HTTP/1.1 200 OK`, 49,401 bytes, rendered in the browser.

The client was an Entra-joined Azure VM (`172.16.0.4`) with no network path to AWS, so only the tunnel could carry the request.

![Grafana served from the AWS private subnet to an Azure VM, with ipconfig and curl in the same frame](../docs/images/phase-5-10-grafana-through-private-access.png)

![Invoke-WebRequest returns 200 and 49,401 bytes](../docs/images/phase-5-09-http-200.png)

## Traffic path

```mermaid
flowchart LR
    subgraph Azure["Azure"]
        Client["Windows 11 VM<br/>172.16.0.4<br/>Entra joined, GSA client"]
    end

    subgraph Entra["Microsoft Entra"]
        Edge["Global Secure Access edge<br/>App assignment<br/>and Conditional Access"]
        PA["Private Access service"]
    end

    subgraph VPC["AWS VPC 10.20.0.0/16"]
        subgraph Routed["Routed subnet"]
            Connector["Connector<br/>10.20.0.155<br/>No inbound rule"]
        end
        subgraph Isolated["Isolated subnet"]
            Target["Grafana on Fargate<br/>10.20.1.63:3000"]
        end
    end

    Client -->|"1 Intercept at socket layer"| Edge
    Edge -->|"2 Authorize"| PA
    Connector -.->|"3 Outbound tunnel"| PA
    PA -->|"4 Broker session"| Connector
    Connector -->|"5 TCP 3000"| Target
```

Authorization happens at step 2, before any packet reaches AWS.

## Configuration

| Setting | Value |
| --- | --- |
| Connector group | `aws-access`, one connector, region Europe |
| Enterprise app | `Grafana-AWS` |
| Segment | `10.20.1.63`, TCP 3000 |
| Assigned groups | `AWS-Administrators`, `AWS-Auditors`, `AWS-Developers` |
| Forwarding profile | Private Access, enabled and assigned |

![Connector active inside the aws-access group](../docs/images/phase-5-01-connector-group-active.png)

![Grafana-AWS application with the aws-access connector group and one IP segment](../docs/images/phase-5-02-gsa-application.png)

![Application segment 10.20.1.63, port 3000, TCP, status Success](../docs/images/phase-5-03-app-segment-success.png)

The same SCIM groups carry AWS permission sets, so one membership drives both the AWS role and private app access.

![AWS-Administrators, AWS-Auditors and AWS-Developers assigned to the application](../docs/images/phase-5-04-app-assignments.png)

![Client forwarding profile listing priority 11, 10.20.1.63, TCP 3000, Tunnel](../docs/images/phase-5-08-forwarding-profile-rule.png)

## Troubleshooting

The tenant configuration was correct. The client identity was the problem.

| Symptom | Cause | Fix |
| --- | --- | --- |
| Client stuck at `Signed out` | Windows 11 Home laptop, Entra registered with a personal account. No PRT, so no token or forwarding profile. | Use an Entra-joined VM ([ADR-021](../decisions.md#adr-021-use-an-entra-joined-vm-as-the-private-access-test-client)) |

![Client reporting Signed out with no account, device ID or join type](../docs/images/phase-5-06-client-signed-out.png)

The client logs Event 421 every 60 seconds. The real error is in `Microsoft-Windows-AAD/Operational`:

```text
AADSTS9002341: User is required to permit SSO   (interaction_required)
```

![Client download page listing Microsoft Entra joined as a system requirement](../docs/images/phase-5-05-client-requires-entra-joined.png)

![Client connected to the sindredg organization](../docs/images/phase-5-07-client-connected.png)

## Tips

- **Check the tenant.** The Azure CLI defaulted to another directory and cost two hours. Run `dsregcmd /status` and read `WorkplaceTenantId`.
- **Read segments from the right path.** Use `/applications/{id}/onPremisesPublishing/segmentsConfiguration/microsoft.graph.ipSegmentConfiguration/applicationSegments`. The parent object is always empty.
- **Don't use ping.** Private Access doesn't tunnel ICMP and doesn't add routes. Use an HTTP request.

  ![Ping to the target times out even though HTTP through the tunnel succeeds](../docs/images/phase-5-11-icmp-not-tunnelled.png)

- **Type `http://`.** Edge upgrades a bare `IP:port` to HTTPS.
- **Use the right join link.** Select **Join this device to Microsoft Entra ID**. The main box performs a workplace join, which doesn't work.

## Not completed

- The denial case for an unassigned identity wasn't run.
- The pilot used the administrator account, not the synthetic Joiner.
- Assignment was direct, not through an access package.
