USE [SupportExtensions]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AddResolvedIncidentStatistics]
	@incidentId uniqueidentifier = null,
	@message nvarchar(100) output
AS
BEGIN
	SET NOCOUNT ON;

	if (@incidentId is null)
	begin
		set @message = 'WARN. IncidentId is null';
		return;
	end

	--declare @incidentId uniqueidentifier;
	declare @existIncidentId uniqueidentifier;

	select 
		top 1
		@existIncidentId = IncidentId
	from [SupportExtensions].[dbo].[ResolvedIncidentStatistics]
	where IncidentId = @incidentId

	if(OBJECT_ID('tempdb..#TempResolvedIncidentStatistics') is not null)
		drop table #TempResolvedIncidentStatistics

	select
		I.IncidentId					IncidentId
		,I.TicketNumber					TicketNumber
		,I.New_resolve					ResolvedDateTimeUTC
		,U.SystemUserId					OwnerId
		,U.FullName						OwnerFUllName
		,U.New_rol_tehpodderzhka		SupportRoleCode
		,SmbRole.Value					SupportRoleValue
		,U.new_positionHeld				PositionHeldCode
		,SmbPosition.Value				PositionHeldValue
		,SupportLine.SupportLineValue	SupportLine
		,Prj.svk_projectId				ProjectId
		,Prj.svk_name					ProjectName
		,A.AccountId					AccountId
		,A.Name							AccountName
		,Cc.New_ProbeId					ClientCardId
		,Cc.New_name					ClientCardName
		,C.ContactId					ContactId
		,C.FullName						ContactFullName
		,Spec.new_specializationId		SpecializationId
		,Spec.new_name					SpecializationName
		,Sub.SubjectId					SubjectId
		,Sub.Title						SubjectName
		,Fun.svk_functionalId			FunctionaId
		,Fun.svk_name					FunctionalName
		,I.CaseTypeCode					CaseTypeCode
		,SmbCaseType.Value				CaseTypeValue
		,I.StateCode					StateCode
		,SmbState.Value					StateValue
		,I.New_state_intenal			StateInternalCode
		,SmbStateInternal.Value			StateInternalValue
	into #TempResolvedIncidentStatistics
		from [ST_MSCRM].[dbo].[IncidentBase](nolock)I
		left join [ST_MSCRM].[dbo].[SystemUserBase](nolock)U on (U.SystemUserId = I.OwnerId)
		left join [ST_MSCRM].[dbo].[StringMapBase](nolock)SmbRole on (SmbRole.AttributeValue = U.New_rol_tehpodderzhka and SmbRole.AttributeName = 'New_rol_tehpodderzhka' and SmbRole.ObjectTypeCode = 8)
		left join [ST_MSCRM].[dbo].[StringMapBase](nolock)SmbPosition on (SmbPosition.AttributeValue = U.new_positionHeld and SmbPosition.AttributeName = 'new_positionHeld' and SmbPosition.ObjectTypeCode = 8)
		cross apply (select [SupportExtensions].[dbo].[GetSupportLineBySystemUserId](U.SystemUserId) SupportLineValue) SupportLine
		left join [ST_MSCRM].[dbo].[svk_projectBase](nolock)Prj on (Prj.svk_projectId = I.iok_KK_project)
		left join [ST_MSCRM].[dbo].[AccountBase](nolock)A on (A.AccountId = I.CustomerId)
		left join [ST_MSCRM].[dbo].[New_ProbeBase](nolock)Cc on (Cc.New_ProbeId = I.New_podderzhka_klienty)
		left join [ST_MSCRM].[dbo].[ContactBase](nolock)C on (C.ContactId = isnull(I.ResponsibleContactId, I.PrimaryContactId))
		left join [ST_MSCRM].[dbo].[new_specializationBase](nolock)Spec on (Spec.new_specializationId = I.new_specialization)
		left join [ST_MSCRM].[dbo].[SubjectBase](nolock)Sub on (Sub.SubjectId = I.SubjectId)
		left join [ST_MSCRM].[dbo].[svk_functionalBase](nolock)Fun on (Fun.svk_functionalId = I.svk_functional)
		left join [ST_MSCRM].[dbo].[StringMapBase](nolock)SmbCaseType on (SmbCaseType.AttributeValue = I.CaseTypeCode and SmbCaseType.AttributeName = 'CaseTypeCode' and SmbCaseType.ObjectTypeCode = 112)
		left join [ST_MSCRM].[dbo].[StringMapBase](nolock)SmbState on (SmbState.AttributeValue = I.StateCode and SmbState.AttributeName = 'StateCode' and SmbState.ObjectTypeCode = 112)
		left join [ST_MSCRM].[dbo].[StringMapBase](nolock)SmbStateInternal on (SmbStateInternal.AttributeValue = I.New_state_intenal and SmbStateInternal.AttributeName = 'New_state_intenal' and SmbStateInternal.ObjectTypeCode = 112)
	where I.IncidentId = @incidentId

	select * from #TempResolvedIncidentStatistics

	if (@existIncidentId is not null)
	begin
		update [SupportExtensions].[dbo].[ResolvedIncidentStatistics]
		set 
			ResolvedDateTimeUTC = T.ResolvedDateTimeUTC
			,OwnerId = T.OwnerId
			,OwnerFullName = T.OwnerFullName
			,SupportRoleCode = T.SupportRoleCode
			,SupportRoleValue = T.SupportRoleValue
			,PositionHeldCode = T.PositionHeldCode
			,PositionHeldValue = T.PositionHeldValue
			,SupportLine = T.SupportLine
			,ProjectId = T.ProjectId
			,ProjectName = T.ProjectName
			,AccountId = T.AccountId
			,AccountName =  T.AccountName
			,ClientCardId = T.ClientCardId
			,ClientCardName = T.ClientCardName
			,ContactId = T.ContactId
			,ContactFullName = T.ContactFullName
			,SpecializationId = T.SpecializationId
			,SpecializationName = T.SpecializationName
			,SubjectId = T.SubjectId
			,SubjectName = T.SubjectName
			,FunctionaId = T.FunctionaId
			,FunctionalName = T.FunctionalName
			,CaseTypeCode = T.CaseTypeCode
			,CaseTypeValue = T.CaseTypeValue
			,StateCode = T.StateCode
			,StateValue = T.StateValue
			,StateInternalCode = T.StateInternalCode
			,StateInternalValue = T.StateInternalValue
			,ReopeningCounter = isnull(S.ReopeningCounter, 0) + 1
		from [SupportExtensions].[dbo].[ResolvedIncidentStatistics] S
		left join #TempResolvedIncidentStatistics T on S.IncidentId = T.IncidentId
		where T.IncidentId = @incidentId
	end

	if (@existIncidentId is null)
	begin
		insert into [SupportExtensions].[dbo].[ResolvedIncidentStatistics](
			IncidentId
			,TicketNumber
			,ResolvedDateTimeUTC
			,OwnerId
			,OwnerFullName
			,SupportRoleCode
			,SupportRoleValue
			,PositionHeldCode
			,PositionHeldValue
			,SupportLine
			,ProjectId
			,ProjectName
			,AccountId
			,AccountName
			,ClientCardId
			,ClientCardName
			,ContactId
			,ContactFullName
			,SpecializationId
			,SpecializationName
			,SubjectId
			,SubjectName
			,FunctionaId
			,FunctionalName
			,CaseTypeCode
			,CaseTypeValue
			,StateCode
			,StateValue
			,StateInternalCode
			,StateInternalValue
		)
		select 
		*
		from #TempResolvedIncidentStatistics
	end

	if(OBJECT_ID('tempdb..#TempResolvedIncidentStatistics') is not null)
		drop table #TempResolvedIncidentStatistics

	set @message = 'success';
	return;
END
