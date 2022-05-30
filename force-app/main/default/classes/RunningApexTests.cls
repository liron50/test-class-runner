public with sharing class RunningApexTests {

    @AuraEnabled
    public static Map<String, object> initRunning(){
        Map<String, object> retData = new Map<String, object>();

        List<Map<String, String>> testOptions = new List<Map<String, String>>();

        for(ApexClass cls : [SELECT Id,Name,body FROM ApexClass WHERE /*Name LIKE '%Test' and*/ NamespacePrefix = null ORDER BY Name]){
            if(cls.body.toLowerCase().contains('@istest')){
                testOptions.add(new Map<String, String>{'value'=> cls.Id, 'label'=>cls.Name});
            }
        }

        List<mba_services__Async_Job__c> runningJobs = [    SELECT Id,mba_services__Parent_Job__r.mba_services__Is_Repeated__c,mba_services__Parent_Job__r.mba_services__Repeated_Interval__c,mba_services__Parent_Job__r.mba_services__Time_to_Run__c,
                                                                mba_services__Parent_Job__r.mba_services__Subject__c,mba_services__Parent_Job__r.mba_services__Repeated_Type__c,mba_services__Job_Params__c,mba_services__Parent_Job__c
                                                            FROM mba_services__Async_Job__c
                                                            WHERE mba_services__Class_Runner__c = 'TestRunnerJob'
                                                            AND mba_services__Parent_Job__r.mba_services__Status__c = 'Pending'
                                                            ORDER BY mba_services__Parent_Job__r.mba_services__Subject__c];

        List<mba_services__Log_Message__c> completedJobs = [SELECT mba_services__JSON_Data__c,mba_services__Subject__c
                                                            FROM mba_services__Log_Message__c
                                                            WHERE mba_services__Tag__c = 'test_job_result'
                                                            AND CreatedDate = LAST_N_DAYS:30
                                                            ORDER BY CreatedDate DESC];

        retData.put('testOptions', testOptions);
        retData.put('runningJobs', runningJobs);
        retData.put('completedJobs', completedJobs);

        return retData;
    }

    @AuraEnabled
    public static Map<String, object> setupTestRun(Map<String, object> param){
        System.debug('param:: ' + param);
        

        Map<String, object> m_params = new Map<String, object>();
        m_params.put('classesToRun', param.get('classesToRun'));
    
        //Create child jobs
        mba_services__Async_Job__c runJob = mba_services.AsyncJobServices.addAsyncJob (
            'Run Tests', 'Apex', 'TestRunnerJob', 'High', JSON.serialize(m_params), null, false);

        Boolean isRepeated = Boolean.valueOf(param.get('isRepeated'));

        mba_services.AsyncJobServices.addAsyncJobWithChild(
            String.valueOf(param.get('jobName')), 
            param.get('timeToRun') != null ? ( (DateTime)JSON.deserialize('"' + String.valueOf(param.get('timeToRun')) + '"', DateTime.class)) : System.now(),
            isRepeated,
            isRepeated ? String.valueOf(param.get('intervalType')) : null,
            isRepeated ? Integer.valueOf(param.get('intervalUnits')) : null,
            new list<mba_services__Async_Job__c>{runJob});

        return initRunning();
    }

    @AuraEnabled
    public static Map<String, object> abortJob(String jobId){
        String retMsg = mba_services.AsyncJobServices.abortScheduleJob(jobId);
        return initRunning();
    }
}
