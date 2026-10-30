# Feature: Converter window

**Run:** 2026-10-29 16:27:38

**Status:** In Development

As a user  
I want to choose the folder with the Florida corporate data files  
So that I can convert them to CSV files for MariaDB

## Scenario: Selecting the source folder

* **Given** the converter window is open
* **When** the Select folder button is pressed
* **Then** the folder dialog asks for a folder
  * **And** the chosen folder is shown in the folder box

**Status:** Passed
