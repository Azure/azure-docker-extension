# Maintainer’s Guide

## Publishing a new version **manually**

:warning: We use the internal EDP (Extension Deployment Pipeline) for releasing
new versions.

:warning: You are recommended to use EDP instead of the instructions here.

### Prerequisites

Make sure: 
* you have access to the subscription that has publishing this extension.
* you have a subscription management certificate in `.pem` format for that.
* you installed `azure-extensions-cli` (and it `list-versions` command works)

### 0. Bump the version number

You need to update `metadata/manifest.xml` with the new version number that
you should document in `README.md` Changelog section and push that change upstream.

### 1. Build and pack

Run `make bundle` to build an extension handler zip package in the `bundle/` directory.

### 2. Upload the package

Extension follows the semantic versioning [MAJOR].[MINOR].[PATCH]. The MAJOR/MINOR
are stored in the `Makefile` and PATCH is the UTC build date of the bundle in `yymmddHHMM`
format.

* **Bump `MAJOR` if**: you are introducing breaking changes in the config schema
* **Bump `MINOR` if**: you are adding new features (no need for hotfixes or minor nits)

Run `azure-extensions-cli new-extension-manifest` with the values in
`metadata/manifest.xml` to upload the package and create a manifest XML. Save the output
of this program to a file (e.g. `/tmp/manifest.xml`).

### 3. Publish new version

Publishing takes 3 steps and you will use the `azure-extensions-cli` program.

#### 3.1. Publish to Slice 1

“Slice 1” means you publish the extension internally only to your own publisher subscription:

    export SUBSCRIPTION_ID=[...]
    export SUBSCRIPTION_CERT=[...].pem
    azure-extensions-cli new-extension-version --manifest [path-to-manifest]

Then check its replication status using:
 
    azure-extensions-cli replication-status --namespace Microsoft.Azure.Extensions \
        --name DockerExtension --version <VERSION>

or `azure-extensions-cli list-versions` command.

Based on the load on PIR it may take from 10 minutes to 10 hours to replicate.

#### 3.2. Integration Tests

After the extension is listed as replicated, you can run integration tests to deploy the extension
to some images and test it is actually working.

For that, make sure you have install `azure` xplat CLI installed and `azure login` is completed.

Then run:

    ./integration-test/test.sh

The tests will:

1. Create test VMs with various distro images in test subscription.
2. Add extension to the VMs with a config that exercises the features.
3. Verify the correct version of the extension is landed to VMs.
4. Verify connectivity to docker-engine with TLS certs.
5. Verify other configuration is taking effect (containers are created etc.)
6. Tear down the test VMs.

If the test gets stuck in a verification step and keeps printing `...`s for more than 5 minutes,
it is very likely something is going badly. You can ssh into the VM (command is printed in the test
output) and see what is going on.

(If you want to delete the buggy version, use `azure-extensions-cli delete-version` at this step.)

#### 3.3. Publish to Slice 2

“Slice 2” means you publish the extension publicly to one Azure PROD region:

    azure-extensions-cli promote-single-region --region-1 'Brazil South' --manifest <FILE>

and then you can use `azure-extensions-cli replication-status` to see it completed.

#### 3.4. Publish to Slice 3

Same as “Slice 2”, but publishes to **two** Azure PROD regions.

    azure-extensions-cli promote-two-regions --region-1 'Brazil South' --region-2 'Southeast Asia' \
        --manifest <FILE>

#### 3.5. Publish to Slice 4

This step publishes the VM extension to **all Azure PROD regions** (be careful).

    azure-extensions-cli promote-all-regions --manifest <FILE>

Wait for it to be completed using `azure-extensions-cli replication-status` command and 
once completed, run `azure vm extension list --json` command from a subscription that is not a publisher
subscription to verify if the new version is available (not applicable for hotfixes).

### 4. Take a code snapshot

Once the version is successful and works in Production:

1. Document the changes in README.md “Changelog” section
2. Commit the changes to your own fork
3. End a pull request to Azure repo
4. Create a tag with the version number you published e.g.:

    git tag 1.0.1506041803
    git push --tags

This will create a snapshot of the code in “releases” section of the GitHub repository.
