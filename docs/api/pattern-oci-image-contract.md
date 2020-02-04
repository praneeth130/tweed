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
    itself, including authorship, versioning, summary, and
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

For each of these operations, subsequent sections detail the
semantics and purpose of the operation, how it is invoked, what
environment it executes in, how standard input / output / error
streams are handled (and what meaning, if any, is attached to
them), and the interpretation of its exit code.  The following
table summarizes most of those details:

| Operation   | Invocation                | stdin    | stdout           | stderr        |
| ----------- | ------------------------- | -------- | ---------------- | ------------- |
| metadata    | `$entrypoint metadata`    | _closed_ | metadata YAML    | _diagnostics_ |
| provision   | `$entrypoint provision`   | _closed_ | _diagnostics_    | _diagnostics_ |
| bind        | `$entrypoint bind`        | _closed_ | credentials YAML | _diagnostics_ |
| unbind      | `$entrypoint unbind`      | _closed_ | _diagnostics_    | _diagnostics_ |
| deprovision | `$entrypoint deprovision` | _closed_ | _diagnostics_    | _diagnostics_ |


## The 'metadata' Operation

This operation is used by the Tweed broker to interrogate the
pattern image to determine its suitability for use with the
current implementation of Tweed, and to provide additional context
and information to operators wishing to configure and use the
pattern image in a catalog service plan.

### ARGUMENTS

When Tweed wishes to run the `metadata` operation, it will execute
the image's OCI _entrypoint_, passing it a single argument: the
string "metadata".

### ENVIRONMENT

The `metadata` operation inherits the following environment:

  - `$HOME` - Will be set to a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

### STANDARD INPUT

The `metadata` operation will not receive any information via
standard input.  Tweed is free to close the `stdin` stream as its
implementation sees fit.  No guarantees are made about the
contents of this input stream, and backend images are strongly
advised to not read from it.

### STANDARD ERROR

The standard error stream will be logged by the Tweed broker, for
review later by interested operators.  No structured information
should be emitted to these two stream; they are intended
explicitly for debugging and diagnostic use -- Tweed will NOT
interpret them in any way.

### STANDARD OUTPUT

The standard output stream will be interpreted as a YAML document,
which identifies the backend image as a valid Tweed backend image,
using the following structure:

```
---
pattern: tweed/v1       # version of the Tweed API contract
name:    Redis Cluster  # human-friendly pattern name
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

If the `metadata` operation does not produce well-formed and
semantically correct YAML, Tweed will likewise consider the the
pattern image as a whole invalid.

### EXIT CODE

The `metadata` operation exits with status 0 on success.

If the `metadata` operation does not exit 0, the pattern image as
a whole will be considered invalid.


## The 'provision' Operation

This operation is used by the Tweed broker to deploy a new
instance of a catalog service plan, in accordance with Tweed
operator configuration and service requester parameters.

### ARGUMENTS

When Tweed wishes to run the `provision` operation, it will execute
the image's OCI _entrypoint_, passing it a single argument: the
string "provision".

### ENVIRONMENT

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

### STANDARD INPUT

The `provision` operation will not receive any information via
standard input.  Tweed is free to close the `stdin` stream as its
implementation sees fit.  No guarantees are made about the
contents of this input stream, and backend images are strongly
advised to not read from it.

### STANDARD ERROR

The standard error stream (file descriptor 2) is multiplexed into
the standard output stream (file descriptor 1), as if per the
shell idiom `2>&1`.  See the next section for details on how Tweed
interprets the standard output stream.

### STANDARD OUTPUT

The standard output stream is logged by the Tweed broker for
review later by interested operators.  No structured information
should be emitted to these two stream; they are intended
explicitly for debugging and diagnostic use -- Tweed will NOT
interpret them in any way.

### EXIT CODE

The `provision` operation exits with status 0 on success.

If the `provision` operation does not exit 0, Tweed will mark the
service instance as failed, and retain logs for operators to
review.  A subsequent `deprovision` operation may be attempted by
the operator.


## The 'bind' Operation

This operation is used by the Tweed broker to provision
credentials for an existing service instance, for use by a new
application.  Service instances may be bound multiple times, with
each binding standing on its own.

### ARGUMENTS

When Tweed wishes to run the `bind` operation, it will execute
the image's OCI _entrypoint_, passing it a single argument: the
string "bind".

### ENVIRONMENT

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

### STANDARD INPUT

The `bind` operation will not receive any information via
standard input.  Tweed is free to close the `stdin` stream as its
implementation sees fit.  No guarantees are made about the
contents of this input stream, and backend images are strongly
advised to not read from it.

### STANDARD ERROR

The standard error stream will be logged by the Tweed broker, for
review later by interested operators.  No structured information
should be emitted to these two stream; they are intended
explicitly for debugging and diagnostic use -- Tweed will NOT
interpret them in any way.

### STANDARD OUTPUT

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

If the `bind` operation does not emit well-formed YAML, Tweed will
consider the bind a failure and not store credentials.

### EXIT CODE

The `bind` operation exits with status 0 on success.

If the `bind` operation does not exit 0, Tweed will consider the
bind a failure.  The binding itself will be stored, and a
subsequent `unbind` operation against it may be requested by the
service requester.


## The 'unbind' Operation

This operation is used by the Tweed broker to revoke and destroy
any bound credentials associated with a single service instance
binding.  Once a binding has been unbound, it will be forgotten
and should no longer be used.

### ARGUMENTS

When Tweed wishes to run the `unbind` operation, it will execute
the image's OCI _entrypoint_, passing it a single argument: the
string "unbind".

### ENVIRONMENT

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

### STANDARD INPUT

The `unbind` operation will not receive any information via
standard input.  Tweed is free to close the `stdin` stream as its
implementation sees fit.  No guarantees are made about the
contents of this input stream, and backend images are strongly
advised to not read from it.

### STANDARD ERROR

The standard error stream (file descriptor 2) is multiplexed into
the standard output stream (file descriptor 1), as if per the
shell idiom `2>&1`.  See the next section for details on how Tweed
interprets the standard output stream.

### STANDARD OUTPUT

The standard output stream is logged by the Tweed broker for
review later by interested operators.  No structured information
should be emitted to these two stream; they are intended
explicitly for debugging and diagnostic use -- Tweed will NOT
interpret them in any way.

### EXIT CODE

The `unbind` operation exits with status 0 on success.

If the `unbind` operation does not exit 0, Tweed will consider the
unbind a failure, and will continue to consider the binding as
valid and usable.


## The 'deprovision' Operation

This operation is used by the Tweed broker to decommission and
tear down a previously provisioned service instance.  Tweed makes
no guarantee that all extant bindings for a service instance have
been unbound before `deprovision` is called against that instance.

### ARGUMENTS

When Tweed wishes to run the `deprovision` operation, it will execute
the image's OCI _entrypoint_, passing it a single argument: the
string "deprovision".

### ENVIRONMENT

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

### STANDARD INPUT

The `deprovision` operation will not receive any information via
standard input.  Tweed is free to close the `stdin` stream as its
implementation sees fit.  No guarantees are made about the
contents of this input stream, and backend images are strongly
advised to not read from it.

### STANDARD ERROR

The standard error stream (file descriptor 2) is multiplexed into
the standard output stream (file descriptor 1), as if per the
shell idiom `2>&1`.  See the next section for details on how Tweed
interprets the standard output stream.

### STANDARD OUTPUT

The standard output stream is logged by the Tweed broker for
review later by interested operators.  No structured information
should be emitted to these two stream; they are intended
explicitly for debugging and diagnostic use -- Tweed will NOT
interpret them in any way.

### EXIT CODE

The `deprovision` operation exits with status 0 on success.

If the `deprovision` operation does not exit 0, Tweed will
continue to consider the instance as valid, and allow bind,
unbind and deprovision operations to be run against it.
