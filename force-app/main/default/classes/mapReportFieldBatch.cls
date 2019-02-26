//
//	Class mapReportFieldBatch : generate a book containing, for a given object ('account' for instance), all the CUSTOM fields referenced in each report of the organization
//	Restrictions :
//		MultiBlock (aka joined) reports are not taken into account
//		'Event' objects not yet taken into account
//		custom objects not yet taken into account
//	
//	Author : Vincent Brenet, vbrenet@salesforce.com
//	Version 1 : April 28, 2017
//	
//	Instructions for use in anonymous execution console : 
//	mapReportFieldBatch instance = new mapReportFieldBatch (<object name>, [max report queries]);
//	ID theId = Database.ExecuteBatch(instance, [nb records per job]);
//	
global class mapReportFieldBatch implements Database.Batchable<SObject>, Database.stateful  {
    
    public Integer nbtoquery;
    public String analyzedObject;
    public List<String> scopedFields;	// set of object fields to be searched in reports
    public String book;
	Map<Id,Exception> exceptionMap;
    Integer nbCatchedExceptions;
    Integer totalNumberOfReports;
    Integer totalNumberOfObjectType;
    Integer numberOfReportIncludingCustomFields;
    
	static final Map<String,String> reportTypeToObject = new Map<String,String> {
		'Opportunity'	=>	'Opportunity'
		,'CaseList'		=>	'Case'
		,'AccountList'	=>	'Account'
		,'LeadList'		=>	'Lead'
		,'ContactList'	=>	'Contact'
		,'User'			=>	'User'
		,'SolutionList'	=>	'Solution'
		,'ReportList'	=>	'Report'
		,'CampaignList'	=>	'Campaign'
		,'DocumentList'	=>	'Document'
		,'Task'			=>	'Task'
    };
        
    static final Map<String,String> fieldNameConversionMap = new Map<String,String> {
        'IS_PERSON_ACCOUNT' =>	'IsPersonAccount'
		,'RECORDTYPE'		=>	'RecordTypeId'
		,'ACCOUNT_ID'		=>	'Id'
		,'CREATED_DATE'		=>	'CreatedDate'
		,'ORIGIN'			=>	'Origin'		// case origin
		,'OWNER'			=>	'OwnerId'
		,'STATUS'			=>	'Status'
		,'SUBJECT'			=>	'Subject'		// case subject
		,'TYPE'				=>	'Type'			// case type
		,'CASE_NUMBER'		=>	'CaseNumber'
		,'CREATED'			=>	'CreatedById'
		,'LAST_UPDATE_BY'	=>	'LastModifiedById'
		,'PRIORITY'			=>	'Priority'
		,'DESCRIPTION'		=>	'Description'
		,'REASON'			=>	'Reason'
		,'CASE_ID'			=>	'Id'
		,'CLOSED'			=>	'IsClosed'
		,'CLOSED_DATE'		=>	'ClosedDate'
		,'COMPANY'			=>	'Company'		// lead fields
		,'CONVERTED'		=>	'IsConverted'
		,'EMAIL'			=>	'Email'
		,'LEAD_SOURCE'		=>	'LeadSource'
		,'RATING'			=>	'Rating'
		,'ACCOUNT_NAME '	=>	'AccountId'		// opportunity fields
		,'CLOSE_DATE'		=>	'CloseDate'
		,'OPPORTUNITY_NAME'	=>	'Name'
		,'STAGE_NAME'		=>	'StageName'
		,'ACTIVE'			=>	'IsActive'		// user fields
		,'IDBIR__c'			=>	'ID_BIR__c'
		,'LAST_LOGIN'		=>	'LastLoginDate'
		,'NAME'				=>	'Name'
		,'PROFILE'			=>	'ProfileId'
		,'ROLE'				=>	'UserRoleId'
		,'USERNAME'			=>	'Username'
    };
//
//	constructor
//	
    public mapReportFieldBatch(String theObj, Integer nbtoquery){
        this.nbtoquery = nbtoquery;
        analyzedObject = theObj;
        nbCatchedExceptions = 0;
        totalNumberOfReports = 0;
        totalNumberOfObjectType = 0;
        numberOfReportIncludingCustomFields = 0;
        exceptionMap = new Map<Id,Exception>();
        scopedFields = initializeScopedFields(theObj);
        book = outputBookHeader();
    }
//
//	searched fields map initialization
//
    private List<String> initializeScopedFields(String theObj) {
        List<String> fields = new List<String>();
        
        String queryfields = 'Select QualifiedApiName From FieldDefinition Where EntityDefinition.QualifiedApiName = \'' + theObj + '\'' ;
		List<FieldDefinition> definitions = Database.query(queryfields);
        
        if (definitions != null && definitions.size() > 0){
            for (FieldDefinition fd : definitions) {
                if (fd.QualifiedApiName.endsWith('__c') || fd.QualifiedApiName.endsWith('__pc')) {
                    fields.add(fd.QualifiedApiName);
                }
            }
        }
        return fields;
    }
//
//	output heads of the columns of the book
//
    private String outputBookHeader() {
        String result;
        result = 'ReportId;Folder;ReportType;ApiName;FieldNumber;';
        for (String s : scopedFields)
            result += s + ';';
        result += '\n';
        return result;
    }
//
//	return true if the field parameter is referenced in the report parameter
//
    private Boolean getIsReferenced (String theField, Set<String> theCols) {
		Boolean isReferenced = false;
        
        for (String s : theCols) {
            if (s.containsAny('.')) {
                String curobj = s.substringbefore('.');
                String curfield = s.substringafter('.');
                if ((analyzedObject == 'Account') && (curobj == 'Contact')) {
                    curfield = curfield.removeEnd('__c');
                    curfield += '__pc';
                }
                if (theField == curfield)
                    return true;
            }
        }  
        return isReferenced;
    }
//
// compute the name of the main object of the report
//
    private String getMainObjectName(String reportTypeName){
        String objName = reportTypeName;
        
        if (reportTypeName == 'Activity') // in this case, the object is either a Task or an Event
            return 'Task';
        
        if (reportTypeToObject.containsKey(reportTypeName))
            return reportTypeToObject.get(reportTypeName);
        
        if (reportTypeName.containsAny('@$')){
			String firstStrip = reportTypeName.substringAfter('$');
			if (String.isEmpty(firstStrip)) firstStrip = reportTypeName;
			String secondStrip = firstStrip.substringBefore('@');
			if (String.isEmpty(secondStrip)) secondStrip = firstStrip;
			objName = secondStrip;
			if (reportTypeToObject.containsKey(objname))
				objName = reportTypeToObject.get(objname);           
        } else {	// two cases remains : custom report types ending by __c and composites like CaseActivity or AccountAsset
            if (reportTypeName.endsWith('__c')){ // custom report types
				// *************** to be completed ***************
            } else { // composites reports
				if (reportTypeName.contains('Activity'))
                    objName = 'Task';
                else if (reportTypeName == 'OpportunityLead')
                    objName = 'Lead' ;
                else if (reportTypeName.endsWith('AuditHistory'))
                    objName = reportTypeName.substringBefore('AuditHistory');
                else {
                    List<String> parts = reportTypeName.splitByCharacterTypeCamelCase();
                    if (parts != null && parts.size() > 0)
                        objName = parts[0];
                }
            }
        }
        return objName;
    }
//
//	compute a book entry for a single report
//
    private void computeReportbookEntry (Id theId, String reportName, String folderName) {
        
        Reports.ReportMetadata rmeta = Reports.ReportManager.describeReport(theId).getReportMetadata();
        String reportTypeName = rmeta.getReportType().getType();

        String objName = getMainObjectName(reportTypeName);
        
        if (objName == analyzedObject) {
            totalNumberOfObjectType++;
            
            // compute set of referenced report fields to be searched : columns, filters, date filter
			Set<String> referencedItems = new Set<String>(rmeta.getDetailColumns());
            List<Reports.ReportFilter> theFilters = rmeta.getReportFilters();
            for (Reports.ReportFilter rf : theFilters)
                referencedItems.add(rf.getColumn());
            Reports.StandardDateFilter df = rmeta.getStandardDateFilter();
            if (df != null) {
                String s = df.getcolumn();
                if (s != null)
					referencedItems.add(s);
            }
            // then for each of them mark the report book entry
            if (referencedItems.size() > 0) {
 				Integer nbFound = 0;
        		String bookEntry = ' ';
        		for (String field : scopedFields) {
            		Boolean isReferenced = getIsReferenced(field, referencedItems);
                	if (isReferenced) {
                    	nbFound++;
                    	bookEntry += '1;';                
               		}
                    else {
                        bookEntry += ' ;'; 
                    } 
        		}
				bookEntry += '\n';
                
                if (nbFound > 0) {
                    numberOfReportIncludingCustomFields++;
                    book += theId + ';' + folderName + ';' + reportTypeName + ';' + reportName + ';' + nbFound + ';' + bookEntry.removeStart(' ');                    
                }

            }
     	 }
    }
//
// implementation of start batchable interface method
//
    global Database.QueryLocator start(Database.BatchableContext ctx){
		String theQuery = 'Select DeveloperName, FolderName from Report where format != \'MultiBlock\' ';
        //	Query string for testing :
        //	String theQuery = 'Select DeveloperName, FolderName from Report where format != \'MultiBlock\' and DeveloperName like \'testfield%\'';
        if (nbtoquery > 0)
            theQuery += 'Limit ' + nbtoquery;
        return Database.getQueryLocator(theQuery);        
    }
//
// implementation of execute batchable interface method
//
    global void execute(Database.BatchableContext ctx, List<SObject> sobjects){
        List<Report> reports = (List<Report>)sobjects;
        for (Report r : reports) {
            totalNumberOfReports++;
            try {
            computeReportbookEntry(r.id, r.developerName,r.folderName);                
            }
            catch (exception e) {
                nbCatchedExceptions++;
                if (exceptionMap.size() < 20)
                    exceptionMap.put(r.id,e);
            }
        }

    }
//
//	compute body of the final email
//
    private String outputBody(){
        String body = 'Please see attached csv file\n\n';
        if (nbCatchedExceptions > 0) {
            body += 'Number of catched exceptions : ' + nbCatchedExceptions + '\n';
        	for (Id currid : exceptionMap.keyset()){
            	exception e = exceptionMap.get(currid);
            	body += 'Report : ' + currid + ' Type : ' + e.getTypeName() + '\n';
            	body += 'Exception Message : ' + e.getMessage() + '\n';
        	}
        }
        body += '\n Total number of reports read : ' + totalNumberOfReports + '\n';
		body += '\n Total number of reports of type ' + analyzedObject + ': ' + totalNumberOfObjectType + '\n';
        body += '\n Total number of reports including at least one custom field : ' + numberOfReportIncludingCustomFields + '\n';

        return body;
    }
//
// implementation of finish batchable interface method
// email construction and sending
// 
    global void finish(Database.BatchableContext ctx){
        List<Organization> orgs = [Select name,isSandbox from Organization Limit 1];
        String subject = 'Custom ' + analyzedObject + ' fields referenced in Reports for organization ' + orgs[0].name;
        if (orgs[0].isSandbox) subject += ' (sandbox)';
        Map<String,String> fileMap = new Map<String,String>();
        fileMap.put(analyzedObject + 'FieldsInReports.csv', book);
        EmailManager.sendMailWithAttachedFiles(UserInfo.getUserEmail(), subject, outputBody(), fileMap);        
    }
}