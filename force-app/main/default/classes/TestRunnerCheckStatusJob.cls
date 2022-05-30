global with sharing class TestRunnerCheckStatusJob implements mba_services.IRunAsyncJob{

    global mba_services.AsyncJobServices.AsyncJobResult run(mba_services__Async_Job__c asyncJob){
        mba_services__Async_Job__c thisJob = [  SELECT Id,mba_services__Job_Params__c,mba_services__Parent_Job__c,mba_services__Sequence__c,mba_services__Parent_Job__r.mba_services__Subject__c
                                                FROM mba_services__Async_Job__c 
                                                WHERE Id = :asyncJob.Id];

        Map<String, object> m_params = (Map<String, object>) JSON.deserializeUntyped(thisJob.mba_services__Job_Params__c);
        
        String jobId = String.valueOf(m_params.get('jobId'));
        
        Boolean foundUncompleteItem = false;

        
        for (ApexTestQueueItem item : [ SELECT ApexClass.Name, Status, ExtendedStatus 
                                        FROM ApexTestQueueItem 
                                        WHERE ParentJobId=:jobId]) {
            String extStatus = item.extendedstatus == null ? '' : item.extendedStatus;
            System.debug(item.ApexClass.Name + ': ' + item.Status + extStatus);

            if(item.Status != 'Completed' && item.Status != 'Failed'){
                foundUncompleteItem = true;
            }
        }
        
        
        if(foundUncompleteItem){
            //Add new job that will check the status in 5 minutes
            mba_services__Async_Job__c newChildJob = mba_services.AsyncJobServices.addAsyncJob (
                'Check Test Results', 'Apex', 'TestRunnerCheckStatusJob', 'High', thisJob.mba_services__Job_Params__c, null, false);
                
            newChildJob.mba_services__Sequence__c = thisJob.mba_services__Sequence__c + 1;
            newChildJob.mba_services__Status__c = 'Pending';
            newChildJob.mba_services__Parent_Job__c = thisJob.mba_services__Parent_Job__c;
            newChildJob.mba_services__Time_to_Run__c = System.now().addMinutes(5);
            newChildJob.mba_services__Switch_Off_Repeated__c = true;
            insert newChildJob;
        }
        else{
            //Get the result and update in the parent job
            List<ApexTestResult> outputRes = [  SELECT Id,Outcome, ApexClass.Name, MethodName, Message, StackTrace 
                                                FROM ApexTestResult 
                                                WHERE AsyncApexJobId=:jobId
                                                AND Outcome != 'Pass'];

            //Create log message that will hold the result
            mba_services__Log_Message__c outputResult = new mba_services__Log_Message__c(
    	        mba_services__Log_Type__c = 'Process',
	            mba_services__Log_Level__c = 'Event',
	            mba_services__Related_Record_Id__c = jobId,
	            mba_services__Subject__c = thisJob.mba_services__Parent_Job__r.mba_services__Subject__c,
                mba_services__Tag__c = 'test_job_result',
                mba_services__JSON_Data__c = JSON.serialize(outputRes));
            insert outputResult;
        }

        return new mba_services.AsyncJobServices.AsyncJobResult(true, 'Tests Scheduled', null);
    }
}