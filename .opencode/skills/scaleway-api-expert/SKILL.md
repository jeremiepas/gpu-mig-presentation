---
name: scaleway-api-expert
description: Expert in Scaleway REST API - manage resources programmatically via HTTP calls with Rust scripts
license: MPL-2.0
compatibility: opencode
metadata:
  audience: developers
  workflow: infrastructure
  version: 1.0.0
---

## What I do
- Make authenticated API calls to Scaleway using the REST API
- Understand and implement zoned, regional, and global API patterns
- Work with all major Scaleway products (Instance, K8s, Object Storage, Block Storage, IAM, etc.)
- Create Rust scripts to interact with Scaleway API using reqwest or ureq
- Handle authentication, error handling, and pagination

## Authentication

### Environment Variables Required
```bash
export SCW_ACCESS_KEY="your-access-key"
export SCW_SECRET_KEY="your-secret-key"
export SCW_PROJECT_ID="your-project-id"
```

### API Key Setup
1. Create an API key from Scaleway Console > IAM > API Keys
2. The secret part of the key is used as `X-Auth-Token` header
3. Ensure the associated IAM policy has permissions for desired resources

### Alternative: Pass Header Directly
```rust
let client = reqwest::Client::new();
let response = client
    .get("https://api.scaleway.com/instance/v1/zones/fr-par-2/servers")
    .header("X-Auth-Token", "your-secret-key")
    .send()
    .await?;
```

## API Structure

### Base Endpoint
```
https://api.scaleway.com
```

### URL Patterns

| Type | Pattern | Example |
|------|---------|---------|
| Zoned | `/\{product\}/\{version\}/zones/\{zone\}/\{object\}...` | `/instance/v1/zones/fr-par-2/servers` |
| Regional | `/\{product\}/\{version\}/regions/\{region\}/\{object\}...` | `/k8s/v1/regions/fr-par/clusters` |
| Global | `/\{product\}/\{version\}/\{object\}...` | `/iam/v1/api-keys` |

### Products (API Names)
- `instance` - Instances, IPs, images, volumes, snapshots
- `k8s` - Kubernetes clusters and pools
- `s3` - Object Storage buckets
- `block` - Block Storage volumes
- `lb` - Load Balancers
- `iam` - IAM users, API keys, policies
- `billing` - Invoices, consumption
- `rdb` - Managed Databases
- `serverless` - Containers, Functions, Jobs
- `registry` - Container Registry
- `vpc` - VPC networks andPrivate Networks
- `secret` - Secret Manager
- `function` - Serverless Functions

### Regions and Zones
- `fr-par` (zones: fr-par-2, fr-par-2, fr-par-3) - Paris
- `nl-ams` (zones: nl-ams-1, nl-ams-2, nl-ams-3) - Amsterdam
- `pl-waw` (zones: pl-waw-1, pl-waw-2, pl-waw-3) - Warsaw

## Rust Script Examples

### Prerequisites
Add to Cargo.toml:
```toml
[dependencies]
reqwest = { version = "0.11", features = ["json", "rustls-tls"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tokio = { version = "1", features = ["full"] }
anyhow = "1.0"
```

### 1. List All Instances in a Zone

```rust
use reqwest::Client;
use serde::Deserialize;
use std::env;

#[derive(Debug, Deserialize)]
struct ServerListResponse {
    servers: Vec<Server>,
}

#[derive(Debug, Deserialize)]
struct Server {
    id: String,
    name: String,
    state: String,
    #[serde(rename = "commercialType")]
    commercial_type: String,
    zone: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let token = env::var("SCW_SECRET_KEY")?;
    let zone = "fr-par-2";

    let client = Client::new();
    let response = client
        .get(&format!(
            "https://api.scaleway.com/instance/v1/zones/{}/servers",
            zone
        ))
        .header("X-Auth-Token", &token)
        .send()
        .await?;

    if !response.status().is_success() {
        let status = response.status();
        let body = response.text().await?;
        anyhow::bail!("API error {}: {}", status, body);
    }

    let result: ServerListResponse = response.json().await?;

    for server in result.servers {
        println!("{} ({}): {} - {}", server.id, server.name, server.commercial_type, server.state);
    }

    Ok(())
}
```

### 2. Create a New Instance

```rust
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::env;

#[derive(Debug, Serialize)]
struct CreateServerRequest {
    name: String,
    #[serde(rename = "commercialType")]
    commercial_type: String,
    image: String,
    #[serde(rename = "bootType")]
    boot_type: String,
}

#[derive(Debug, Deserialize)]
struct CreateServerResponse {
    server: Server,
}

#[derive(Debug, Deserialize)]
struct Server {
    id: String,
    name: String,
    private_ip: Option<String>,
    public_ip: Option<String>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let token = env::var("SCW_SECRET_KEY")?;
    let zone = "fr-par-2";

    let request = CreateServerRequest {
        name: "my-rust-instance".to_string(),
        commercial_type: "DEV1-S".to_string(),
        image: "ubuntu_jammy".to_string(),
        boot_type: "local".to_string(),
    };

    let client = Client::new();
    let response = client
        .post(&format!(
            "https://api.scaleway.com/instance/v1/zones/{}/servers",
            zone
        ))
        .header("X-Auth-Token", &token)
        .json(&request)
        .send()
        .await?;

    let result: CreateServerResponse = response.json().await?;

    println!("Created server: {}", result.server.id);
    println!("Private IP: {:?}", result.server.private_ip);
    println!("Public IP: {:?}", result.server.public_ip);

    Ok(())
}
```

### 3. Create S3 Bucket (Object Storage)

```rust
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::env;

#[derive(Debug, Serialize)]
struct CreateBucketRequest {
    name: String,
    #[serde(rename = "endpoint")]
    endpoint: String,
    #[serde(rename = "region")]
    region: String,
}

#[derive(Debug, Deserialize)]
struct BucketResponse {
    id: String,
    name: String,
    region: String,
    #[serde(rename = "endpoint")]
    endpoint: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let token = env::var("SCW_SECRET_KEY")?;
    let region = "fr-par";
    let bucket_name = "my-rust-bucket-12345";

    let request = CreateBucketRequest {
        name: bucket_name.to_string(),
        endpoint: format!("https://s3.{}.scw.cloud", region),
        region: region.to_string(),
    };

    let client = Client::new();
    let response = client
        .post("https://api.scaleway.com/s3/v1/regions/fr-par/buckets")
        .header("X-Auth-Token", &token)
        .header("Content-Type", "application/json")
        .json(&request)
        .send()
        .await?;

    let result: BucketResponse = response.json().await?;

    println!("Created bucket: {}", result.name);
    println!("Endpoint: {}", result.endpoint);

    Ok(())
}
```

### 4. List Kubernetes Clusters

```rust
use reqwest::Client;
use serde::Deserialize;
use std::env;

#[derive(Debug, Deserialize)]
struct ClusterListResponse {
    clusters: Vec<Cluster>,
}

#[derive(Debug, Deserialize)]
struct Cluster {
    id: String,
    name: String,
    region: String,
    version: String,
    status: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let token = env::var("SCW_SECRET_KEY")?;
    let region = "fr-par";

    let client = Client::new();
    let response = client
        .get(&format!(
            "https://api.scaleway.com/k8s/v1/regions/{}/clusters",
            region
        ))
        .header("X-Auth-Token", &token)
        .send()
        .await?;

    let result: ClusterListResponse = response.json().await?;

    for cluster in result.clusters {
        println!("{} ({}): v{} - {}", cluster.id, cluster.name, cluster.version, cluster.status);
    }

    Ok(())
}
```

### 5. List IAM API Keys

```rust
use reqwest::Client;
use serde::Deserialize;
use std::env;

#[derive(Debug, Deserialize)]
struct ApiKeyListResponse {
    api_keys: Vec<ApiKey>,
}

#[derive(Debug, Deserialize)]
struct ApiKey {
    id: String,
    #[serde(rename = "accessKey")]
    access_key: String,
    #[serde(rename = "userID")]
    user_id: String,
    #[serde(rename = "creationDate")]
    creation_date: String,
    #[serde(rename = "expireAt")]
    expire_at: Option<String>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let token = env::var("SCW_SECRET_KEY")?;

    let client = Client::new();
    let response = client
        .get("https://api.scaleway.com/iam/v1/api-keys")
        .header("X-Auth-Token", &token)
        .send()
        .await?;

    let result: ApiKeyListResponse = response.json().await?;

    for key in result.api_keys {
        println!("{}: {}", key.id, key.access_key);
        println!("  Created: {}", key.creation_date);
        println!("  Expires: {:?}", key.expire_at);
    }

    Ok(())
}
```

### 6. Generic API Client (Reusable Pattern)

```rust
use reqwest::Client;
use serde::{de::DeserializeOwned, Serialize};
use std::env;

pub struct ScalewayClient {
    client: Client,
    token: String,
    base_url: String,
}

impl ScalewayClient {
    pub fn new() -> anyhow::Result<Self> {
        let token = env::var("SCW_SECRET_KEY")
            .expect("SCW_SECRET_KEY environment variable must be set");

        Ok(Self {
            client: Client::new(),
            token,
            base_url: "https://api.scaleway.com".to_string(),
        })
    }

    pub async fn get<T: DeserializeOwned>(&self, path: &str) -> anyhow::Result<T> {
        let url = format!("{}{}", self.base_url, path);
        let response = self.client
            .get(&url)
            .header("X-Auth-Token", &self.token)
            .send()
            .await?;

        self.handle_response(response).await
    }

    pub async fn post<T: DeserializeOwned, B: Serialize>(
        &self,
        path: &str,
        body: &B
    ) -> anyhow::Result<T> {
        let url = format!("{}{}", self.base_url, path);
        let response = self.client
            .post(&url)
            .header("X-Auth-Token", &self.token)
            .json(body)
            .send()
            .await?;

        self.handle_response(response).await
    }

    pub async fn delete(&self, path: &str) -> anyhow::Result<()> {
        let url = format!("{}{}", self.base_url, path);
        let response = self.client
            .delete(&url)
            .header("X-Auth-Token", &self.token)
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await?;
            anyhow::bail!("DELETE failed {}: {}", status, body);
        }

        Ok(())
    }

    async fn handle_response<T: DeserializeOwned>(&self, response: reqwest::Response) -> anyhow::Result<T> {
        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await?;
            anyhow::bail!("API error {}: {}", status, body);
        }

        Ok(response.json().await?)
    }
}

// Usage example:
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let scw = ScalewayClient::new()?;

    // List instances
    #[derive(Deserialize)]
    struct Servers { servers: Vec<serde_json::Value> }

    let servers: Servers = scw.get("/instance/v1/zones/fr-par-2/servers").await?;
    println!("Found {} servers", servers.servers.len());

    // Create a volume
    #[derive(Serialize)]
    struct CreateVolumeRequest {
        name: String,
        #[serde(rename = "size")]
        size: u64,
        #[serde(rename = "volumeType")]
        volume_type: String,
    }

    #[derive(Deserialize)]
    struct Volume { id: String }

    let request = CreateVolumeRequest {
        name: "my-volume".to_string(),
        size: 10_000_000_000, // 10GB
        volume_type: "b_ssd".to_string(),
    };

    let volume: Volume = scw.post("/instance/v1/zones/fr-par-2/volumes", &request).await?;
    println!("Created volume: {}", volume.id);

    Ok(())
}
```

## Common Operations Reference

### Instance API (Zonal)
| Operation | Method | Path |
|-----------|--------|------|
| List servers | GET | `/instance/v1/zones/{zone}/servers` |
| Create server | POST | `/instance/v1/zones/{zone}/servers` |
| Get server | GET | `/instance/v1/zones/{zone}/servers/{id}` |
| Delete server | DELETE | `/instance/v1/zones/{zone}/servers/{id}` |
| List IPs | GET | `/instance/v1/zones/{zone}/ips` |
| Create IP | POST | `/instance/v1/zones/{zone}/ips` |
| List volumes | GET | `/instance/v1/zones/{zone}/volumes` |
| Create volume | POST | `/instance/v1/zones/{zone}/volumes` |
| List snapshots | GET | `/instance/v1/zones/{zone}/snapshots` |

### Kubernetes API (Regional)
| Operation | Method | Path |
|-----------|--------|------|
| List clusters | GET | `/k8s/v1/regions/{region}/clusters` |
| Create cluster | POST | `/k8s/v1/regions/{region}/clusters` |
| Get cluster | GET | `/k8s/v1/regions/{region}/clusters/{id}` |
| Delete cluster | DELETE | `/k8s/v1/regions/{region}/clusters/{id}` |
| List pools | GET | `/k8s/v1/regions/{region}/pools` |
| Create pool | POST | `/k8s/v1/regions/{region}/pools` |

### Object Storage API (Regional)
| Operation | Method | Path |
|-----------|--------|------|
| List buckets | GET | `/s3/v1/regions/{region}/buckets` |
| Create bucket | POST | `/s3/v1/regions/{region}/buckets` |
| Delete bucket | DELETE | `/s3/v1/regions/{region}/buckets/{name}` |
| List objects | GET | `/s3/v1/regions/{region}/buckets/{name}/objects` |

### IAM API (Global)
| Operation | Method | Path |
|-----------|--------|------|
| List API keys | GET | `/iam/v1/api-keys` |
| Create API key | POST | `/iam/v1/api-keys` |
| Delete API key | DELETE | `/iam/v1/api-keys/{id}` |
| List policies | GET | `/iam/v1/policies` |
| List users | GET | `/iam/v1/users` |

## Error Handling

### Common Error Codes

| Code | Meaning | Solution |
|------|---------|----------|
| 401 | Unauthorized | Check X-Auth-Token is valid |
| 403 | Forbidden | Check IAM permissions |
| 404 | Not Found | Resource doesn't exist or wrong URL |
| 422 | Validation Error | Check request body format |
| 429 | Rate Limited | Wait and retry |
| 500 | Server Error | Retry later |

### Error Response Format
```rust
#[derive(Debug, Deserialize)]
struct ApiError {
    #[serde(rename = "message")]
    message: String,
    #[serde(rename = "type")]
    error_type: Option<String>,
    #[serde(rename = "fields")]
    fields: Option<serde_json::Value>,
}
```

## Best Practices

1. **Always use environment variables** for credentials - never hardcode
2. **Handle errors gracefully** - check status codes and parse error responses
3. **Use appropriate timeouts** - API calls can take time
4. **Implement retries** with exponential backoff for transient failures
5. **Use pagination** when listing resources - results may be limited
6. **Prefer regional/zonal APIs** over global when possible for better performance
7. **Reuse HTTP client** - create once and reuse for connection pooling

## When to Use This Skill

Use this skill when you need to:
- Programmatic resource management beyond Terraform
- Automate recurring tasks (snapshots, backups)
- Integrate Scaleway into custom tooling
- Build custom dashboards or monitoring
- Query usage and billing data
- Manage IAM resources programmatically
- Create or delete resources as part of CI/CD pipelines
- Test API behavior before implementing in other languages

## Related Skills

- `terraform-scaleway` - For declarative infrastructure management
- `nixos-scaleway-packer` - For creating custom images
