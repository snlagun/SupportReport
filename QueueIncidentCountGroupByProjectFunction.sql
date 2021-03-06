USE [ST_MSCRM]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [dbo].[QueueIncidentCountGroupByProjectFunction] ()
RETURNS 
@result table
(
	CreateCountMobileTrading int
	,ClosedCountMobileTrading int
	,QueueCountMobileTrading int
	,AwaitClientCheckCountMobileTrading int
	,DefectEditingCountMobileTrading int
	,CreateCountChicago int
	,ClosedCountChicago int
	,QueueCountChicago int
	,AwaitClientCheckCountChicago int
	,DefectEditingCountChicago int
	,CreateCountDataExchange int
	,ClosedCountDataExchange int
	,QueueCountDataExchange int
	,AwaitClientCheckCountDataExchange int
	,DefectEditingCountDataExchange int
	,ProjectName nvarchar(200)
)
AS
BEGIN
	declare @startDate dateTime = DATEADD(hh, -(DATEDIFF( hh , GETUTCDATE() , GETDATE())), CAST(CAST(GETDATE() AS DATE) AS DATETIME)) -- Начало дня минус два часа, т.к. в таблицах время в UTC

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
			SUM
			(
				case 
					when I.CreatedOn >= @startDate then 1
					else 0
				end
			) CreateCount
			,SUM
			(
				case 
					when (I.StateCode != 0 and I.New_resolve >= @startDate) then 1
					else 0
				end
			) ClosedCount
			,SUM
			(
				case 
					when
						(
							I.StateCode = 0 and 
								(
									I.New_state_intenal = @registrated 
									or I.New_state_intenal = @running
									or I.New_state_intenal = @sleeping
									or I.New_state_intenal = @answerReceived
									or I.New_state_intenal = @reEditing
									or I.New_state_intenal = @awaitingAnswerFromClient
									or I.New_state_intenal = @awaiting
									or I.New_state_intenal = @waitingFirmwareUpdate
								)
						) then 1
					else 0
				end
			) QueueCount
			,SUM
			(
				case 
					when
						(
							(I.StateCode = 0 and I.New_state_intenal = @closed)
							or 
							(
								I.StateCode = 0 and I.New_state_intenal = @awaitClientCheck 
							)
						) then 1
					else 0
				end
			) AwaitClientCheckCount
			,SUM
			(
				case 
					when (I.StateCode = 0 and I.New_state_intenal = @defectEditing) then 1
					else 0
				end
			) DefectEditingCount
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
		group by svk_name, new_specialization
	)
	,
	MobileTradingReport as
	(
		select 
			SUM(CreateCount) as CreateCountMobileTrading
			,SUM(ClosedCount) as ClosedCountMobileTrading
			,SUM(QueueCount) as QueueCountMobileTrading
			,SUM(AwaitClientCheckCount) as AwaitClientCheckCountMobileTrading
			,SUM(DefectEditingCount) as DefectEditingCountMobileTrading
			,ProjectName
		from CommonReport
		where
			SpecializationId is not null
			and SpecializationId not in (select specializationId from @excludeSpecializationIdsMobileTrading)
			and SpecializationId in (select new_specializationId from [ST_MSCRM].[dbo].[new_specializationBase](nolock) where new_parentSpecialization is not null and new_parentSpecialization = @mobileTradingParentSpecializationId)
		group by 
			ProjectName
	)
	,
	ChicagoReport as
	(
		select 
			SUM(CreateCount) as CreateCountChicago
			,SUM(ClosedCount) as ClosedCountChicago
			,SUM(QueueCount) as QueueCountChicago
			,SUM(AwaitClientCheckCount) as AwaitClientCheckCountChicago
			,SUM(DefectEditingCount) as DefectEditingCountChicago
			,ProjectName
		from CommonReport
		where
			SpecializationId is not null
			and SpecializationId not in (select specializationId from @excludeSpecializationIdsChicago)
			and SpecializationId in (select new_specializationId from [ST_MSCRM].[dbo].[new_specializationBase](nolock) where new_parentSpecialization is not null and new_parentSpecialization = @chicagoParentSpecializationId)
		group by 
			ProjectName
	),
	DataExchangeReport as
	(
		select 
			SUM(CreateCount) as CreateCountDataExchange
			,SUM(ClosedCount) as ClosedCountDataExchange
			,SUM(QueueCount) as QueueCountDataExchange
			,SUM(AwaitClientCheckCount) as AwaitClientCheckCountDataExchange
			,SUM(DefectEditingCount) as DefectEditingCountDataExchange
			,ProjectName
		from CommonReport
		where
			SpecializationId is not null
			and SpecializationId not in (select specializationId from @excludeSpecializationIdsDataExchange)
			and SpecializationId in (select new_specializationId from [ST_MSCRM].[dbo].[new_specializationBase](nolock) where new_parentSpecialization is not null and new_parentSpecialization = @dataExchangeParentSpecializationId)
		group by 
			ProjectName
	)

	INSERT INTO @result
	select 
		ISNULL(M.CreateCountMobileTrading, 0) CreateCountMobileTrading
		,ISNULL(M.ClosedCountMobileTrading, 0) ClosedCountMobileTrading
		,ISNULL(M.QueueCountMobileTrading, 0) QueueCountMobileTrading
		,ISNULL(M.AwaitClientCheckCountMobileTrading, 0) AwaitClientCheckCountMobileTrading
		,ISNULL(M.DefectEditingCountMobileTrading, 0) DefectEditingCountMobileTrading
		,ISNULL(C.CreateCountChicago, 0) CreateCountChicago
		,ISNULL(C.ClosedCountChicago, 0) ClosedCountChicago
		,ISNULL(C.QueueCountChicago, 0) QueueCountChicago
		,ISNULL(C.AwaitClientCheckCountChicago, 0) AwaitClientCheckCountChicago
		,ISNULL(C.DefectEditingCountChicago, 0) DefectEditingCountChicago
		,ISNULL(D.CreateCountDataExchange, 0) CreateCountDataExchange
		,ISNULL(D.ClosedCountDataExchange, 0) ClosedCountDataExchange
		,ISNULL(D.QueueCountDataExchange, 0) QueueCountDataExchange
		,ISNULL(D.AwaitClientCheckCountDataExchange, 0) AwaitClientCheckCountDataExchange
		,ISNULL(D.DefectEditingCountDataExchange, 0) DefectEditingCountDataExchange
		,COALESCE(M.ProjectName, C.ProjectName,D.ProjectName) ProjectName
	from MobileTradingReport M
	full outer join ChicagoReport C on M.ProjectName = C.ProjectName
	full outer join DataExchangeReport D on M.ProjectName = D.ProjectName
	order by ProjectName
	
	RETURN 
END
