# DevOps Openhack Proctor Repository

This repo contains the code for the provisioning of the resources necessary to build the DevSecOps environment needed for the My Health Clinic application.

## Components

The components are organized by folders which contain the following:

* **provision-team** - code to support the provisioning of a complete team environment.
* **provision-vm** - automates the provisioning of an Ubuntu 16.04 VM used as the foundation for provisioning the team and proctor environments.

Go to the root of these folders to see a readme with deeper information on each component.

## Getting Started

### Prerequisites

The first step is to create a virtual machine which has the necessary software installed required to provision the VM needed for the My Health environment.  In order to create the VM, only the following needs to be installed

* Azure PowerShell
* An Azure Subscription

### High-Level Installation Flow

1. [Deploy the My Health Clinic environment](./provision-vm) using the Azure Resource Manager template.
2. [Create a Proctor Environment](./provision-proctor) using the Azure Resource Manager template.

## Resources

For troubleshooting or answers to common questions, please [read the FAQ](FAQ.md).
