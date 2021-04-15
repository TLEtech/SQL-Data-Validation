-- SP Purpose is to check the integrity of imported data from source DB (CRM)
-- to target DB (ERP). - TLE
-- Date Last Modified: 3-4-21
-- 
--Declarations
DECLARE @AlertTo varchar(max) -- Who the alerts get sent to
DECLARE @AlertHeader varchar(max) -- Header and styles for alert
DECLARE @NumRows int -- Keep track of number of rows
DECLARE @AlertTitle varchar(200) -- Title of the alert
DECLARE @AlertSection varchar(100) -- Type of alert, ie: Inventory, Sales Order, etc

--SET Recipients emails/names separated by a semicolon (;)
SET @AlertTo = ''-- Send the alert to these emails or mobile numbers

SET @AlertHeader = '' -- Alert header

DECLARE @sinceDate varchar(10)
SELECT @sinceDate = convert(varchar(10),dateadd(month,-1,getdate()),101)


DELETE FROM portal_notes
WHERE dockey is null

DECLARE @field varchar(100); SET @field = 'SG Order ID:'


------ Step 1) Grab orders in target DB (Sage)
-- From target database (Sage):
-- Grab IDs for orders (from today) based on notes created by Order Import process
DECLARE @notes table (id varchar(100))
INSERT INTO @notes
SELECT 
REPLACE(REPLACE(ltrim(rtrim(REPLACE(
	substring(noteshorttext,charindex(@field,noteshorttext,0),len(noteshorttext) - CHARINDEX(@field,noteshorttext,0)),
	@field,
	''
))),char(10),''),char(13),'') id
FROM portal_notes
-- The '*** Quick%' tag on the noteShortText is what indicates that an order was imported to target DB (Sage).
-- This is clearly an imperfect variable to use as a key - must revisit this later.
WHERE noteShortText like '*** Quick%'
and notedate >= @sinceDate

------ Step 2) Grab orders in source DB (Evolution)
-- From source database (Evolution)
-- Grab IDs for orders that have been imported already.
CREATE TABLE #orders (id varchar(100))
INSERT INTO #orders 
	SELECT id FROM 
	server.CRMdb.dbo.orders
-- The 'QualifierString' tag is what flags orders form import into target DB (Sage).
	WHERE docalias like 'QualifierString%'
	and orderdate >= @sinceDate

------ Step 3) Compare order data from Sage to order data from Evolution
-- Delete IDs that have been succesfully imported into target database,
-- leaving only ids that are tagged in source DB as imported, but are not
-- present in the target database (Sage).
DELETE FROM #orders
WHERE id in (SELECT id FROM @notes) 

-- Create temp table containing final mismatched orders data
SELECT id,orderdate,verifydate,salesperson,shipcompany 
INTO #temp
FROM server.CRMdb.dbo.orders
WHERE id in
(
	SELECT id FROM #orders
)

DROP TABLE #orders

SELECT * FROM #TEMP

SELECT @NumRows=count(*) FROM #temp

------ Step 4) Check results to see if there are any missing orders
-- If there are any mismatched orders, create and send an alert for SysAdmin analysis.
if @NumRows > 0
BEGIN
	--Create email here
	DECLARE @table varchar(max)
	SET @table = ''

	WHILE (SELECT count(*) FROM #temp) > 0
	BEGIN
		DECLARE @id varchar(max), @salesperson varchar(max), @shipcompany varchar(max)
		SELECT top 1 @id = id, @salesperson=salesperson, @shipcompany = shipcompany FROM #temp

		SET @table = @table + '[' + @salesperson + '] ' + @shipcompany + '
		'

		DELETE FROM #temp WHERE id  = @id		
	end

	DECLARE @mysubject varchar(400)
	SET @mysubject = 'Missing Orders: [' + convert(varchar(20),@NumRows) + ']'
------ Step 6) Send alerts.
-- Utilize dbmail to send out to specified recipients.
	EXEC msdb.dbo.sp_send_dbmail @recipients=@AlertTo,
    @subject = @mysubject, 
    @body = @table,
    @body_format = 'Text'

END
	

DROP TABLE #temp





END
