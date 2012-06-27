/********************************************************************
* Trigger: HubSpotActivity_AfterInsert
*
* Usage: Executed by Salesforce.com after a new 
*        HubSpot_Inc__HubSpot_Activity__c is inserted. Passes a list
*        of Ids to createTaskFromActivity.makeTasksFuture. Excludes
*        activities that include the word import in the title.

* Unit test coverage provided in CreateTaskFromActivity class.
*
********************************************************************/
trigger HubSpotActivity_AfterInsert on HubSpot_Inc__HubSpot_Activity__c (after insert) {
    List<Id> hsActIds = new List<Id>();
    
    //Loop through new activities and add the associated hubspot intel ids to list
    for (HubSpot_Inc__HubSpot_Activity__c hsA : trigger.new) {
    	//Filter out activities that are just imports 
    	if (!hsA.HubSpot_Inc__Title__c.toLowerCase().contains('import')) {
        	hsActIds.add(hsA.id);  
    	}
    } 
    createTaskFromActivity.makeTasksFuture(hsActIds);
}