USE [ST_MSCRM]
GO
/****** Object:  UserDefinedFunction [dbo].[CreatedIncidentCountGroupByPeriodReportMarsFunction]    Script Date: 30.12.2020 13:22:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<S.Lagun>
-- Create date: <30/12/2020>
-- Description:	<Количество созданных обращений проекта Марс>
-- =============================================
ALTER FUNCTION [dbo].[CreatedIncidentCountGroupByPeriodReportMarsFunction]()
RETURNS 
@result table
(
	PercentCount float
	,CreatedCount int
	,CaseTypeName nvarchar(50)
	,MarsPeriodFullName nvarchar(20)
	,SpecializationName nvarchar(200)
	,CreatedServerDateTime datetime

)
AS
BEGIN
	;with 
	TotalCountGroupByPeriod as
	(
		select
			COUNT(TicketNumber) as CreatedIncidentCount
			,MarsPeriodFullName
		from [ST_MSCRM].[dbo].[CreatedIncidentReportMarsFunction]()
		group by 			
			MarsPeriodFullName
	),
	CreatedIncidentReportMars as
	(
		select
			COUNT(TicketNumber) as CreatedIncidentCount
			,CaseTypeName
			,MarsPeriodFullName
			,SpecializationName
			,CreatedServerDateTime
		from [ST_MSCRM].[dbo].[CreatedIncidentReportMarsFunction]()
		group by 			
			CaseTypeName
			,MarsPeriodFullName
			,SpecializationName
			,CreatedServerDateTime
	)

	INSERT INTO @result
	select 
		(R.CreatedIncidentCount * 1.0 / T.CreatedIncidentCount) PercentCount
		,R.CreatedIncidentCount
		,R.CaseTypeName
		,R.MarsPeriodFullName
		,R.SpecializationName
		,R.CreatedServerDateTime
	from TotalCountGroupByPeriod T
	right join CreatedIncidentReportMars R on (R.MarsPeriodFullName = T.MarsPeriodFullName)
	group by
			(R.CreatedIncidentCount * 1.0 / T.CreatedIncidentCount)
			,R.CreatedIncidentCount
			,R.CaseTypeName
			,R.MarsPeriodFullName
			,R.SpecializationName
			,R.CreatedServerDateTime

	RETURN;
END
