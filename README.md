# DevOps Openhack Proctor Repository

This repo contains the code for the provisioning of the resources necessary to build a DevSecOps AKS environment for the My Health Clinic application. This code leverages the DevOps Openhack Team repository (https://github.com/Azure-Samples/openhack-devops-team/).

## Components

The components are organized by folders which contain the following:

* **provision-proctor** - code to support the provisioning of a complete AKS environment.
* **provision-team** - code to support the provisioning of a complete team environment.
* **provision-vm** - automates the provisioning of an Ubuntu 16.04 VM used as the foundation for provisioning the team and proctor environments.
* **simulator** - simulates traffic to the SQL database the APIs use for every team's environment.

Go to the root of these folders to see a readme with deeper information on each component.

## Getting Started

### Prerequisites

The first step is to create a virtual machine which has the necessary software installed required to provision the environments.  In order to create the VM, only the following needs to be installed

* Azure PowerShell
* An Azure Subscription

### High-Level Installation Flow

1. [Deploy a team environment](./provision-vm) using the Azure Resource Manager template.
2. [Create a Proctor Environment](./provision-proctor) using the Azure Resource Manager template.

## Resources

For troubleshooting or answers to common questions, please [read the FAQ](FAQ.md).
