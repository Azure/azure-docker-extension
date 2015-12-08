# Maintainer’s Guide

## Publishing a new version

### 1. Build and pack

Make the code changes and run `make bundle`.

This will compile and create the extension handler zip package to `bundle/` directory.

### 2. Bump the version (except hotfixes)

Extension follows the semantic versioning [MAJOR].[MINOR].[PATCH]. The MAJOR/MINOR
are stored in the `Makefile` and PATCH is the build date of the bundle in `yymmddHHMM`
format.

* **Bump `MAJOR` if**: you are introducing breaking changes in the config schema
* **Bump `MINOR` if**: you are adding new features (no need for hotfixes or minor nits)

You need to edit `Makefile` if you need to change those version numbers. When the
extension published, the version would look like `1.0.1506041803`.

Update to... | Applied to VM when...
------------- | -------------
PATCH  | The VM reboots
MINOR  | The VM reboots, if the user has opted in for them (e.g. specified version as `1.*`)
MAJOR  | Never, unless user redeploys the extension with the new version number.

### 3. Publish to Production

Publishing takes 4 steps and all can be done using `make` commands.

Make sure you have the service management certificate for the publishing subscription in PEM format
before going through these commands.

#### 3.1. Publish to Slice 1

“Slice 1” means you publish the extension internally only to your own publisher subscription
(hardcoded in Makefile). Use `make publish` to do this. It will upload the package to
blob storage, will publish the extension.

Once you see “HTTP 202 Accepted” in the response, run `make replicationstatus` and wait until
the version is replicated to all regions. (It should say `<Status>Completed</Status>` on all regions.)

Based on the load on PIR it may take from 10 minutes to 10 hours to replicate.

#### 3.2. Integration Tests

After the extension is listed as replicated, you can run integration tests to deploy the extension
to some images and test it is actually working.

For that, make sure you have install `azure` CLI installed and `azure login` is completed.

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

(If you want to delete the buggy version, use `make deleteversion` at this step.)

#### 3.3. Publish to Slice 2

“Slice 2” means you publish the extension publicly to one Azure PROD  region. The region is hardcoded in
`Makefile` (preferably a less used region). Run `make slice2` to publish it. This may take a few minutes,
watch the status with `make listversions` (watch for the `<Regions>` and `<IsInternal>false</IsInternal>`.

#### 3.4. Publish to Slice 3

Same as “Slice 2”, but publishes to one more Azure PROD region. Run `make slice3` and watch result using
`make listversions`.

#### 3.5. Publish to Slice 4

This step publishes the VM extension to **all Azure PROD regions** (be careful).
Run `make slice4` and watch result using `make listversions`.

Once completed, run `azure vm extension list --json` command from a subscription that is not a publisher
subscription to verify if the new version is available (not applicable for hotfixes).

### 4. Take a code snapshot

Once the version is successful and works in Production:

1. Document the changes in README.md “Changelog” section
2. Commit the changes ti your own fork
3. End a pull request to Azure repo
4. Create a tag with the version number you published e.g.:

    git tag 1.0.1506041803
    git push --tags

This will create a snapshot of the code in “releases” section of the GitHub repository.
