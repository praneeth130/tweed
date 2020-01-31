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

  - `metadata` - The backend image must emit metadata about itelf,
    including authorship, versioning, summary and descriptive
    text.

  - `configure` - The backend image must consume operator-supplied
    configuration for a single cloud, validate it, and persist any
    files it will need for future authentication attempts.

  - `check` - The backend image must attempt to utilize only the
    configuration it persisted during the most recent `configure`
    operation to access the remote backend and ensure its
    viability.

  - `setup` - Sets up the disk and environment variables for a
    single interaction with the backend system.

  - `teardown` - Cleans up any in-backend configuration created by
    the `setup` operation.  Usually, this will be a no-op.


## The 'metadata' Operation

The `check` operation inherits the following environment:

  - `$HOME` - Will be set to a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

The standard error stream will be logged by the Tweed broker, for
review later by interested operators.

The standard output stream will be interpreted as a YAML document,
which properly identifies the backend image as a valid Tweed
backend image, with the following structure:

```
---
tweed:   v1             # version of the Tweed API contract
backend: Redis Cluster  # human-friendly backend name
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

If the `metadata` operation does not exit 0, the backend image as
a whole will be considered invalid.

If the `metadata` operation does not produce well-formed and
semantically correct YAML, Tweed will likewise consider the the
backend image as a whole invalid.


## The 'configure' Operation

The `configure` operation inherits the following environment:

  - `$HOME` - Will be set to a writable, ephemeral home directory.

    The exact `$HOME` mountpoint is unspecified, may change in
    future revisions of Tweed, but is guaranteed to reside under
    the reserved `/tweed` top-level directory.

  - `$OUT_CONFIG` - Will be set to a writable, persistent
    directory that will survive the termination of the backend
    container.  This is where the backend container *must* write
    any files it wishes to persist to future invocations to this
    directory.

    The exact `$OUT_CONFIG` mountpoint is unspecified, may
    change in future revisions of Tweed, but is guaranteed to
    reside under the reserved `/tweed` top-level directory.

Tweed will write the configuration (as supplied by the operator)
to standard input, in JSON format.  The field names will be those
specified in the JSON Schema given by the `metadata` operation's
output.

The standard output and standard error streams will be multiplexed
together (i.e. `2>&1`) and logged by the Tweed broker for review
later by interested operators.  No structured information should
be emitted to these two stream; they are intended explicitly for
debugging and diagnostic use -- Tweed will NOT interpret them in
any way.


## The 'check' Operation

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

The standard output and standard error streams will be multiplexed
together (i.e. `2>&1`) and logged by the Tweed broker for review
later by interested operators.  No structured information should
be emitted to these two stream; they are intended explicitly for
debugging and diagnostic use -- Tweed will NOT interpret them in
any way.

If the `check` operation does not exit 0, Tweed will consider the
configuration of the backend non-viable, and may prevent operators
from using it in configuration of new service plans.


## The 'setup' Operation

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

The standard error stream will be logged by the Tweed broker, for
review later by interested operators.

The standard output stream will be interpreted as a YAML document,
which identifies additional environment variables that Tweed must
inject into the _pattern_ container for it to be able to interact
with the backend.  That YAML must be of the form:

```
ENV_VAR: "Value of Environment Variable"
FOO: bar
```

If the `setup` operation does not exit 0, Tweed will consider the
configuration of the backend non-viable, and will not attempt any
operations against the backend.


## The 'teardown' Operation

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

The standard output and standard error streams will be multiplexed
together (i.e. `2>&1`) and logged by the Tweed broker for review
later by interested operators.  No structured information should
be emitted to these two stream; they are intended explicitly for
debugging and diagnostic use -- Tweed will NOT interpret them in
any way.
