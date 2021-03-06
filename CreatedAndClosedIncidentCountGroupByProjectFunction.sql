USE [ST_MSCRM]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [dbo].[CreatedAndClosedIncidentCountGroupByProjectFunction](@interval int)
RETURNS 
@result table
(
	ActionDatePart nvarchar(10)
	,CreatedCountMobileTrading int
	,ClosedCountMobileTrading int
	,ParentSpecialization nvarchar(50)
	,CreatedCountChicago int
	,ClosedCountChicago int
	,CreatedCountDataExchange int
	,ClosedCountDataExchange int
	,ProjectName nvarchar(200)
)
AS
BEGIN
	if (@interval is null) set @interval = 30;
	declare @startDate dateTime = DATEADD(hh, -(DATEDIFF(hh, GETUTCDATE(), GETDATE())), DATEADD(dd, -@interval,  CAST(CAST(GETDATE() as date) as datetime))) -- Минус 30 дней, а также минус два часа, т.к. в таблицах время в UTC

	declare @caseTypes table(caseType int)
	insert into @caseTypes
		values (1),(2),(4),(9) --(Консультация)(Неполадка)(Лицензирование)(Процесс сверки данных)

	declare @StMaksimenkoId uniqueidentifier = 'BD270638-B84F-DF11-A837-00155D1A6310';
	declare @RProntenkoId uniqueidentifier = '8CF1A335-2FCF-E511-BF78-00155D017F24';
	declare @DSklyarenkoId uniqueidentifier = '275D299F-965E-E011-B9C0-00155D017F2A';
	declare @ownerIds table(ownerId uniqueidentifier)

	declare @registrated int = 1; --Зарегистрировано
	declare @running int = 2; --В работе
	declare @awaitClientCheck int = 3; --Ожидает проверки клиентом
	declare @closed int = 6; --Закрыто
	declare @sleeping int = 16; --Отложено
	declare @defectEditing int = 18; --На исправлении дефекта
	declare @answerReceived int = 19; --Получен ответ от клиента
	declare @reEditing int = 20; --На дооформлении
	declare @awaitingAnswerFromClient int = 21; --Ждем ответа от клиента
	declare @waitingFirmwareUpdate int = 22; --Ждет обновление ПО
	declare @awaitingFirmwareUpdate int = 26; --Ждет обновления ПО (Р)
	declare @clientClosed int = 27; --Закрыто клиентом
	declare @awaiting int = 100000000; --В ожидании
	declare @clientSupport int = 100000001; --Поддержка клиента

	declare @mobileTradingParentSpecializationId uniqueidentifier = 'A5498406-CB0A-E611-A7A4-00155D017F24'; -- Мобильная торговля родительская специализация
	declare @chicagoParentSpecializationId uniqueidentifier = '83B94F98-CA0A-E611-A7A4-00155D017F24'; -- Чикаго родительская специализация
	declare @dataExchangeParentSpecializationId uniqueidentifier = '227C9131-E824-E711-80D4-00155D234F02'; -- Обмен данными родитетельская специализация

	declare @inspectorCloudSpecializationId uniqueidentifier = '537510A1-AB08-EB11-9E4B-00155DC86C0F'; 
	declare @excludeSpecializationIdsMobileTrading table(specializationId uniqueidentifier)
	insert into @excludeSpecializationIdsMobileTrading
		values (@inspectorCloudSpecializationId) -- Исключить из выборки МТ

	declare @portalRegistration uniqueidentifier = '2A0AA361-E473-E511-8300-DC0EA18AD6CD';
	declare @excludeSpecializationIdsChicago table(specializationId uniqueidentifier)
	insert into @excludeSpecializationIdsChicago
		values (@portalRegistration) -- Исключить из выборки Чикаго

	declare @dms uniqueidentifier = '91D2E358-7ABD-E811-811F-00155D005ACA';
	declare @excludeSpecializationIdsDataExchange table(specializationId uniqueidentifier)
	insert into @excludeSpecializationIdsDataExchange
		values (@dms) -- Исключить из выборки ОД

	;with
	CommonReport as
	(
		select
				I.IncidentId
				,DATEADD(hh, (DATEDIFF(hh, GETUTCDATE(), GETDATE())), I.CreatedOn) CreatedDateTime
				,DATEADD(hh, (DATEDIFF(hh, GETUTCDATE(), GETDATE())), I.New_resolve) ClosedDateTime
				,svk_name ProjectName
				,new_specialization SpecializationId
			from [ST_MSCRM].[dbo].[IncidentBase](nolock) I
			left join [ST_MSCRM].[dbo].[svk_projectBase](nolock) P on (I.iok_KK_project = P.svk_projectId)
			where
				I.iok_KK_project is not null
				and I.OwnerId is not null
				and I.OwnerId not in (select ownerId from @ownerIds)
				and I.CaseTypeCode is not null 
				and I.CaseTypeCode in (select caseType from @caseTypes)
				and (I.CreatedOn >= @startDate or I.New_resolve >= @startDate)
	)
	,CreatedIncidents as
	(
		select
			case
				when (@interval = 30 and CreatedDateTime >= @startDate) then RTRIM(CAST(CAST(CreatedDateTime as date) as nvarchar(10)))
				when (@interval = 90 and CreatedDateTime >= @startDate) then RIGHT('0' + RTRIM(CAST(DATEPART(wk, DATEADD(hh, (DATEDIFF(hh, GETUTCDATE(), GETDATE())), CreatedDateTime)) as nvarchar(2))), 2)
				when (@interval = 365 and CreatedDateTime >= @startDate) then CONCAT(RTRIM(CAST(DATEPART(yyyy, DATEADD(hh, (DATEDIFF(hh, GETUTCDATE(), GETDATE())), CreatedDateTime)) as nvarchar(4))), '.', RIGHT('0' + RTRIM(CAST(DATEPART(mm, DATEADD(hh, (DATEDIFF(hh, GETUTCDATE(), GETDATE())), CreatedDateTime)) as nvarchar(2))), 2))
				else null
			end CreatedDatePart
			,ProjectName
			,SpecializationId
			,SUM
			(
				case 
					when CreatedDateTime >= @startDate then 1
					else 0
				end
			) CreatedCount
		from CommonReport
		group by
			case
				when (@interval = 30 and CreatedDateTime >= @startDate) then RTRIM(CAST(CAST(CreatedDateTime as date) as nvarchar(10)))
				when (@interval = 90 and CreatedDateTime >= @startDate) then RIGHT('0' + RTRIM(CAST(DATEPART(wk, DATEADD(hh, (DATEDIFF(hh, GETUTCDATE(), GETDATE())), CreatedDateTime)) as nvarchar(2))), 2)
				when (@interval = 365 and CreatedDateTime >= @startDate) then CONCAT(RTRIM(CAST(DATEPART(yyyy, DATEADD(hh, (DATEDIFF(hh, GETUTCDATE(), GETDATE())), CreatedDateTime)) as nvarchar(4))), '.', RIGHT('0' + RTRIM(CAST(DATEPART(mm, DATEADD(hh, (DATEDIFF(hh, GETUTCDATE(), GETDATE())), CreatedDateTime)) as nvarchar(2))), 2))
				else null
			end
			,ProjectName
			,SpecializationId
	)
	,ClosedIncidents as
	(
		select
			case
				when (@interval = 30 and ClosedDateTime >= @startDate) then RTRIM(CAST(CAST(ClosedDateTime as date) as nvarchar(10)))
				when (@interval = 90 and ClosedDateTime >= @startDate) then RIGHT('0' + RTRIM(CAST(DATEPART(wk, DATEADD(hh, (DATEDIFF(hh, GETUTCDATE(), GETDATE())), ClosedDateTime)) as nvarchar(2))), 2)
				when (@interval = 365 and ClosedDateTime >= @startDate) then CONCAT(RTRIM(CAST(DATEPART(yyyy, DATEADD(hh, (DATEDIFF(hh, GETUTCDATE(), GETDATE())), ClosedDateTime)) as nvarchar(4))), '.', RIGHT('0' + RTRIM(CAST(DATEPART(mm, DATEADD(hh, (DATEDIFF(hh, GETUTCDATE(), GETDATE())), ClosedDateTime)) as nvarchar(2))), 2))
				else null
			end ClosedDatePart
			,ProjectName
			,SpecializationId
			,SUM
			(
				case 
					when ClosedDateTime >= @startDate then 1
					else 0
				end
			) ClosedCount
		from CommonReport
		group by
			case
				when (@interval = 30 and ClosedDateTime >= @startDate) then RTRIM(CAST(CAST(ClosedDateTime as date) as nvarchar(10)))
				when (@interval = 90 and ClosedDateTime >= @startDate) then RIGHT('0' + RTRIM(CAST(DATEPART(wk, DATEADD(hh, (DATEDIFF(hh, GETUTCDATE(), GETDATE())), ClosedDateTime)) as nvarchar(2))), 2)
				when (@interval = 365 and ClosedDateTime >= @startDate) then CONCAT(RTRIM(CAST(DATEPART(yyyy, DATEADD(hh, (DATEDIFF(hh, GETUTCDATE(), GETDATE())), ClosedDateTime)) as nvarchar(4))), '.', RIGHT('0' + RTRIM(CAST(DATEPART(mm, DATEADD(hh, (DATEDIFF(hh, GETUTCDATE(), GETDATE())), ClosedDateTime)) as nvarchar(2))), 2))
				else null
			end
			,ProjectName
			,SpecializationId
	)
	,CommonReportGroupByDatePart as
	(
		select 
			ISNULL(Cr.CreatedDatePart, Cl.ClosedDatePart) ActionDatePart
			,ISNULL(Cr.ProjectName, Cl.ProjectName) ProjectName
			,ISNULL(Cr.SpecializationId, Cl.SpecializationId) SpecializationId
			,ISNULL(SUM(Cr.CreatedCount), 0) CreatedCount
			,ISNULL(SUM(Cl.ClosedCount), 0) ClosedCount
		from CreatedIncidents Cr
		full outer join ClosedIncidents Cl 
			on Cr.CreatedDatePart = Cl.ClosedDatePart and Cr.ProjectName = Cl.ProjectName	and Cr.SpecializationId = Cl.SpecializationId
		group by 
			ISNULL(Cr.CreatedDatePart, Cl.ClosedDatePart)
			,ISNULL(Cr.ProjectName, Cl.ProjectName)
			,ISNULL(Cr.SpecializationId, Cl.SpecializationId)
		having ISNULL(Cr.CreatedDatePart, Cl.ClosedDatePart) is not null
	)
	,
	MobileTradingReport as
	(
		select 
			ActionDatePart
			,SUM(CreatedCount) as CreatedCountMobileTrading
			,SUM(ClosedCount) as ClosedCountMobileTrading
			,ProjectName
			,N'Мобильная торговля' as ParentSpecialization
		from CommonReportGroupByDatePart
		where
			SpecializationId is not null
			and SpecializationId not in (select specializationId from @excludeSpecializationIdsMobileTrading)
			and SpecializationId in (select new_specializationId from [ST_MSCRM].[dbo].[new_specializationBase](nolock) where new_parentSpecialization is not null and new_parentSpecialization = @mobileTradingParentSpecializationId)
		group by 
			ActionDatePart, ProjectName
	)
	,
	ChicagoReport as
	(
		select 
			ActionDatePart
			,SUM(CreatedCount) as CreatedCountChicago
			,SUM(ClosedCount) as ClosedCountChicago
			,ProjectName
			,N'Чикаго' as ParentSpecialization
		from CommonReportGroupByDatePart
		where
			SpecializationId is not null
			and SpecializationId not in (select specializationId from @excludeSpecializationIdsChicago)
			and SpecializationId in (select new_specializationId from [ST_MSCRM].[dbo].[new_specializationBase](nolock) where new_parentSpecialization is not null and new_parentSpecialization = @chicagoParentSpecializationId)
		group by 
			ActionDatePart, ProjectName
	),
	DataExchangeReport as
	(
		select 
			ActionDatePart
			,SUM(CreatedCount) as CreatedCountDataExchange
			,SUM(ClosedCount) as ClosedCountDataExchange
			,ProjectName
			,N'Обмен данными' as ParentSpecialization
		from CommonReportGroupByDatePart
		where
			SpecializationId is not null
			and SpecializationId not in (select specializationId from @excludeSpecializationIdsDataExchange)
			and SpecializationId in (select new_specializationId from [ST_MSCRM].[dbo].[new_specializationBase](nolock) where new_parentSpecialization is not null and new_parentSpecialization = @dataExchangeParentSpecializationId)
		group by 
			ActionDatePart, ProjectName
	)

	INSERT INTO @result
	select
		COALESCE(M.ActionDatePart, C.ActionDatePart, D.ActionDatePart) ActionDatePart
		,ISNULL(M.CreatedCountMobileTrading, 0) CreatedCountMobileTrading
		,ISNULL(M.ClosedCountMobileTrading, 0) ClosedCountMobileTrading
		,RTRIM(COALESCE(M.ParentSpecialization, C.ParentSpecialization, D.ParentSpecialization)) ParentSpecialization
		,ISNULL(C.CreatedCountChicago, 0) CreatedCountChicago
		,ISNULL(C.ClosedCountChicago, 0) ClosedCountChicago
		,ISNULL(D.CreatedCountDataExchange, 0) CreatedCountDataExchange
		,ISNULL(D.ClosedCountDataExchange, 0) ClosedCountDataExchange
		,COALESCE(M.ProjectName, C.ProjectName, D.ProjectName) ProjectName
	from MobileTradingReport M
	full outer join ChicagoReport C on M.ProjectName = C.ProjectName and M.ActionDatePart = C.ActionDatePart and M.ParentSpecialization = C.ParentSpecialization
	full outer join DataExchangeReport D on M.ProjectName = D.ProjectName and M.ActionDatePart = D.ActionDatePart and M.ParentSpecialization = D.ParentSpecialization
	order by ActionDatePart desc

	RETURN 
END
