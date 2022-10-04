# Crossplane Workshop

Author: Simon Beck (simon.beck@vshn.ch)

## Requirements
* Kubectl
* Go
* make
* yq
* docker
* GCP credentials.json in root of this repository

== Crossplane Setup

**Enable Cloud SQL Admin API for the project and Compute Engine API**

Install local kind cluster and crossplane:
`make local-setup`

Install stackgres:
`make setup-stackgres`

Install cloudsql with crossplane-provider:

Adjust the GCP project in `crossplane/provider-gcp/providerconfig.yaml` first!

```
export GCP_CREDENTIALS=$(cat credentials.json)
make setup-cloudsql
```

Install cloudsql with terraform-provider

Adjust the GCP project in `crossplane/provider-terraform/providerconfig.yaml` first!

```
export GCP_CREDENTIALS=$(cat credentials.json)
make setup-terraform
```

Remove all instances, compositions, XRDs and providers
`make clean-crossplane`

Completely remove kind cluster
`make clean-kind`
**This will delete the cluster!** Any external cloudsql database will still exist.

## Build slides.html

`make slides.html`

Then just open the html file with a browser.
