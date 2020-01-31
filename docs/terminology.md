Terminology
===========

This document defines terminology used by the Tweed Data Service
Broker, in a disambiguating capacity.  This document is the final
word on the meaning of words as used in the rest of the Tweed
documentation, API descriptions, contracts, and protocol
specifications.


## catalog

A _catalog_ is a collection of _services_ and their _plans_, which
is made available to customers to deploy new instances of data
services, on-demand.

## service

A _service_ is a generic offering of (usually) a single piece of
software, configured in a variety of ways.  The different methods
of configuring a service are presented as _plans_.

## plan

A _plan_ is a specific offering, belong to a single related
_service_, that provides a more concrete idea of what will be
deployed.  For example, a Redis _service_ might have three plans,
based on the size of VM or container that you get: small, medium,
or large.

## instance

An instance is a single occurrence or deployment of a _service_ /
_plan_, on top of a something like a BOSH director or a Kubernetes
cluster.  A plan can have an arbitrary number of instances,
pursuant to operator quota configuration.

## pattern

A _pattern_ is a collection of logic, code, and configuration
items, delivered as an OCI image that implements the _[Tweed Pattern
OCI Image Contract](api/pattern-oci-image-contract.md)_.  A
pattern can be used across several _service plans_, depending on
the needs of the operator.

## backend

A _backend_ is a collection of logic and code, and configuration
items, delivered as an OCI image that imeplements the _[Tweed
Backend OCI Image Contract](api/backend-oci-image-contract.md)_. A
backend can be configured several times, depending on the needs of
the operator.
