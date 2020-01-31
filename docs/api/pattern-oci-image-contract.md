Pattern OCI Image Contract
==========================

<div style="background-color: #0067ac; color: #fff; font-weight:
bold; padding: 1em; border-radius: 1em;">
<p>THIS IS A WORK IN PROGRESS.</p>
<p>The information contained in this document is not currently
considered binding or in force for any implementation.</p>
</div>

This document describes the complete specification for Tweed
Pattern OCI Images, and what command invocations they need to
implement to be usable by the Tweed Data Services Broker.

This is `v1` of the Tweed Pattern OCI Image Contract.

This contract defines the following operations:

  - metadata
  - provision
  - bind
  - unbind
  - deprovision

A Pattern OCI Image will be invoked for each of these operations,
by supplying one of the following string tokens as an argument to
the image entrypoint:

  - `metadata` - The pattern image must emit metadata about
    itself, including authorship, versioning, summary and
    descriptive text, and a list of files that the `provision`
    operation will produce.

  - `provision` - The pattern image must attempt to provision an
    instance of the service, given the rest of the configuration.

  - `bind` - The pattern image must attempt to create or retrieve
    a set of credentials for the provisioned service instance.

  - `unbind` - The pattern image must attempt to destroy a set of
    previously created credentials (via a previous `bind`
    operation) for the provisioned service instance.

  - `deprovision` - The pattern image must attempt to decomission
    and tear down a deployed service instance, and (if possible)
    remove all bound credential sets.


## The 'metadata' Operation

The `metadata` operation inherits the following environment:

  - `$HOME` - Will be set to a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

The standard error stream will be logged by the Tweed broker, for
review later by interested operators.

The standard output stream will be interpreted as a YAML document,
which properly identifies the pattern image as a valid Tweed
pattern image, with the following structure:

```
---
tweed:   v1             # version of the Tweed API contract
pattern: Redis Cluster  # human-friendly pattern name
version: 1.2.3          # version of this pattern implementation

summary: A short summary of the pattern and its purpose
description: |
  A longer, markdown-formatted description of this pattern,
  what it does, how it is supposed to work, etc.

# a 128x128 PNG icon, for the web user interface
icon:
  base64: <... base64-encoded image data ...>

# copyright notice, for the web and CLI interfaces
copyright: 2020 Some Company, Inc.

# one or more authors for attribution.
authors: 
  - Author Name <author@e.mail>

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

If the `metadata` operation does not exit 0, the pattern image as
a whole will be considered invalid.

If the `metadata` operation does not produce well-formed and
semantically correct YAML, Tweed will likewise consider the the
pattern image as a whole invalid.


## The 'provision' Operation

The `provision` operation inherits the following environment:

  - `$HOME` - Will be set to a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

  - `$CREDSTORE` - A path to a directory into which a pattern
    container should write any sensitive credentials to be
    retained across execution of pattern operations, for a single
    instance.

    For example: a MySQL pattern deploys with a
    randomly-generated root password.  The pattern image is
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

  - `$OUTPUTS` - A directory, bind-mounted into the pattern
    container by Tweed, in which the pattern container is expected
    to put its output files, i.e. Kubernetes resource YAMLs or
    BOSH deployment manifests.

    The nature and disposition of these files is entirely up to
    the pattern author, but must be communicated via the
    `metadata` operation.

    The exact `$OUTPUTS` path is unspecified, may change
    in future revisions of Tweed, but is guaranteed to reside
    under the reserved `/tweed` top-level directory.

The standard output and standard error streams will be multiplexed
together (i.e. `2>&1`) and logged by the Tweed broker for review
later by interested operators.  No structured information should
be emitted to these two stream; they are intended explicitly for
debugging and diagnostic use -- Tweed will NOT interpret them in
any way.

If the `provision` operation does not exit 0, Tweed will mark the
service instance as failed, and retain logs for operators to
review.


## The 'bind' Operation

The `bind` operation inherits the following environment:

  - `$HOME` - Will be set to a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

  - `$CREDSTORE` - A path to a directory from which the pattern
    container can read any credentials created by other operations
    (namely, `provision`), for this instance.

    This mount is read-only, and cannot be modified during the
    `bind` operation.

    For example: a MySQL pattern sets the root password during a
    `provision` operation.  A subsequent `bind` can then read that
    randomly-generated root password, to connect to the database
    server and provision an additional user for the bind.

    The exact `$CREDSTORE` mountpoint is unspecified, may change
    in future revisions of Tweed, but is guaranteed to reside
    under the reserved `/tweed` top-level directory.

The standard output and standard error streams will be multiplexed
together (i.e. `2>&1`) and logged by the Tweed broker for review
later by interested operators.  No structured information should
be emitted to these two stream; they are intended explicitly for
debugging and diagnostic use -- Tweed will NOT interpret them in
any way.

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

The exact semantics of the YAML structure are left to the pattern
author to document and communicate to end users.

If the `bind` operation does not exit 0, Tweed will consider the
bind a failure, and will NOT store any generated credentials.

If the `bind` operation does not emit well-formed YAML, Tweed will
also consider the bind a failure and not store credentials.


## The 'unbind' Operation

The `unbind` operation inherits the following environment:

  - `$HOME` - Will be set to a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

  - `$CREDSTORE` - A path to a directory from which the pattern
    container can read any credentials created by other operations
    (namely, `provision`), for this instance.

    This mount is read-only, and cannot be modified during the
    `unbind` operation.

    For example: a MySQL pattern sets the root password during a
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
together (i.e. `2>&1`) and logged by the Tweed broker for review
later by interested operators.  No structured information should
be emitted to these two stream; they are intended explicitly for
debugging and diagnostic use -- Tweed will NOT interpret them in
any way.

If the `unbind` operation does not exit 0, Tweed will consider the
unbind a failure, and will continue to consider the binding as
valid and usable.


## The 'deprovision' Operation

The `deprovision` operation inherits the following environment:

  - `$HOME` - Will be set to a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

  - `$CREDSTORE` - A path to a directory into which a pattern
    container should write any sensitive credentials to be
    retained across execution of pattern operations, for a single
    instance.

    For example: a MySQL pattern deploys with a
    randomly-generated root password.  The pattern image is
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
together (i.e. `2>&1`) and logged by the Tweed broker for review
later by interested operators.  No structured information should
be emitted to these two stream; they are intended explicitly for
debugging and diagnostic use -- Tweed will NOT interpret them in
any way.

If the `deprovision` operation does not exit 0, Tweed will
continue to consider the instance as valid, and allow bind,
unbind and deprovision operations to be run against it.
