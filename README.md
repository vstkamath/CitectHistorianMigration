# Citect Historian Migration
Migration of Citect Historian to Wonderware Historian using SQL scripts. Process Data migration from Citect Historian v4.6 is validated using Citect SCADA 2016 and System Platform 2017U03SP1

## Release Notes
This is a detailed listing of migration to Wonderware Historian (Updated 15 July 2019)

## Citect Metadata migration

Table below shows how the Citect Historian Data Types are mapped to Wonderware Historian

Citect Historian Data Type | Wonderware Historian Tag Type
------------ | -------------
Numeric Samples | Analog Tags
Digital Samples | Discrete Tags
String Samples | String tags

Citect Historian Properties are mapped with Wonderware Historian

Citect Historian Tag Property Name | Wonderware Historian Tag Property Name
------------ | -------------
TagName | TagName
Datatype | TagType
Properties | Description
Eng_Full | MaxEU
Eng_Units | EUKey
Eng_Zero | MinEU
Raw_Full | MaxRaw
Raw_Zero | MinRaw

## Citect ProcessData migration
Using the SQL script, the process data for Numeric Samples, Digital Samples & String Samples is migrated to Wonderware Historian.

1. This script expects the start and end dates as parameters to process the Historical data from Citect Historian to Wonderware Historian
1. It will process the entire data from Citect Historian, if datetime parameters are Null
1. Script has the ability to resume the process from where it has left last time
   * It processes the data in a batches of 1 day
   * If the query is interrupted or ended, it has the ability to resume from date. (This information is being persisted through a table 'ProcessedTime')

Limitations / cautions:

Note that the values will be processed as >= and <=, and make sure there is no time overlap, to avoid duplication of entries
