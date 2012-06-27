HubSpot-Salesforce-Activities
=============================

An apex class and trigger that enables Tasks to be created on Contacts and Leads in Salesforce.com when using the HubSpot Salesforce Connector V2

Also allows you to trigger an email via workflow that goes to the Lead or Contact Owner when a new HubSpot Activity is logged in Salesforce.com by the connector

Instructions
============

Pre-Installation
================
1.  Make sure that the HubSpot Salesforce Connector V2 is installed in your Salesforce.com org
2.  Add a custom field to the HubSpot Activity object (Create->Objects) that will be used to trigger the workflow email
	a. Name: Notify Owner
	b. Type: Checkbox
3.  Add a custom field to the HubSpot Activity object (Create->Object) that will allow a link to the Contact or Lead to be added to the email
	a. Name: Related Record Link
	b. Type: Formula (Text)
	c. Formula text:

	HYPERLINK((if (ISBLANK(HubSpot_Inc__HubSpot_Intelligence__r.HubSpot_Inc__Contact__c), HubSpot_Inc__HubSpot_Intelligence__r.HubSpot_Inc__Lead__r.Id, HubSpot_Inc__HubSpot_Intelligence__r.HubSpot_Inc__Contact__r.Id)), 'Related Record')

4.  Add a new email template (Personal Setup->Email->My Templates)
	a. Type: HTML or Custom
	a. Sample template name: Notify HubSpot Activity Owner
	b. Sample template subject: New HubSpot Activity: {!HubSpot_Inc__HubSpot_Activity__c.HubSpot_Inc__Title__c}
	c. Sample template body: 

	A lead or contact you own submitted a form.<br/>

	Lead/Contact: {!HubSpot_Inc__HubSpot_Activity__c.Related_Record_Link__c}<br/>

	Form Name: {!HubSpot_Inc__HubSpot_Activity__c.HubSpot_Inc__Title__c}<br/>

	Form Data: {!HubSpot_Inc__HubSpot_Activity__c.HubSpot_Inc__Body__c}<br/>

5.  Add a new Workflow Rule (Create->Workflow->Workflow Rules) to send the email:
	a. Object: HubSpot Activity
	b. Rule Name: Email owner when created
	c. Evaluate Rule: When a record is created, or when a record is edited and did not previously meet the rule criteria
	d. Run this rule if the following: Criteria are met
	e. Field: Notify Owner 
	f. Operator: Equals 
	g. Value: True
	(Save and Next)
	h. Add workflow action: New Email Alert
	i. Description: Email HubSpot Activity Owner
	j. Email Template: The template you created in step 4
	k. Recipient Type: Owner
	l. Recipients: Add HubSpot Activity Owner
	(Save)
	(Done)
	(Activate)


