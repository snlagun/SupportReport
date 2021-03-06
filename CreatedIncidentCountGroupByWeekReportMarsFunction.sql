USE [ST_MSCRM]
GO
/****** Object:  UserDefinedFunction [dbo].[CreatedIncidentCountGroupByWeekReportMarsFunction]    Script Date: 30.12.2020 13:22:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<S.Lagun>
-- Create date: <30/12/2020>
-- Description:	<Количество созданных обращений проекта Марс>
-- =============================================
ALTER FUNCTION [dbo].[CreatedIncidentCountGroupByWeekReportMarsFunction]()
RETURNS 
@result table
(
	PercentCount float
	,CreatedCount int
	,CaseTypeName nvarchar(50)
	,MarsWeekFullName nvarchar(20)
	,SpecializationName nvarchar(200)
	,CreatedServerDateTime datetime

)
AS
BEGIN
	;with 
	TotalCountGroupByWeek as
	(
		select
			COUNT(TicketNumber) as CreatedIncidentCount
			,MarsWeekFullName
		from [ST_MSCRM].[dbo].[CreatedIncidentReportMarsFunction]()
		group by 			
			MarsWeekFullName
	),
	CreatedIncidentReportMars as
	(
		select
			COUNT(TicketNumber) as CreatedIncidentCount
			,CaseTypeName
			,MarsWeekFullName
			,SpecializationName
			,CreatedServerDateTime
		from [ST_MSCRM].[dbo].[CreatedIncidentReportMarsFunction]()
		group by 			
			CaseTypeName
			,MarsWeekFullName
			,SpecializationName
			,CreatedServerDateTime
	)

	INSERT INTO @result
	select 
		(R.CreatedIncidentCount * 1.0 / T.CreatedIncidentCount) PercentCount
		,R.CreatedIncidentCount
		,R.CaseTypeName
		,R.MarsWeekFullName
		,R.SpecializationName
		,R.CreatedServerDateTime
	from TotalCountGroupByWeek T
	right join CreatedIncidentReportMars R on (R.MarsWeekFullName = T.MarsWeekFullName)
	group by
			(R.CreatedIncidentCount * 1.0 / T.CreatedIncidentCount)
			,R.CreatedIncidentCount
			,R.CaseTypeName
			,R.MarsWeekFullName
			,R.SpecializationName
			,R.CreatedServerDateTime

	RETURN;
END
