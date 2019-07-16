/*





!!! This script migrates Configuration Data of Citect Historian to Wonderware Process Historain' Runtime Databaase!!!







Description

-----------




Usage

-----



	exec MigrateCitectConfig





Limitations / cautions

-----------------------






License

-------

This script can be used without additional charge with any licensed Wonderware Historian server. 

The terms of use are defined in your existing End User License Agreement for the 

Wonderware Historian software.



Update Info

-----------

The latest version of this script is available at:





Modified: 20-Jun-2019

By:		  RajkumarK



*/



/*

-- The following queries are useful for checking whether the data got migrated properly





*/


IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MigrateCitectConfig]') and TYPE in (N'P', N'PC'))

	BEGIN

		EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[MigrateCitectConfig] AS' 

	END

GO

ALTER PROCEDURE MigrateCitectConfig
AS
BEGIN
--DROP TABLE IF EXISTS #CitectConfig
IF OBJECT_ID('tempdb..#CitectConfig') IS NOT NULL
BEGIN
	DROP TABLE #CitectConfig
END

SELECT * INTO #CitectConfig
FROM
(
       SELECT 
			T1.ID,
			T1.TagName, 
			T1.Address, 
			T1.DataTypeID, 
			T1.DatasourceID, 
			T1.Location, 
			T1.Properties, 
			T1.LastReadSampleTime, 
			T2.PropertyName, 
			T2.PropertyValue  
       FROM  
			Tags T1,  
			TagProperties T2
       WHERE T1.ID = T2.TagID
) AS SourceTable PIVOT(MIN(PropertyValue) FOR [PropertyName] IN(Comment, DataAcquisition, Eng_Full, Eng_Units, Eng_Zero, LoggingDeadBand, LoggingEnabled, Raw_Full, Raw_Zero)) AS PivotTable;
       
DECLARE		@TagID INT = 0
DECLARE		@TagType INT = 0
DECLARE		@TagName NVARCHAR(512)
DECLARE		@Comment NVARCHAR(512)
DECLARE		@DataTypeID INT = 0
DECLARE		@DataSourceID NVARCHAR(512)
DECLARE     @DataSource NVARCHAR(256)
DECLARE     @Location NVARCHAR(256)
DECLARE     @Description NVARCHAR(256)
DECLARE		@EUKey INT = 0
DECLARE     @MaxEu NVARCHAR(256)
DECLARE     @MinEu NVARCHAR(256)
DECLARE     @EngineeringUnits NVARCHAR(256)
DECLARE     @ValueDeaband NVARCHAR(256)
DECLARE     @MinRaw NVARCHAR(256)
DECLARE     @MaxRaw NVARCHAR(256)

-- Iterate over all Tag IDs
WHILE (1 = 1) 
BEGIN  
	-- Get next TagID
	SELECT TOP 1 
		@TagID = ID
	FROM 
		#CitectConfig
	WHERE 
		ID > @TagID 
	ORDER BY ID

	-- Exit loop if no more Tags
	IF @@ROWCOUNT = 0 BREAK;

	-- Collect the data needed for Stored Proc
	SELECT  @TagName = TagName, 
			@Description = Properties, 
			@DataSourceID = DatasourceID, 
			@DataTypeID = DataTypeID,
			@Location = Location, 
			@MaxEu = Eng_Full, 
			@MinEu = Eng_Zero, 
			@EngineeringUnits = Eng_Units, 
			@ValueDeaband = LoggingDeadband,
			@MinRaw = Raw_Zero, @MaxRaw = Raw_Full
	FROM #CitectConfig 
	WHERE ID = @TagID   
 
	SELECT 
		@DataSource = DatasourceName 
	FROM Datasources 
	WHERE ID = @DataSourceID

	IF NOT EXISTS( 
		SELECT 1 
		FROM Runtime.dbo.EngineeringUnit 
		WHERE Unit = @EngineeringUnits)
	BEGIN
		EXEC Runtime.dbo.aaEngineeringUnitInsert   @EngineeringUnits, 1000, 1
	END

	SELECT 
		@EUKey = EUKey 
	FROM Runtime.dbo.EngineeringUnit 
	WHERE Unit = @EngineeringUnits

	DECLARE @MnEU AS FLOAT(53) 
	SET @MnEU = CONVERT(FLOAT, @MinEu)

	DECLARE @MxEU AS FLOAT(53) 
	SET @MxEU = CONVERT(FLOAT, @MaxEU)

	DECLARE @MnRAW AS FLOAT(53) 
	SET @MnRAW = CONVERT(FLOAT, @MinRAW)

	DECLARE @MxRAW AS FLOAT(53) 
	SET @MxRAW = CONVERT(FLOAT, @MaxRAW)

	DECLARE @VDeaband AS FLOAT(53) 
	SET @VDeaband = CONVERT(FLOAT, @ValueDeaband)

	  -- call respectivesproc
	  IF @DataTypeID = 1
	  BEGIN
		   EXEC Runtime.dbo.aaAnalogTagInsert 
					@TagName, 
					@Description,
					2,
					2,
					0,
					N'',
					0,
					N'Citect',
					NULL,
					0,
					@EUKey,
					@MnEU,
					@MxEU,
					@MnRaw,
					@MxRaw,
					1,
					3,
					@VDeaband,
					0,
					16,
					0,
					NULL,
					NULL,
					1,
					0,
					0,
					0,
					254,
					0,
					0,
					1,
					NULL,
					NULL,
					0,
					NULL,
					1,
					NULL,
					NULL
	  END

	  IF @DataTypeID = 2
	  BEGIN
		   EXEC Runtime.dbo.aaDiscreteTagInsert 
					@TagName, 
					@Description,
					2,
					2,
					0,
					N'',
					0,
					N'Citect',
					NULL,
					0,
					1,
					0,
					NULL,
					NULL,
					0,
					0,
					0,
					1,
					NULL,
					NULL,
					0,
					NULL,
					1,
					NULL,
					NULL
	  END

	  IF @DataTypeID = 3
	  BEGIN
		   EXEC Runtime.dbo.aaStringTagInsert 
					@TagName,
					@Description,
					2,
					2,
					0,
					N'',
					0,
					N'Citect',
					NULL,
					131,
					N'',
					NULL,
					NULL,
					0,
					0,
					0,
					0,
					1,
					0,
					NULL,
					NULL,
					0,
					NULL,
					1,
					NULL,
					NULL,
					NULL
	  END

END
END

