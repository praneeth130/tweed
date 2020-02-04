Backend OCI Image Contract
==========================

<div style="background-color: #0067ac; color: #fff; font-weight:
bold; padding: 1em; border-radius: 1em;">
<p>THIS IS A WORK IN PROGRESS.</p>
<p>The information contained in this document is not currently
considered binding or in force for any implementation.</p>
</div>

This document describes the complete specification for Tweed
Backend OCI Images, and what command invocations they need to
implement to be usable by the Tweed Data Services Broker.

This is `v1` of the Tweed Backend OCI Image Contract.

This contract defines the following operations:

  - metadata
  - configure
  - setup
  - teardown

A Backend OCI Image will be invoked for each of these operations,
by supplying one of the following string tokens as an argument to
the image entrypoint:

  - `metadata` - The backend image must emit metadata about itself,
    including authorship, versioning, summary, and descriptive
    text.

  - `configure` - The backend image must consume operator-supplied
    configuration for a single cloud, validate it, and persist any
    files it will need for future authentication.

  - `check` - The backend image must attempt to utilize only the
    configuration it persisted during the most recent `configure`
    operation to access the remote backend and ensure its
    viability.

  - `setup` - The backend image must set up the disk and
    environment variables for a single interaction with the
    backend system.

  - `teardown` - The backend image must clean up any in-backend
    configuration created by the `setup` operation.  Usually, this
    will be a no-op.

For each of these operations, subsequent sections detail the
semantics and purpose of the operation, how it is invoked, what
environment it executes in, how standard input / output / error
streams are handled (and what meaning, if any, is attached to
them), and the interpretation of its exit code.  The following
table summarizes most of those details:

| Operation | Invocation              | stdin       | stdout        | stderr           |
| --------- | ----------------------- | ----------- | ------------- | ---------------- |
| metadata  | `$entrypoint metadata`  | _closed_    | metadata YAML | _diagnostics_    |
| configure | `$entrypoint configure` | config JSON | _diagnostics_ | _diagnostics_    |
| check     | `$entrypoint check`     | _closed_    | _diagnostics_ | _diagnostics_    |
| setup     | `$entrypoint setup`     | _closed_    | _diagnostics_ | environment YAML |
| teardown  | `$entrypoint teardown`  | _closed_    | _diagnostics_ | _diagnostics_    |


## The 'metadata' Operation

This operation is used by the Tweed broker to interrogate the
backend image to determine its suitability for use with the
current implementation of Tweed, and to provide additional context
and information to operators wishing to configure and use the
backend image in a specific deployment.

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
backend: tweed/v1       # version of the Tweed API contract
name:    Redis Cluster  # human-friendly backend name
version: 1.2.3          # version of this backend implementation

summary: A short summary of the backend and its purpose
description: |
  A longer, markdown-formatted description of this backend,
  what it does, how it is supposed to work, etc.

# a 128x128 PNG icon, for the web user interface
icon:
  base64: <... base64-encoded image data ...>

# copyright notice, for the web and CLI interfaces
copyright: 2020 Some Company, Inc.

# one or more authors for attribution.
authors: 
  - Author Name <author@e.mail>

inputs:
  # JSON Schema for the custom parameters that can be set
  # by operators when configuring this backend.
  #
  persistent:
    type: boolean
    description: 
      Make the Redis storage persistent, instead of ephemeral.
```

If the `metadata` operation does not produce well-formed and
semantically correct YAML, Tweed will likewise consider the the
backend image as a whole invalid.

### EXIT CODE

The `metadata` operation exits with status 0 on success.

If the `metadata` operation does not exit 0, the backend image as
a whole will be considered invalid.


## The 'configure' Operation

This operation is used by the Tweed broker to supply raw
configuration parameters, given to it by the operator(s) who wish
to use this backend implementation as a deployment target for
service plans in the catalog.

### ARGUMENTS

When Tweed wishes to run the `configure` operation, it will execute
the image's OCI _entrypoint_, passing it a single argument: the
string "configure".

### ENVIRONMENT

The `configure` operation inherits the following environment:

  - `$HOME` - Will be set to a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

  - `$OUT_CONFIG` - Will be set to a writable, persistent
    directory that will survive the termination of the container.
    This is where the implementation *must* write any files it
    wishes to persist to future invocations to this directory.

    The exact `$OUT_CONFIG` mountpoint is unspecified, may
    change in future revisions of Tweed, but is guaranteed to
    reside under the reserved `/tweed` top-level directory.

### STANDARD INPUT

Tweed will write the configuration (as supplied by the operator)
to standard input, in JSON format.  The field names will be those
specified in the JSON Schema given by the `metadata` operation's
output.

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

The `configure` operation exits with status 0 on success.

If the `configure` operation does not exit 0, Tweed will consider
the configuration of the backend non-viable, and may prevent
operators from using it in configuration of new service plans.


## The 'check' Operation

This operation is used by the Tweed broker to validate the
configuration persisted by the most recent `configure` operation.

### ARGUMENTS

When Tweed wishes to run the `check` operation, it will execute
the image's OCI _entrypoint_, passing it a single argument: the
string "check".

### ENVIRONMENT

The `check` operation inherits the following environment:

  - `$HOME` - Will be set to a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

  - `$IN_CONFIG` - Will be set to a readonly, persistent
    directory that will survive the termination of the backend
    container.  This is where the backend container *must* write
    any files it wishes to persist to future invocations to this
    directory.

    The exact `$IN_CONFIG` mountpoint is unspecified, may
    change in future revisions of Tweed, but is guaranteed to
    reside under the reserved `/tweed` top-level directory.

### STANDARD INPUT

The `check` operation will not receive any information via
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

The `check` operation exits with status 0 on success.

If the `check` operation does not exit 0, Tweed will consider the
configuration of the backend non-viable, and may prevent operators
from using it in configuration of new service plans.


## The 'setup' Operation

This operation is used by the Tweed broker to configure a
subsequent run of a _pattern container_ to deploy to the
configured backend system.

### ARGUMENTS

When Tweed wishes to run the `setup` operation, it will execute
the image's OCI _entrypoint_, passing it a single argument: the
string "setup".

### ENVIRONMENT

The `setup` operation inherits the following environment:

  - `$HOME` - Will be set to a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

  - `$IN_CONFIG` - Will be set to a readonly directory that
    contains the configuration written by most recent `configure`
    operation.

    The exact `$IN_CONFIG` mountpoint is unspecified, may
    change in future revisions of Tweed, but is guaranteed to
    reside under the reserved `/tweed` top-level directory.

  - `$OUT_CONFIG` - Will be set to a writable, persistent
    directory that will store the configuration generated by
    whatever setup steps the backend author deems appropriate.

    The exact `$OUT_CONFIG` mountpoint is unspecified, may
    change in future revisions of Tweed, but is guaranteed to
    reside under the reserved `/tweed` top-level directory.

### STANDARD INPUT

The `setup` operation will not receive any information via
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
which identifies additional environment variables that Tweed must
inject into the _pattern_ container for it to be able to interact
with the backend.  That YAML must be of the form:

```
ENV_VAR: "Value of Environment Variable"
FOO: bar
```

### EXIT CODE

The `setup` operation exits with status 0 on success.

If the `setup` operation does not exit 0, Tweed will consider the
configuration of the backend non-viable, and will abort any
in-progress operations that were dependent on it.  Of note: the
`teardown` operation will _not_ be called to clean up.


## The 'teardown' Operation

This operation is used by the Tweed broker to clean up any
persisting assets related to authencation that were created by the
previous `setup` operation.

### ARGUMENTS

When Tweed wishes to run the `teardown` operation, it will execute
the image's OCI _entrypoint_, passing it a single argument: the
string "teardown".

### ENVIRONMENT

The `teardown` operation inherits the following environment:

  - `$HOME` - Will be set to a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

  - `$IN_CONFIG` - Will be set to the readonly directory that was
    the `$OUT_CONFIG` of the most recent `setup` operation.  This
    is where the backend container *should* read configuration and
    perform any credential cleanup actions the backend author
    deems appropriate.

    The exact `$IN_CONFIG` mountpoint is unspecified, may
    change in future revisions of Tweed, but is guaranteed to
    reside under the reserved `/tweed` top-level directory.

### STANDARD INPUT

The `teardown` operation will not receive any information via
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

The `teardown` operation exits with status 0 on success.

If the `teardown` operation does not exit 0, Tweed will consider
the teardown of the credentials as failed, and may hold onto the
output of the previous `setup` operation for a subsequent retry of
this `teardown` operation.
