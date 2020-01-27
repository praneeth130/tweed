Stencil Contract Documentation
==============================

<div style="background-color: #0067ac; color: #fff; font-weight:
bold; padding: 1em; border-radius: 1em;">
<p>THIS IS A WORK IN PROGRESS.</p>
<p>The information contained in this document is not currently
considered binding or in force for any implementation.</p>
</div>

This document describes the complete specification for Tweed
Stencil OCI Images, and what command invocations they need to
implement to be usable by the Tweed Data Services Broker.

This is `v1` of the Tweed Stencil OCI Image Contract.

This contract defines the following operations:

  - metadata
  - provision
  - bind
  - unbind
  - deprovision

A Stencil OCI Image will be invoked for each of these operations,
by supplying one of the following string tokens as an argument to
the image entrypoint:

  - `metadata` - The stencil image must emit metadata about
    itself, including authorship, versioning, summary and
    descriptive text, and a list of files that the `provision`
    operation will produce.

  - `provision` - The stencil image must attempt to provision an
    instance of the service, given the rest of the configuration.

  - `bind` - The stencil image must attempt to create or retrieve
    a set of credentials for the provisioned service instance.

  - `unbind` - The stencil image must attempt to destroy a set of
    previously created credentials (via a previous `bind`
    operation) for the provisioned service instance.

  - `deprovision` - The stencil image must attempt to decomission
    and tear down a deployed service instance, and (if possible)
    remove all bound credential sets.


## The 'metadata' Operation

The `metadata` operation inherits the following environment:

  - `$HOME` - Will be set a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

The standard error stream will be logged by the Tweed broker, for
review later by interested operators.

The standard output stream will be interpreted as a YAML document,
which properly identifies the stencil image as a valid Tweed
stencil image, with the following structure:

```
---
tweed:   v1             # version of the Tweed API contract
name:    Redis Cluster  # human-friendly stencil name
version: 1.2.3          # version of this stencil implementation

infrastructures:        # what infrastructure types does this
  - bosh                # stencil support being deployed to?

# what files might the various operations create?
files:
  - filename: out.yml                    # relative to $OUTPUTS
    summary:  Kubernetes Resource YAML
    description: |
      This is a longer description of the file, explaining
      what it contains, why it exists, etc.  This will be
      shown to Tweed operators in the user interface.

inputs:
  # JSON Schema for the custom parameters that can be set
  # by operators and (if allowed by operators) end users.
  #
  persistent:
    type: boolean
    description: 
      Make the Redis storage persistent, instead of ephemeral.
```

If the `metadata` operation does not exit 0, the stencil image as
a whole will be considered invalid.

If the `metadata` operation does not produce well-formed and
semantically correct YAML, Tweed will likewise consider the the
stencil image as a whole invalid.


## The 'provision' Operation

The `provision` operation inherits the following environment:

  - `$HOME` - Will be set a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

  - `$INFRASTRUCTURE` - What type of backing infrastructure
    this instance ought to be deployed to. One of either `bosh`,
    or `kubernetes`.

    If set to `bosh`, the following additional environment
    variables will also be set up:

      - `$BOSH_ENVIRONMENT` - The URL of the BOSH director.
      - `$BOSH_CA_CERT` - The contents of the X.509 Certificate
        Authority certificate for validating the BOSH director's
        TLS certificate.
      - `$BOSH_CLIENT` - The UAA client ID for authenticating
        to the BOSH director.
      - `$BOSH_CLIENT_SECRET` - The UAA client secret for
        authenticating to the BOSH director.
      - `$BOSH_DEPLOYMENT` - The name of the deployment to create.

    These additional environment variables are intended to wrap up
    all of the necessary information for interacting with the
    targeted BOSH director, without any additional involvement of
    the stencil image.

    If `$INFRASTRUCTURE` is set to `kubernetes`, Tweed will
    bind-mount in a valid kubeconfig at `$HOME/.kube/config` (the
    default location).  This kubeconfig will have the
    authentication parameters, default context, and namespace set
    such that tools like `kubectl` will work without additional
    configuration or command-line parameters.

  - `$CREDSTORE` - A path to a directory into which a stencil
    container should write any sensitive credentials to be
    retained across execution of stencil operations, for a single
    instance.

    For example: a MySQL stencil deploys with a
    randomly-generated root password.  The stencil image is
    responsible for generating said password, and may store
    that in the file `$CREDSTORE/root.password`.  Subsequent
    operations on the same instance will then be able to access
    that file to retrieve the random password, for purposes of
    bind / unbind / deprovision / etc.

    This mountpoint supports arbitrarily nested directories, for
    organization of binding credentials, etc.  There is a limited
    amount of available space (octets) for storing credentials in
    the `$CREDSTORE` fs hierarchy; any attempt to exceed this
    limitation will result in an IO failure.

    The exact `$CREDSTORE` mountpoint is unspecified, may change
    in future revisions of Tweed, but is guaranteed to reside
    under the reserved `/tweed` top-level directory.

  - `$INPUTS` - The input JSON file, containing parameters set by
    both the Tweed operator (via catalog configuration) and by the
    user requesting the service instance (via parameters).  This
    file is read-only.

    The exact `$INPUTS` path is unspecified, may change
    in future revisions of Tweed, but is guaranteed to reside
    under the reserved `/tweed` top-level directory.

  - `$OUTPUTS` - A directory, bind-mounted into the stencil
    container by Tweed, in which the stencil container is expected
    to put its output files, i.e. Kubernetes resource YAMLs or
    BOSH deployment manifests.

    The nature and disposition of these files is entirely up to
    the stencil author, but must be communicated via the
    `metadata` operation.

    The exact `$OUTPUTS` path is unspecified, may change
    in future revisions of Tweed, but is guaranteed to reside
    under the reserved `/tweed` top-level directory.

The standard output and standard error streams will be multiplexed
together (i.e. `2>&1`) and collected by the Tweed broker for
storage in its database, for retrieval later by interested
operators.  No structured information should be emitted to these
two stream; they are intended explicitly for debugging and
diagnostic use -- Tweed will NOT interpret them in any way.

If the `provision` operation does not exit 0, Tweed will mark the
service instance as failed, and retain logs for operators to
review.


## The 'bind' Operation

The `bind` operation inherits the following environment:

  - `$HOME` - Will be set a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

  - `$INFRASTRUCTURE` - What type of backing infrastructure
    this instance was deployed. One of either `bosh`, or
    `kubernetes`.

    If set to `bosh`, the following additional environment
    variables will also be set up:

      - `$BOSH_ENVIRONMENT` - The URL of the BOSH director.
      - `$BOSH_CA_CERT` - The contents of the X.509 Certificate
        Authority certificate for validating the BOSH director's
        TLS certificate.
      - `$BOSH_CLIENT` - The UAA client ID for authenticating
        to the BOSH director.
      - `$BOSH_CLIENT_SECRET` - The UAA client secret for
        authenticating to the BOSH director.
      - `$BOSH_DEPLOYMENT` - The name of the deployment to create.

    These additional environment variables are intended to wrap up
    all of the necessary information for interacting with the
    targeted BOSH director, without any additional involvement of
    the stencil image.

    If `$INFRASTRUCTURE` is set to `kubernetes`, Tweed will
    bind-mount in a valid kubeconfig at `$HOME/.kube/config` (the
    default location).  This kubeconfig will have the
    authentication parameters, default context, and namespace set
    such that tools like `kubectl` will work without additional
    configuration or command-line parameters.

  - `$CREDSTORE` - A path to a directory from which the stencil
    container can read any credentials created by other operations
    (namely, `provision`), for this instance.

    This mount is read-only, and cannot be modified during the
    `bind` operation.

    For example: a MySQL stencil sets the root password during a
    `provision` operation.  A subsequent `bind` can then read that
    randomly-generated root password, to connect to the database
    server and provision an additional user for the bind.

    The exact `$CREDSTORE` mountpoint is unspecified, may change
    in future revisions of Tweed, but is guaranteed to reside
    under the reserved `/tweed` top-level directory.

The standard error stream will be collected by the Tweed broker,
for storage in its database, for retrieval later by interested
operators.  No structured information should be emitted to these
two stream; they are intended explicitly for debugging and
diagnostic use -- Tweed will NOT interpret them in any way.

The standard output stream will be interpreted as a YAML document,
which fully and completely represents the necessary information to
connect to the provisioned instance, as a unique user if possible.

Syntactically, the output YAML document must consist of a map /
object, i.e.:

```
---
username: foo
password: sekrit
port: 1234
host: 10.0.0.1
hosts:
  - 10.0.0.1
  - 10.0.0.2
  - 10.0.0.3
```

etc.

The exact semantics of the YAML structure are left to the stencil
author to document and communicate to end users.

If the `bind` operation does not exit 0, Tweed will consider the
bind a failure, and will NOT store any generated credentials.

If the `bind` operation does not emit well-formed YAML, Tweed will
also consider the bind a failure and not store credentials.


## The 'unbind' Operation

The `unbind` operation inherits the following environment:

  - `$HOME` - Will be set a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

  - `$INFRASTRUCTURE` - What type of backing infrastructure
    this instance was deployed. One of either `bosh`, or
    `kubernetes`.

    If set to `bosh`, the following additional environment
    variables will also be set up:

      - `$BOSH_ENVIRONMENT` - The URL of the BOSH director.
      - `$BOSH_CA_CERT` - The contents of the X.509 Certificate
        Authority certificate for validating the BOSH director's
        TLS certificate.
      - `$BOSH_CLIENT` - The UAA client ID for authenticating
        to the BOSH director.
      - `$BOSH_CLIENT_SECRET` - The UAA client secret for
        authenticating to the BOSH director.
      - `$BOSH_DEPLOYMENT` - The name of the deployment to create.

    These additional environment variables are intended to wrap up
    all of the necessary information for interacting with the
    targeted BOSH director, without any additional involvement of
    the stencil image.

    If `$INFRASTRUCTURE` is set to `kubernetes`, Tweed will
    bind-mount in a valid kubeconfig at `$HOME/.kube/config` (the
    default location).  This kubeconfig will have the
    authentication parameters, default context, and namespace set
    such that tools like `kubectl` will work without additional
    configuration or command-line parameters.

  - `$CREDSTORE` - A path to a directory from which the stencil
    container can read any credentials created by other operations
    (namely, `provision`), for this instance.

    This mount is read-only, and cannot be modified during the
    `unbind` operation.

    For example: a MySQL stencil sets the root password during a
    `provision` operation.  A subsequent `bind` can then read that
    randomly-generated root password, to connect to the database
    server and provision an additional user for the bind.

    The exact `$CREDSTORE` mountpoint is unspecified, may change
    in future revisions of Tweed, but is guaranteed to reside
    under the reserved `/tweed` top-level directory.

  - `$BINDING` - A path to a file containing the JSON-ified
    version of the output of the previous `bind` operation that
    this `unbind` is intended to reverse.

    This mount is read-only, and cannot be modified during the
    `unbind` operation.

    The exact `$BINDING` mountpoint is unspecified, may change
    in future revisions of Tweed, but is guaranteed to reside
    under the reserved `/tweed` top-level directory.

The standard output and standard error streams will be multiplexed
together (i.e. `2>&1`) and collected by the Tweed broker for
storage in its database, for retrieval later by interested
operators.  No structured information should be emitted to these
two stream; they are intended explicitly for debugging and
diagnostic use -- Tweed will NOT interpret them in any way.

If the `unbind` operation does not exit 0, Tweed will consider the
unbind a failure, and will continue to consider the binding as
valid and usable.


## The 'deprovision' Operation

The `deprovision` operation inherits the following environment:

  - `$HOME` - Will be set a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

  - `$INFRASTRUCTURE` - What type of backing infrastructure
    this instance ought to be deployed to. One of either `bosh`,
    or `kubernetes`.

    If set to `bosh`, the following additional environment
    variables will also be set up:

      - `$BOSH_ENVIRONMENT` - The URL of the BOSH director.
      - `$BOSH_CA_CERT` - The contents of the X.509 Certificate
        Authority certificate for validating the BOSH director's
        TLS certificate.
      - `$BOSH_CLIENT` - The UAA client ID for authenticating
        to the BOSH director.
      - `$BOSH_CLIENT_SECRET` - The UAA client secret for
        authenticating to the BOSH director.
      - `$BOSH_DEPLOYMENT` - The name of the deployment to create.

    These additional environment variables are intended to wrap up
    all of the necessary information for interacting with the
    targeted BOSH director, without any additional involvement of
    the stencil image.

    If `$INFRASTRUCTURE` is set to `kubernetes`, Tweed will
    bind-mount in a valid kubeconfig at `$HOME/.kube/config` (the
    default location).  This kubeconfig will have the
    authentication parameters, default context, and namespace set
    such that tools like `kubectl` will work without additional
    configuration or command-line parameters.

  - `$CREDSTORE` - A path to a directory into which a stencil
    container should write any sensitive credentials to be
    retained across execution of stencil operations, for a single
    instance.

    For example: a MySQL stencil deploys with a
    randomly-generated root password.  The stencil image is
    responsible for generating said password, and may store
    that in the file `$CREDSTORE/root.password`.  Subsequent
    operations on the same instance will then be able to access
    that file to retrieve the random password, for purposes of
    bind / unbind / deprovision / etc.

    This mountpoint supports arbitrarily nested directories, for
    organization of binding credentials, etc.  There is a limited
    amount of available space (octets) for storing credentials in
    the `$CREDSTORE` fs hierarchy; any attempt to exceed this
    limitation will result in an IO failure.

    The exact `$CREDSTORE` mountpoint is unspecified, may change
    in future revisions of Tweed, but is guaranteed to reside
    under the reserved `/tweed` top-level directory.

  - `$INPUTS` - The input JSON file, containing parameters set by
    both the Tweed operator (via catalog configuration) and by the
    user requesting the service instance (via parameters).  This
    file is read-only.

    The exact `$INPUTS` path is unspecified, may change
    in future revisions of Tweed, but is guaranteed to reside
    under the reserved `/tweed` top-level directory.


The standard output and standard error streams will be multiplexed
together (i.e. `2>&1`) and collected by the Tweed broker for
storage in its database, for retrieval later by interested
operators.  No structured information should be emitted to these
two stream; they are intended explicitly for debugging and
diagnostic use -- Tweed will NOT interpret them in any way.

If the `deprovision` operation does not exit 0, Tweed will
continue to consider the instance as valid, and allow bind,
unbind and deprovision operations to be run against it.
