# Customer Lookup

**Feature documentation for Customer Lookup, written by its BDD feature tests.**

## The application

Customer Lookup is a desktop application for the front office. Before a
clerk takes on a new customer, they search the customer list by name to
see whether the customer is already on file. That keeps one record per
customer, so service history, invoices and contact details stay together.

A search shows every customer whose name matches, or tells the clerk that
no customer was found. Searching never changes the customer list.

## Who uses it

* **Clerks** search the list while taking a call or filling in a new
  customer form.
* **Office managers** use this document to see which features are ready and
  which are still in development.

## This document

Each feature below was written as Given / When / Then scenarios before the
code that makes them pass, and the scenarios are run against the application
by its test suite.

* Each feature shows when it was last run and where it is in its life cycle,
  from *Proposed* to *Accepted*, and the requirement it satisfies.
* Each scenario shows whether it **Passed** or **Failed**, with the reason
  when it failed.

This is a sample. Customer Lookup is an example application made up to show
what a PsBDD document looks like.

# Table of Contents

[BDD-TOC-START]: #

- [Feature 1: Customer list](#feature-1-customer-list)
  - [Scenario 1: Customer is found in the list](#scenario-1-customer-is-found-in-the-list)
  - [Scenario 2: Unknown customer is not found](#scenario-2-unknown-customer-is-not-found)

[BDD-TOC-END]: #

# Feature 1: Customer list

**Run:** 2026-10-28 09:26:25

**Status:** In Development

As a clerk  
I want to check whether a customer is in the customer list  
So that I do not create the same customer twice

> **REQ#014:** The system shall report whether a customer is in the customer list.

## Scenario 1: Customer is found in the list

* **Given** a customer list with "Smith" and "Jones"
* **When** the clerk searches for "Smith"
* **Then** the customer is found
  * **And** exactly one match is returned

**Status:** Passed

## Scenario 2: Unknown customer is not found

* **Given** a customer list with "Smith" and "Jones"
* **When** the clerk searches for "Brown"
* **Then** no customer is found
  * **But** the customer list still holds 2 customers

**Status:** Passed
