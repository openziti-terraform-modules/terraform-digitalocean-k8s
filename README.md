# Terraform Modules for Managing zrok in Kubernetes

This version of the plan for zrok needs a few things to run in Kubernetes.

* A Kubernetes cluster with a load balancer provider
* a controller for `ingressClass: nginx`
* a certificate issuer with DNS challenge solver to support wildcard certificates 

These modules create a dedicated Ziti network for zrok. You could use the same network for other Ziti services, but it's best for Ziti and zrok to share a life cycle to avoid manually cleaning up the network if you decide to reset zrok.
