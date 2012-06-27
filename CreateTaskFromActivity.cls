/********************************************************************
* Class: CreateTaskFromActivity
*
* Usage: To be called from a trigger on the After Insert event of the
*        HubSpot__HubSpot_Activity__c custom object from the HubSpot
*        Salesforce Integration package. 
*        (See HubspotActivity_AfterInsert.trigger)
*
*        Calling the static CreateTaskFromActivity.makeTasks()
*        method with a list of HubSpot_Activity__c record IDs will
*        cause Salesforce to create Tasks attached to the Lead or Contact
*        based on the data in the HubSpot_Activity__c record.
*
* Prerequisites: The HubSpot Salesforce integration must be installed
*        in the Salesforce.com org and you must add a new custom checkbox
*        field named Notify_Owner__c to the HubSpot_Activity__c object 
*        to allow creation of these activities to trigger a custom workflow 
*        that will notify the owner that a new HubSpot activity has been created.
*
********************************************************************/
public with sharing class CreateTaskFromActivity {
    
    /****************************************************************
    * makeTasksFuture
    *
    * Takes a list of HubSpot_Activity__c ids and uses the date in the
    * activities and the related HubSpot_Intelligence__c records to 
    * create standard Salesforce.com Tasks attached to Leads or Contacts
    * (@future is defined to allow other HubSpot processing to complete
    * before attempting to create the records so that all necessary
    * data will be present at the time of execution when executing from
    * the trigger)
    *
    * @param List<Id> hsActIds: The list of ids of the HubSpot Activities
    *        being created
    *
    ****************************************************************/
    @future
    public Static Void makeTasksFuture(List<Id> hsActIds) {
        makeTasks(hsActIds);
    }
    
    /****************************************************************
    * makeTasks
    *
    * Takes a list of HubSpot_Activity__c ids and uses the date in the
    * activities and the related HubSpot_Intelligence__c records to 
    * create standard Salesforce.com Tasks attached to Leads or Contacts
    *
    * @param List<Id> hsActIds: The list of ids of the HubSpot Activities
    *        being created
    *
    ****************************************************************/
    public Static Void makeTasks(List<Id> hsActIds) {
        //Map to store hubspot intel id / contact or lead id mapping
        Map<Id, Id> HubSpotIntelLeadContactIds = new Map<Id, Id>();
        
        //Lists to store lead and contact ids
        List<Id> contactIds = new List<Id>();
        List<Id> leadIds = new List<Id>();
        Map<Id,Id> ownerIds = new Map<Id, Id>();
        
        
        //Set to store hubspot intel ids associated to activities in trigger
        Set<Id>HubSpotIntelIds = new Set<Id>();
        
        List<HubSpot_Inc__HubSpot_Activity__c> hsActivities = [select id,
                                                                      HubSpot_Inc__HubSpot_Intelligence__c,
                                                                      HubSpot_Inc__Title__c,
                                                                      HubSpot_Inc__Activity_Date__c,
                                                                      HubSpot_Inc__Body__c,
                                                                      HubSpot_Inc__Activity_Type__c,
                                                                      OwnerId,
                                                                      Notify_Owner__c
                                                               from HubSpot_Inc__HubSpot_Activity__c
                                                               where id in:hsActIds];
                                                              
        
        //Loop through new activities and add the associated hubspot intel ids to list
        for (HubSpot_Inc__HubSpot_Activity__c hsA : hsActivities) {
            if (hsA.HubSpot_Inc__HubSpot_Intelligence__c != null) {
                HubSpotIntelIds.add(hsA.HubSpot_Inc__HubSpot_Intelligence__c);
            }   
        }
        
        //Query hubspot intels to get lead and contact ids
        List<HubSpot_Inc__HubSpot_Intelligence__c> hsIntels = [select id, 
                                                                      HubSpot_Inc__Lead__c, 
                                                                      HubSpot_Inc__Contact__c 
                                                               from HubSpot_Inc__HubSpot_Intelligence__c
                                                               where id in :HubSpotIntelIds];
        
        //go through intels and store intel id and contact or lead id in map
        //Also store lead and contact IDs in lists to retrieve record owner info and store in map
        for (HubSpot_Inc__HubSpot_Intelligence__c hsIntel : hsIntels) {
            if (hsIntel.HubSpot_Inc__Contact__c != null) {
                HubSpotIntelLeadContactIds.put(hsIntel.id, hsIntel.HubSpot_Inc__Contact__c);
                contactIds.add(hsIntel.HubSpot_Inc__Contact__c);
            } else if (hsIntel.HubSpot_Inc__Lead__c != null) {
                HubSpotIntelLeadContactIds.put(hsIntel.id, hsIntel.HubSpot_Inc__Lead__c);
                leadIds.add(hsIntel.HubSpot_Inc__Lead__c);
            }
        }
        
        //Get lead and contact owner info and store in map
        if (contactIds.size()>0) {
            List<Contact> contacts = [select id, 
                                             ownerId
                                      from Contact
                                      where id in:contactIds];
            for (Contact c : contacts) {
                ownerIds.put(c.Id, c.OwnerId);
            }
        }
        
        if (leadIds.size()>0) {
            List<Lead> leads = [select id, 
                                             ownerId
                                      from Lead
                                      where id in:leadIds];
            for (Lead l : leads) {
                ownerIds.put(l.Id, l.OwnerId);
            }
        }
              
        //loop through new activities and create tasks
        List<Task> newTasks = new List<Task>();
        List<HubSpot_Inc__HubSpot_Activity__c> updateHSAs = new List<HubSpot_Inc__HubSpot_Activity__c>();
        for (HubSpot_Inc__HubSpot_Activity__c hsA : hsActivities) {
            if (HubSpotIntelLeadContactIds.containsKey(hsA.HubSpot_Inc__HubSpot_Intelligence__c)){
                Task newTask = new Task();
                //Populate task fields with data from activity
                newTask.whoId = HubSpotIntelLeadContactIds.get(hsA.HubSpot_Inc__HubSpot_Intelligence__c);
                newTask.Subject = hsA.HubSpot_Inc__Title__c;
                newTask.Description = hsA.HubSpot_Inc__Body__c;
                newTask.ActivityDate = Date.valueOf(hsA.HubSpot_Inc__Activity_Date__c);
                newTask.Status = 'Completed';
                newTask.OwnerId = ownerIds.get(HubSpotIntelLeadContactIds.get(hsA.HubSpot_Inc__HubSpot_Intelligence__c));
                /*
                add more fields here
                */
                newTasks.add(newTask);
                
                //Add owner and notification flag to HubSpot Activity
                hsa.OwnerId = newTask.OwnerId;
                if (hsa.HubSpot_Inc__Activity_Type__c == 'Form Submission') {
                    hsa.Notify_Owner__c = true;
                }
                updateHSAs.add(hsa);               
            }
        }
        
        //if there are new tasks, insert them
        if (newTasks.size()>0) {
            insert newTasks;
        }
        
        //if there are hsas to update, update them
        if (updateHSAs.size()>0) {
            update updateHSAs;
        }
    }
    
    /*********************************************
    * Unit test
    *********************************************/ 
    @isTest(SeeAllData=true)
    public static void doTest() {
        //Create a test lead
        Lead l = new Lead();
        l.firstname = 'Test';
        l.lastname = 'Lead';
        l.email = 'testlead@example.com';
        l.company = 'Test Lead Company';
        insert l;
        
        l = [select id, ownerid from Lead where id =:l.id];
        
        //Create a test HubSpot Intelligence object
        HubSpot_Inc__HubSpot_Intelligence__c hsi = new HubSpot_Inc__HubSpot_Intelligence__c();
        hsi.HubSpot_Inc__guid__c = 'testguid';
        hsi.HubSpot_Inc__lead__c = l.id;
        insert hsi;
        
        //Create a test HubSpot Activity object
        HubSpot_Inc__HubSpot_Activity__c hsa = new HubSpot_Inc__HubSpot_Activity__c();
        hsa.HubSpot_Inc__Activity_Date__c = Datetime.now();
        hsa.HubSpot_Inc__Activity_Type__c = 'Form Submission';
        hsa.HubSpot_Inc__Activity_Guid__c = 'testguid';
        hsa.HubSpot_Inc__Body__c = 'This is the activity body';
        hsa.HubSpot_Inc__Title__c = 'Form Submission 12345';
        hsa.HubSpot_Inc__HubSpot_Intelligence__c = hsi.id;
        insert hsa;
        
        //Execute the code
        List<Id> hsaId = new List<Id>();
        hsaId.add(hsa.Id);
        CreateTaskFromActivity.makeTasks(hsaId);
        
        //Get Task object from lead
        Task t = [select whoId,
                         subject,
                         description,
                         activitydate,
                         status,
                         notify_owner__c,
                         ownerid
                  from Task
                  where whoId =:l.id
                  limit 1];
                  
        //Verify that Task contains same data as HubSpot Activity
        System.assertEquals(hsi.HubSpot_Inc__lead__c, t.whoId);
        System.assertEquals(hsa.HubSpot_Inc__Title__c, t.subject);
        System.assertEquals(hsa.HubSpot_Inc__Body__c, t.description);
        System.assertEquals(l.ownerId, t.ownerId);
        System.assertEquals('Completed', t.status);
    }
}