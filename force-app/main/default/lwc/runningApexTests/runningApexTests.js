import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import initRunning from '@salesforce/apex/RunningApexTests.initRunning';
import setupTestRun from '@salesforce/apex/RunningApexTests.setupTestRun';
import abortJob from '@salesforce/apex/RunningApexTests.abortJob';


export default class RunningApexTests extends LightningElement {

    @track testOptions;
    @track completedJobs;
    @track runningJobs;
    @track showCompleted = false;
    @track showRunning = false;

    @track runProp = {
        jobName: 'Test Job',
        classesToRun: undefined,
        timeToRun: undefined,
        isRepeated: false,
        intervalType: undefined,
        intervalUnits: undefined
    };

    get intervalTypeOptions(){
        return [
            {label: 'Daily', value: 'Daily'},
            {label: 'Weekly', value: 'Weekly'},
            {label: 'Monthly', value: 'Monthly'},
            {label: 'Hourly', value: 'Hourly'}
        ];
    }

    connectedCallback(){
        if(! this.testOptions){
            initRunning().then(
                result =>{
                    this.getInitResult(result);                
                }
            );
        }
    }

    getInitResult(res){
        this.testOptions = res.testOptions;
        this.completedJobs = res.completedJobs;
        this.runningJobs = res.runningJobs;

        this.showCompleted = this.completedJobs.length > 0;
        this.showRunning = this.runningJobs.length > 0;
        for(let cJob in this.completedJobs){
            this.completedJobs[cJob]['errors'] = JSON.parse(this.completedJobs[cJob].mba_services__JSON_Data__c);
            this.completedJobs[cJob]['status'] = this.completedJobs[cJob].errors.length > 0 ? 'Failed' : 'Success';
        }
    }

    runPropHandler(event){
        if(event.currentTarget.dataset.prop == 'isRepeated'){
            this.runProp[event.currentTarget.dataset.prop] = event.detail.checked;
        }
        else{
            this.runProp[event.currentTarget.dataset.prop] = event.detail.value;
        }
        console.log('this.runProp:: ' + JSON.stringify(this.runProp));
    }

    runTestHandler(){

        setupTestRun({param: this.runProp}).then(
            result =>{
                this.dispatchEvent(new ShowToastEvent({title: 'Success', message: 'Tests Scheduled Successfully', variant: "success"}));

                this.getInitResult(result);                
            }
        );
    }

    aborTestRun(event){
        abortJob({jobId: event.currentTarget.dataset.jid}).then(
            result =>{
                this.dispatchEvent(new ShowToastEvent({title: 'Success', message: 'Tests aborted', variant: "success"}));

                this.getInitResult(result);                
            }
        );
    }
}