# Feature: Single instance

**Run:** 2026-10-29 16:27:38

**Status:** In Development

As a user  
I want the converter to open only once  
So that starting it again brings back the converter I already have open

## Scenario: Starting the converter a second time

* **Given** the converter is running and minimized
* **When** the converter is started again
* **Then** the running converter is found, so no second one opens
  * **And** the running converter window is restored
  * **And** the running converter window is in front

**Status:** Passed

## Scenario: Starting the converter the first time

* **Given** no converter is running
* **When** the converter is started
* **Then** it is the only converter, so it opens

**Status:** Passed
