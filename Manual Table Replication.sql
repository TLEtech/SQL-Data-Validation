---- Created with MSSQL to give an example on a way to update an out of date target table
---- with up to date records from a source table. This is very generalized and not meant
---- for immediate use (obviously - variable names are placeholders), so if you're looking
---- to use this for a specific purpose, replace the generic variable names with your specific
---- needs. Feel free to comment me with any questions. - TLE


-- This is all assuming the source table matches the datatypes for the target table EXACTLY.
-- Replace all variable names as needed. Be careful with this.
 
-- Looks for temp tables created and drops them, if you are planning to run this multiple times.
IF OBJECT_ID('tempdb..##KeysForInsert') IS NOT NULL DROP TABLE ##KeysForInsert
IF OBJECT_ID('tempdb..##InsertData') IS NOT NULL DROP TABLE ##InsertData
 
-- Creates a Common Table Expression (basically a type of temp table)
-- Grabbing all keys from target DB. If this is grabbing too much data,
-- you can uncomment the WHERE statement before the end of parenthesis.
-- That will cause this to only grab from the calendar year.
-- This is all dependant on how much data you want to grab
-- and how current your backup is.
-- WARNING: If you uncomment the WHERE clause here,
--      MAKE SURE YOU DO THE SAME ON THE STATEMENT COMMENTED OUT BELOW THIS
WITH CTE AS
    (
    SELECT [PrimaryKey] FROM [TargetServer].[TargetDB].[TargetSchema].[TargetTable] WITH(NOLOCK)
    --WHERE DatePart(Year,[RecordDate]) = '2021'
    )
 
-- Selects keys from source DB that do not exist in target
-- Again, if this grabs too much data, uncomment the WHERE clause.
-- That will cause this to only grab from the calendar year.
-- WARNING: If you uncomment the WHERE clause here,
--      MAKE SURE YOU DO THE SAME ON THE STATEMENT COMMENTED OUT ABOVE THIS
SELECT [PrimaryKey]
    INTO ##KeysForInsert
    FROM [SourceServer].[SourceDB].[SourceSchema].[SourceTable] WITH(NOLOCK)
-- WHERE DatePart(Year,[RecordDate]) = '2021'
    WHERE [PrimaryKey] NOT IN (SELECT [PrimaryKey] FROM CTE);
 
-- This will tell you the amount of keys flagged for insert
SELECT COUNT([PrimaryKey]) FROM ##KeysForInsert
 
-- Using the primary keys on the temp table as reference, this
-- will grab all the data from the source table into another
-- temp table for insert.
SELECT *
    INTO ##InsertData
    FROM [SourceServer].[SourceDB].[SourceSchema].[SourceTable]
    WHERE [PrimaryKey] IN (SELECT [PrimaryKey] FROM ##KeysForInsert)
 
-- This will tell you what is added, for auditing purposes
SELECT * FROM ##InsertData
 
-- This is the final insert statement. This is commented for now. Uncomment if everything looks good.
 
/*
INSERT INTO [TargetServer].[TargetDB].[TargetSchema].[TargetTable]
    SELECT * FROM ##InsertData
*/
