global with sharing class TestRunnerJob implements mba_services.IRunAsyncJob{

    global mba_services.AsyncJobServices.AsyncJobResult run(mba_services__Async_Job__c asyncJob){
        Map<String, object> m_params = (Map<String, object>) JSON.deserializeUntyped(asyncJob.mba_services__Job_Params__c);
        
        List<object> classesToRun = (List<object>) m_params.get('classesToRun');
        
        List<ApexTestQueueItem> apexTestQueueItemList = new List<ApexTestQueueItem>();
        for (object clsId : classesToRun){
            
            apexTestQueueItemList.add(new ApexTestQueueItem(ApexClassId = (Id) clsId));
        }

        insert apexTestQueueItemList;

        // Get the job ID of the first queue item returned.
        ApexTestQueueItem item = [SELECT ParentJobId FROM ApexTestQueueItem WHERE Id = :apexTestQueueItemList[0].Id LIMIT 1];

        //Add new job that will check the status in 5 minutes
        mba_services__Async_Job__c newChildJob = mba_services.AsyncJobServices.addAsyncJob (
            'Check Test Results', 'Apex', 'TestRunnerCheckStatusJob', 'High', '{"jobId": "' + item.parentjobid + '"}', null, false);
            
        newChildJob.mba_services__Sequence__c = 2;
        newChildJob.mba_services__Status__c = 'Pending';
        newChildJob.mba_services__Parent_Job__c = asyncJob.mba_services__Parent_Job__c;
        newChildJob.mba_services__Time_to_Run__c = System.now().addMinutes(5);
        newChildJob.mba_services__Switch_Off_Repeated__c = true;
        insert newChildJob;

        return new mba_services.AsyncJobServices.AsyncJobResult(true, 'Tests Scheduled', null);
    }
}