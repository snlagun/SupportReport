USE [ST_MSCRM]
GO
/****** Object:  UserDefinedFunction [dbo].[CreatedIncidentReportMarsFunction]    Script Date: 30.12.2020 13:21:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<S.Lagun>
-- Create date: <29/12/2020>
-- Description:	<Отчет по созданным обращениям проекта Марс>
-- =============================================
ALTER FUNCTION [dbo].[CreatedIncidentReportMarsFunction]()
RETURNS 
@result table
(
	TicketNumber nvarchar(50)
	,CreatedServerDateTime datetime
	,CaseTypeName nvarchar(50)
	,MarsPeriodFullName nvarchar(20)
	,MarsWeekFullName nvarchar(20)
	,SpecializationName nvarchar(200)
)
AS
BEGIN
		declare @marsProjectId uniqueidentifier = '7304D53F-1D70-EA11-9E32-00155DC86C01';
	declare @specializationsConformity table(specializationId uniqueidentifier, specializationName nvarchar(200), specializationConformityName nvarchar(200));
	insert into @specializationsConformity values 
			('1D0AA361-E473-E511-8300-DC0EA18AD6CD', 'Фактический маршрут, ST-Locator, GPS, ST-Супервайзер', 'ST-Супервайзер')
			,('240AA361-E473-E511-8300-DC0EA18AD6CD', 'Не сходятся данные с УС, Не выгружаются данные из УС или Чикаго', 'Обмен с УС')
	
	declare @caseTypes table(caseType int)
	insert into @caseTypes
		values (1),(2),(4) --(Консультация)(Неполадка)(Лицензирование)

	declare @internalStates table(internalState int)
	insert into @internalStates
		values (4),(8) --(К отклонению)(Дубль)

	declare @excludeSpecializationIds table(specializationId uniqueidentifier, specializationName nvarchar(200))
	insert into @excludeSpecializationIds values -- Исключить специализации
		('2E0AA361-E473-E511-8300-DC0EA18AD6CD', 'Автоинформатор')
		,('2A0AA361-E473-E511-8300-DC0EA18AD6CD', 'Регистрация на портале')
		,('4B5D2053-C878-E511-85D9-00155D017F87', 'Для внутренних БП')
		,('290AA361-E473-E511-8300-DC0EA18AD6CD', 'Документация')
		,('1C0AA361-E473-E511-8300-DC0EA18AD6CD', 'Консультация специалиста')
		,('2B0AA361-E473-E511-8300-DC0EA18AD6CD', 'СДО проблемы с обучением')
		,('2C0AA361-E473-E511-8300-DC0EA18AD6CD', 'СДО регистрация')
	;with 
	StartPeriod as
	(
		select
			C2.*
		from [SupportExtensions].[dbo].[ClosureCalendarMars](nolock) C1 
		left join [SupportExtensions].[dbo].[ClosureCalendarMars](nolock) C2 on (C1.MarsYear = C2.MarsYear and C1.MarsPeriod = C2.MarsPeriod and C1.MarsWeek = C2.MarsWeek and C2.MarsDay = 1)
		where C1.Date = CAST(CAST(DATEADD(yy, -1, GETDATE()) as date) as datetime)
	)
	,CreatedIncident as
	(
		select 
			I.TicketNumber
			,I.CreatedOn CreatedUTC
			,DATEADD(hh, (DATEDIFF(hh, GETUTCDATE(), GETDATE())), I.CreatedOn) CreatedServerDateTime
			,DATETIMEFROMPARTS(DATEPART(yy, I.CreatedOn), DATEPART(mm, I.CreatedOn), DATEPART(dd, I.CreatedOn), 0, 0, 0, 0) CreatedServerDate
			,SmbCaseTypeCode.Value CaseTypeName
			,case
				when Sc.specializationConformityName is not null then Sc.specializationConformityName
				when S.new_name = 'Чикаго' then 'Чикаго Веб'
				when S.new_name = 'Портал продуктов' then 'Чикаго Веб'
				when S.new_name = 'Проблема доступа к приложениям (RDWeb)' then 'Чикаго Веб'
				when S.new_name = 'Репликация' then 'Обмен с УС'
				when S.new_name = 'Репликация МТ' then 'Мобильная торговля (МТ)'
				else S.new_name
			end SpecializationName
		from [ST_MSCRM].[dbo].[IncidentBase](nolock) I
		left join [ST_MSCRM].[dbo].[new_specializationBase](nolock) S on (I.new_specialization = S.new_specializationId)
		left join [ST_MSCRM].[dbo].[StringMapBase](nolock) SmbCaseTypeCode on (I.CaseTypeCode = SmbCaseTypeCode.AttributeValue and SmbCaseTypeCode.AttributeName = LOWER('CaseTypeCode') and SmbCaseTypeCode.ObjectTypeCode = 112)
		left join @specializationsConformity Sc on (I.new_specialization = Sc.specializationId)
		where 
			I.iok_KK_project is not null
			and I.iok_KK_project = @marsProjectId
			and I.CaseTypeCode is not null
			and I.CaseTypeCode in (select caseType from @caseTypes)
			and I.new_specialization is not null
			and I.new_specialization not in (select specializationId from @excludeSpecializationIds)
			and I.new_state_intenal is not null
			and I.new_state_intenal not in (select internalState from @internalStates)
			and I.CreatedOn >= 
							(
								select
									case 
										when ((select count(*) from StartPeriod) != 0) then (select top 1 [Date] from StartPeriod order by Date)
										else DATEADD(yy, -1, GETDATE())
									end
							)
	),
	Report as
	(
		select 
			I.TicketNumber
			,I.CreatedServerDateTime
			,I.CaseTypeName
			,C.MarsPeriodFullName
			,C.MarsWeekFullName
			,I.SpecializationName
		from CreatedIncident I
		left join [SupportExtensions].[dbo].[ClosureCalendarMars](nolock) C on (I.CreatedServerDate = C.Date)
	)
	
	INSERT INTO @result
	select * from Report

	RETURN;
END
