USE [SupportExtensions]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].[WorkingDayDifference]
(
	@startDateTime dateTime, @endDateTime dateTime
)
RETURNS int
AS
BEGIN
	declare @dayDifference int = DATEDIFF(dd, @startDateTime, @endDateTime);
	declare @result int = 0;

	;with workingDayDifference(n, WeekdayName, DateTimeValue, IsWorkingDate) 
	AS (
		select
			0
			,DATENAME(dw, 0)
			,@startDateTime
			,(select [SupportExtensions].[dbo].[IsWorkingDateTime](@startDateTime))
		union all
		select    
			n + 1 
			,DATENAME(dw, n + 1)
			,DATEADD(dd, n + 1, @startDateTime)
			,IsWorkingDateTime.IsWorkingDateTimeValue
		from    
			workingDayDifference
		cross apply (select [SupportExtensions].[dbo].[IsWorkingDateTime](DATEADD(dd, n + 1, @startDateTime)) as IsWorkingDateTimeValue) IsWorkingDateTime
		where 
			(n < @dayDifference)
	)

	select @result = count(*)
	from workingDayDifference
	where IsWorkingDate = 0

	return @result;
END
