/*
!!! This script migrates Process Data from Citect Historian to Wonderware Process Historain !!!

Prerequisite
-------------
!!! Prior to run this script,  do ensure to migrate the Citect Configuration data to Wonderware Process Historian's Runtime Database using stroed procedure dbo.MigrateCitectConfiguration  !!!

Description
-----------

 - This scripts expect the Starte and end date as parameters to process the Historical data from Citect Historian to Wonderware Historian
 - It will process the entire data from Citect Historian, if datetime parameters are null.
 - Script has the ability to resume the process from where it left last time.
	- It processes the data in a batches of 1 day
	- It the query is interrupted or ended, it has the ability to resume from date. (This information is being persisted through a table 'ProcessedTime')

Usage
-----

	exec MigrateCitectData <StartDateTime>, <EndDateTime>

Where:

	StartDateTime / EndDateTime

		- Time period expressed in local server time
		- These parameters are optional and if not provided, then all the data in Citect Historian will be Migrated to Wonderware Process Historian.

Examples

	exec MigrateCitectData '2016-04-01 00:00', '2016-04-10 0:00:00'

	exec MigrateCitectData 

Limitations / cautions
-----------------------

Please note that the values will be processed as >= and <=. Please ensure that there is no time overlap, to avoid duplication of entiries.

License
-------

This script can be used without additional charge with any licensed Wonderware Historian server. 

The terms of use are defined in your existing End User License Agreement for the 

Wonderware Historian software.


Update Info
-----------

The latest version of this script is available at:


Modified: 20-Jun-2019

By:		  AVEVA Software, LLC.

*/

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MigrateCitectData]') and TYPE in (N'P', N'PC'))
BEGIN
	EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[MigrateCitectData] AS' 
END
GO

-- Migrate Citect Data
ALTER PROCEDURE dbo.MigrateCitectData 
	@StartDateTime AS DATETIME = NULL, 
	@EndDateTime AS DATETIME = NULL
AS
BEGIN
	DECLARE @StartDate BIGINT;
	DECLARE @EndDate BIGINT;
	DECLARE @CurrentDate BIGINT;
	DECLARE @OneDayOffset BIGINT;
	DECLARE @TimeZone VARCHAR(50)
	
	EXEC MASTER.dbo.xp_regread 'HKEY_LOCAL_MACHINE',
								'SYSTEM\CurrentControlSet\Control\TimeZoneInformation',
								'TimeZoneKeyName',
								@TimeZone OUT

	IF NOT EXISTS (
		SELECT 1
		FROM sys.objects
		WHERE object_id = OBJECT_ID(N'dbo.ProcessedTime'))
	BEGIN
		CREATE TABLE ProcessedTime (
			LastTimeStamp BIGINT);

		INSERT INTO ProcessedTime VALUES(0);
	END;

	IF (@StartDateTime IS NULL AND @EndDateTime IS NULL)
	BEGIN TRY
		SELECT 
			@EndDate = LastTimeStamp 
		FROM ProcessedTime; 

		IF (@EndDate IS NULL OR @EndDate = 0)
		BEGIN
			SELECT 
				@EndDate  = MAX(ISNULL(SampleDateTime,0))
			FROM(
				SELECT 
					MAX(ISNULL(SampleDateTime,0)) AS SampleDateTime 
				FROM NumericSamples 
				WHERE SampleDateTime != 0

				UNION 

				SELECT 
					MAX(ISNULL(SampleDateTime,0)) AS SampleDateTime 
				FROM DigitalSamples 
				WHERE SampleDateTime != 0

				UNION 

				SELECT 
					MAX(ISNULL(SampleDateTime,0)) AS SampleDateTime 
				FROM StringSamples 
				WHERE SampleDateTime != 0 ) MaxVal
		END;

		SELECT 
			@StartDate = MAX(ISNULL(SampleDateTime,0))
		FROM(
			SELECT
				MIN(ISNULL(SampleDateTime,0)) AS SampleDateTime 
			FROM NumericSamples 
			WHERE SampleDateTime != 0

			UNION 

			SELECT
				MIN(ISNULL(SampleDateTime,0)) AS SampleDateTime 
			FROM DigitalSamples 
			WHERE SampleDateTime != 0

			UNION 

			SELECT
				MIN(ISNULL(SampleDateTime,0)) AS SampleDateTime 
			FROM StringSamples 
			WHERE SampleDateTime != 0 ) MinVal	
	END TRY
	BEGIN CATCH
		SELECT   
			ERROR_NUMBER() AS ErrorNumber,  
			ERROR_MESSAGE() AS ErrorMessage;
	END CATCH;
	ELSE
	BEGIN
		SELECT @StartDate = dbo.ToBigInt(@StartDateTime);
		SELECT @EndDate = dbo.ToBigInt(@EndDateTime);
	END;

	IF (@EndDate <= @StartDate)
		RETURN;

	SET @CurrentDate = @EndDate;

	WHILE (@CurrentDate >= @StartDate)
	BEGIN TRY
		DECLARE @DateTimeVal DateTime;

		SET @DateTimeVal = dbo.ToDate(@CurrentDate);
		SET @DateTimeVal = CONVERT(VARCHAR(30), DATEADD(DAY,-1, @DateTimeVal), 101); /*decrement date by one day for one day processing*/
		SET @OneDayOffset = dbo.ToBigInt(@DateTimeVal);

		INSERT INTO Runtime.dbo.History (TagName, DateTime, Value, OPCQuality, wwTimeZone) 
		SELECT
			TagName, 
			dbo.ToDateUTC(SampleDateTime),
			SampleValue,
			QualityID,
			@TimeZone 
		FROM (
			SELECT 
				T4.TagName,
				T1.SampleDateTime,
				T1.SampleValue,
				T1.QualityID 
			FROM NumericSamples T1 
			INNER JOIN Tags T4 ON T1.TagID = T4.ID
			WHERE T1.SampleDateTime >= @OneDayOffset
				AND T1.SampleDateTime < @CurrentDate
				AND T1.SampleDateTime != 0

			UNION ALL

			SELECT 
				T4.TagName,
				T1.SampleDateTime,
				T1.SampleValue,
				T1.QualityID 
			FROM DigitalSamples T1 
			INNER JOIN Tags T4 ON T1.TagID = T4.ID
			WHERE T1.SampleDateTime >= @OneDayOffset
				AND T1.SampleDateTime < @CurrentDate
				AND T1.SampleDateTime != 0	) CitectData;

			INSERT INTO Runtime.dbo.StringHistory (TagName, DateTime, Value, OPCQuality, wwTimeZone) 
			SELECT 
				T4.TagName,
				dbo.ToDateUTC(T1.SampleDateTime),
				T1.SampleValue,
				T1.QualityID,
				@TimeZone 
			FROM StringSamples T1 
			INNER JOIN Tags T4 ON T1.TagID = T4.ID
			WHERE T1.SampleDateTime >= @OneDayOffset
				AND T1.SampleDateTime < @CurrentDate
				AND T1.SampleDateTime != 0;
     
			SET @DateTimeVal = dbo.ToDate(@CurrentDate);
			SET @DateTimeVal = CONVERT(VARCHAR(30), DATEADD(DAY,-1, @DateTimeVal), 101); /*decrement current date*/
			SET @CurrentDate = dbo.ToBigInt(@DateTimeVal);

			UPDATE 
				ProcessedTime 
			SET LastTimeStamp = @CurrentDate;
		END TRY
		BEGIN CATCH  
		SELECT   
			ERROR_NUMBER() AS ErrorNumber,  
			ERROR_MESSAGE() AS ErrorMessage;
		END CATCH;

		-- *** To ensure last values on exact boundary value are not missed out.....****
		BEGIN TRY
			INSERT INTO Runtime.dbo.History (TagName, DateTime, Value, OPCQuality, wwTimeZone) 
			SELECT
				TagName, 
				dbo.ToDateUTC(SampleDateTime),
				SampleValue,
				QualityID,
				@TimeZone 
			FROM (
				SELECT 
					T4.TagName,
					T1.SampleDateTime,
					T1.SampleValue,
					T1.QualityID 
				FROM NumericSamples T1 
				INNER JOIN Tags T4 ON T1.TagID = T4.ID
				WHERE T1.SampleDateTime = @CurrentDate
					AND T1.SampleDateTime != 0

				UNION ALL

				SELECT 
					T4.TagName,
					T1.SampleDateTime,
					T1.SampleValue,
					T1.QualityID 
				FROM DigitalSamples T1 
				INNER JOIN Tags T4 ON T1.TagID = T4.ID
				WHERE T1.SampleDateTime = @CurrentDate
					AND T1.SampleDateTime != 0	) CitectData;

				INSERT INTO Runtime.dbo.StringHistory (TagName, DateTime, Value, OPCQuality, wwTimeZone) 
				SELECT 
					T4.TagName,
					dbo.ToDateUTC(T1.SampleDateTime),
					T1.SampleValue,
					T1.QualityID,
					@TimeZone 
				FROM StringSamples T1 
				INNER JOIN Tags T4 ON T1.TagID = T4.ID
				WHERE T1.SampleDateTime = @CurrentDate
					AND T1.SampleDateTime != 0;
		END TRY
		BEGIN CATCH
			SELECT
				ERROR_NUMBER() AS ErrorNumber,  
				ERROR_MESSAGE() AS ErrorMessage;
		END CATCH;
END;

