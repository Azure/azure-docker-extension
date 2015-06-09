# Maintainer's Guide

## Publishing a new version

### 1. Build and pack

Make the code changes and run `make bundle`.

This will compile and create the extension handler zip package to `bundle/` directory.

### 2. Bump the version

Extension follows the semantic versioning [MAJOR].[MINOR].[PATCH]. The MAJOR/MINOR
are stored in the `Makefile` and PATCH is the build date of the bundle in `yymmddHHMM`
format.

* **Bump `MAJOR` if**: you're introducing breaking changes in the config schema
* **Bump `MINOR` if**: you're adding new features (no need for hotfixes or minor nits)

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

"Slice 1" means you publish the extension internally only to your own publisher subscription
(hardcoded in Makefile). Use `make publish` to do this. It will upload the package to
blob storage, will publish the extension.

Once you see "HTTP 202 Accepted" in the response, run `make listversions` to see if your version became
`<Status>Completed</Status>` on all regions and wait until it does so. (You can check the replication
status via `make replicationstatus`). Based on the load on PIR it may take between 5 minutes to 10 hours
(based on personal experience).

After the extension is listed as replicated, deploy to a VM using xplat-cli (see User Guide). Until
Slice 2, you cannot specify the version with asterisk (e.g. `1.*`). Once extension makes it to the
VM (you can watch `/var/log/waagent.log`) and works correctly as you expected, proceed.

(If you want to delete the version, use `make deleteversion` at this step.)

#### 3.2. Publish to Slice 2

"Slice 2" means you publish the extension publicly to one Azure PROD  region. The region is hardcoded in
`Makefile` (preferably a less used region). Run `make slice2` to publish it. This may take a few minutes,
watch the status with `make listversions` (watch for the `<Regions>` and `<IsInternal>false</IsInternal>`.

#### 3.3. Publish to Slice 3

Same as ”Slice 2”, but publishes to one more Azure PROD region. Run `make slice3` and watch result using
`make listversions`.

#### 3.4. Publish to Slice 4

This step publishes the VM extension to **all Azure PROD regions** (be careful).
Run `make slice4` and watch result using `make listversions`.

Once completed, run `azure vm extension list --json` command from a subscription that is not a publisher
subscription to verify if the new version is available.

### 4. Take a code snapshot

Once the version is successful and works in Production, document the changes in README.md
“Changelog” section, commit the changes and create a tag with the version number you published e.g.:

    git tag 1.0.1506041803
    git push --tags

This will create a snapshot of the code in “releases” section of the GitHub repository.
