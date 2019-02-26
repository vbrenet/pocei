//
// Class : reportBookBatch
// Author : Vincent Brenet, vbrenet@salesforce.com
// 
// Generate a book about org reports
// 
// Instructions for use in the anonymous execution window :
// 		reportBookBatch instance = new reportBookBatch(<nb to query>, ['verbose']);
// 		ID theID = Database.executeBatch(instance, <nb records processed in one batch>);
// 		we recommend 100 as the second parameter to avoid Apex CPU Limit exceptions
// 		Example : 
// 		reportBookBatch instance = new reportBookBatch(0);
// 		ID theID = Database.executeBatch(instance,100);
// 		
// Version : 
// April 14, 2017 : creation
// April 15, 2017 : add Document, Solution, Report, Campaign, User to the report types
// April 16, 2017 : minor improvements
// April 17, 2017 : taking into account Activities (tasks) and custom objects report types
// April 18, 2017 : started to output statistics - org name in the email subject
// April 20, 2017 : more statistics
// April 23, 2017 : add verbose mode, stats as file, new report type => object conversion algo
// April 24, 2017 : output report Ids for not found filter fields
// May 8, 2017 : new algo taking into account custom report types when computing the number of indexed fields
// May 10, 2017 : improvements to lessen the number of fields not found - move generic methods to an utility class
// May 11, 2017 : improvements to lessen the number of fields not found - a single Map for Activity object regrouping Task & Event fields
// May 12, 2017 : added lookup fields (more than one 'dot' in the name or CASE_OWNER for instance, added fields that are not really fields like AGE for Case
// September 25, 2017 : added 2 columns to the report book : created by  et last modified by user names
// 	
// 	TO DO : change the output of the book : hide row limit, qualify both indexed correctly and too complicated
//
global class reportBookBatch implements Database.Batchable<SObject>, Database.stateful {

    global Integer nbtoquery;
    global String endresult;	// book generated as a string
    global Date currentDate;
    global Boolean verbose;
    
    Map<String,String> currentReportInfo;
    Map<String,Map<String,Boolean>> stdObjIndexedFields;
    Map<String,Integer> fieldsAccessSuccessMap;	// protection against not useful queries
    Map<String,Map<String,Integer>> fieldsNotFound;
    Map<String,Map<String,Integer>> fieldsNotIndexed;
    Map<String,Map<String,ID>> fieldsNotFoundByReportId;
    Map<String,Integer> conversionHitMap;
    Map<String,Integer>	conversionMissedMap;
    Map<Id,String> userNamesMap;	// accumulation of usernames to avoid too many queries
    
    Integer totalFieldQueries;
    Integer totalFieldQuerySucesses;
    Integer totalNbOfExceptions;
    Map<Id,Exception> exceptionMap;
    
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
		,'Task'			=>	'Activity'
		,'Event'		=>	'Activity'
    };
    
    static final Map<String,String> fieldNameConversionMap = new Map<String,String> {
        'IS_PERSON_ACCOUNT' =>	'IsPersonAccount'
		,'RECORDTYPE'		=>	'RecordTypeId'
		,'RecordType'		=>	'RecordTypeId'
		,'ACCOUNT_ID'		=>	'Id'
		,'CREATED_DATE'		=>	'CreatedDate'
		,'CREATEDDATE'		=>	'CreatedDate'
		,'CREATED_DATEONLY'	=>	'CreatedDate'
		,'ORIGIN'			=>	'Origin'		// case origin
		,'OWNER'			=>	'OwnerId'
		,'STATUS'			=>	'Status'
		,'SUBJECT'			=>	'Subject'		// case subject
		,'TYPE'				=>	'Type'			// case type
		,'CASE_CREATED_DATEONLY'	=>	'CreatedDate'
		,'CASE_CREATED_DATE'		=>	'CreatedDate'
		,'CASE_ID'			=>	'Id'
		,'CASE_NUMBER'		=>	'CaseNumber'
		,'CASE_RECORDTYPE'	=>	'RecordTypeId'
		,'CASE_STATUS'		=>	'Status'
		,'CASE_COMMENT'		=>	'Comments'
		,'CASE_SUBJECT'		=>	'Subject'
		,'CASE_TYPE'		=>	'Type'
		,'CREATED'			=>	'CreatedById'
		,'LAST_UPDATE_BY'	=>	'LastModifiedById'
		,'LASTMODIFIEDDATE'	=>	'LastModifiedDate'
		,'PRIORITY'			=>	'Priority'
		,'DESCRIPTION'		=>	'Description'
		,'REASON'			=>	'Reason'
		,'CLOSED'			=>	'IsClosed'
		,'CLOSED_DATE'		=>	'ClosedDate'
		,'CLOSED_DATEONLY'	=>	'ClosedDate'
		,'COMPANY'			=>	'Company'		// lead fields
		,'CONVERTED'		=>	'IsConverted'
		,'CONVERTED_DATE'	=>	'ConvertedDate'
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
		,'ADDRESS1_CITY'	=>	'BillingAddress'
		,'ADDRESS1_COUNTRY'	=>	'BillingAddress'
		,'PHONE1'			=>	'Phone'
		,'FIRST_NAME'		=>	'Name'
		,'LAST_NAME'		=>	'Name'
		,'LastName'			=>	'Name'
		,'FirstName'		=>	'Name'
		,'FROM_ADDRESS'		=>	'FromAddress'
		,'TO_ADDRESS'		=>	'ToAddress'
		,'CC_ADDRESS'		=>	'CcAddress'
		,'IS_INBOUND'		=>	'Incoming'
		,'MESSAGE_DATE'		=>	'MessageDate'
		,'DUE_DATE'			=>	'ActivityDate'
		,'TASK_TYPE'		=>	'Type'
	};
     
	static final Map<String,List<String>> fieldToObjectAndFieldMap = new Map<String,List<String>> {
        'DUE_DATE'				=>	new String[] {'Activity', 'ActivityDate'}
		,'CREATED_ALIAS'		=>	new String[] {'User', 'Alias'}
        ,'LAST_UPDATE_BY_ALIAS'	=>	new String[] {'User', 'Alias'}
	};

	static final Set<String> excludedFields = new Set<String> {
		'AGE'
		,'LAST_STAGE_CHANGE_DATE'
	};

	// keys used for the book titles
	static final String headId = 'Id';
	static final String headDeveloperName = 'DeveloperName';
	static final String headFolder = 'Folder';
    static final String headLastRunDate = 'LastRunDate';
	static final String headLastModifiedDate = 'LastModifiedDate';
	static final String headMainObject = 'MainObject';
	static final String headReportType = 'ReportType';
	static final String headFormat = 'Format';    
	static final String headNbColumns = 'NbColumns';
	static final String headNbFilters = 'NbFilters';
	static final String headNbIndexedFilters = 'NbIndexedFilters';
	static final String headRowLimit = 'RowLimit';
	static final String headIndexedDateFilter = 'IndexedDateFilter';    
	static final String headDateIntervalDefined = 'DateIntervalDefined';    
	static final String headSuggestedAction = 'SuggestedAction';    
    static final String headReason = 'Reason';
    static final String headCreatedBy = 'CreatedBy';
    static final String headLastModifiedBy = 'LastModifiedBy';
//
// constructors taking a number of reports to query - 0 means all reports
// 
    public reportBookBatch (integer nbtoquery){
        verbose = false;
        initialize(nbtoquery);
    }
    public reportBookBatch (integer nbtoquery, String isverbose){
        verbose = (isverbose == 'verbose');
        initialize(nbtoquery);
    }
    private void initialize(integer nbtoquery){
		this.nbtoquery = nbtoquery;
        currentDate = date.today();
        totalFieldQueries = 0;
        totalFieldQuerySucesses = 0;
        totalNbOfExceptions = 0;
        fieldsNotFound = new Map<String,Map<String,Integer>>();
        fieldsNotIndexed = new Map<String,Map<String,Integer>>();
        fieldsNotFoundByReportId = new Map<String,Map<String,ID>>();
        fieldsAccessSuccessMap = new Map<String,Integer>();
        conversionHitMap = new Map<String,Integer>();
        conversionMissedMap = new Map<String,Integer>();
        userNamesMap = new Map<Id,String>();
        exceptionMap = new Map<Id,Exception>();
        stdObjIndexedFields = new Map<String,Map<String,Boolean>>();
        stdObjIndexedFields.put('Account',initializeIndexedFieldMap('Account'));
        stdObjIndexedFields.put('Lead',initializeIndexedFieldMap('Lead'));
        stdObjIndexedFields.put('Opportunity',initializeIndexedFieldMap('Opportunity'));
        stdObjIndexedFields.put('Case',initializeIndexedFieldMap('Case'));
        stdObjIndexedFields.put('Contact',initializeIndexedFieldMap('Contact'));
		stdObjIndexedFields.put('User',initializeIndexedFieldMap('User'));
        stdObjIndexedFields.put('Solution',initializeIndexedFieldMap('Solution'));
        stdObjIndexedFields.put('Report',initializeIndexedFieldMap('Report'));
        stdObjIndexedFields.put('Campaign',initializeIndexedFieldMap('Campaign'));
        stdObjIndexedFields.put('Document',initializeIndexedFieldMap('Document'));
        stdObjIndexedFields.put('Activity',initializeIndexedFieldMap('Activity'));
        endresult = computeBookHeader();        
    }
//
// initialize the map of indexed fields for an object
//
    private Map<String,Boolean> initializeIndexedFieldMap(String inputObj){
        
        Map<String, Boolean> theMap = null;
		String theobj = inputObj.toLowerCase().capitalize();
        
        if (fieldsAccessSuccessMap.containsKey(theobj)){
            if (fieldsAccessSuccessMap.get(theobj) == -1) return null;          
        }
        else {
            fieldsAccessSuccessMap.put(theobj, 0);
        }
        
		String queryfields = 'Select QualifiedApiName, IsIndexed From FieldDefinition Where EntityDefinition.QualifiedApiName = \'' + theObj + '\'';
		if (theObj == 'Activity') 
        	queryfields = 'Select QualifiedApiName, IsIndexed From FieldDefinition Where EntityDefinition.QualifiedApiName = \'Task\' or EntityDefinition.QualifiedApiName = \'Event\'';
        List<FieldDefinition> definitions = Database.query(queryfields);
        totalFieldQueries++;
        
        if (definitions != null && definitions.size() > 0){
            totalFieldQuerySucesses++;
            theMap = new Map<String, Boolean>();
        	for (FieldDefinition fd : definitions) 
            	theMap.put(fd.QualifiedApiName, fd.isIndexed);
            vbTools.incrementStringMap(fieldsAccessSuccessMap, theObj);
        }
        else
            fieldsAccessSuccessMap.put(theObj, -1);
        return theMap;
    }
//
// initialize Map of info to output
// return book header string
//
    private String computeBookHeader() {
		
        currentReportInfo = new Map<String,String>();
        currentReportInfo.put(headId,null);
        currentReportInfo.put(headDeveloperName,null);
        currentReportInfo.put(headFolder,null);
        currentReportInfo.put(headCreatedBy,null);
        currentReportInfo.put(headLastModifiedBy,null);
        currentReportInfo.put(headLastRunDate,null);
        currentReportInfo.put(headLastModifiedDate,null);
        currentReportInfo.put(headMainObject,null);
        currentReportInfo.put(headReportType,null);
        currentReportInfo.put(headFormat,null);
        currentReportInfo.put(headNbColumns,null);
        currentReportInfo.put(headNbFilters,null);
        currentReportInfo.put(headNbIndexedFilters,null);
        currentReportInfo.put(headRowLimit,null);
        currentReportInfo.put(headIndexedDateFilter,null);
        currentReportInfo.put(headDateIntervalDefined,null);
        currentReportInfo.put(headSuggestedAction,null);
        currentReportInfo.put(headReason,null);
        
        Set<String> bookColumns = currentReportInfo.keySet();
        String header;
        for (String s : bookColumns)
            if (header == null) header = s + ';';
			else header += s + ';';
        
        header += '\n';
        
        return header;
    }
//
// clear the current report info map - called at each new report
//
    @TestVisible private void clearCurrentReportInfo() {
        Set<String> bookColumns = currentReportInfo.keySet();
        for (String key : bookColumns) currentReportInfo.put(key, null);
    }
//
// output a line of the book
//
    private String outputCurrentReportInfo(){
        String result;
        Set<String> bookColumns = currentReportInfo.keySet();
        for (String key : bookColumns)
            if (result == null) result = currentReportInfo.get(key) + ';';
        	else result += currentReportInfo.get(key) + ';';
        result += '\n';
        return result;
    }
//
// get an object indexed status field map
// if the object exists and is not in the map, create the map entry, else return null
//
    private Map<String,Boolean> getIndexedStatusFieldMap(String inputObj){
        Map<String,Boolean>  isfMap;
        String objname = inputObj.toLowerCase().capitalize();
        if (stdObjIndexedFields.containsKey(objname))
            isfMap = stdObjIndexedFields.get(objname);
        else {
            isfMap = initializeIndexedFieldMap(objname);
            stdObjIndexedFields.put(objname, isfmap);
        }
        return isfMap;
    }
//
// do +1 in a object map of field map
// 
    private void incrementFieldsMap (Map<String,Map<String,Integer>> theMap, String theObj, String theField){
        if (!theMap.containsKey(theObj))
            theMap.put(theObj, new Map<String,Integer>());       
		vbTools.incrementStringMap(theMap.get(theObj),theField);
    }
//
//	add current report to map of fields not found by id
//
    private void addIdToMap(String theobj, String thecol){
		// get the obj map entry
		if (!fieldsNotFoundByReportId.containsKey(theobj))
            fieldsNotFoundByReportId.put(theobj, new Map<String,ID>());
        Map<String,ID> currMap = fieldsNotFoundByReportId.get(theobj);
        if (!currMap.containsKey(thecol))
            currMap.put(thecol,currentReportInfo.get(headId));
    }
//
//	return the string corresponding to the key in the conversion map, else return the key
//
    private String convertFieldName (String key)	{
        String result = key;
        if (fieldNameConversionMap.containsKey(key)) {
            result = fieldNameConversionMap.get(key);
            if (verbose) vbTools.incrementStringMap(conversionHitMap, key);
        }
        else {
            if (verbose) vbTools.incrementStringMap(conversionMissedMap, key);
        }
        return result;
    }
//
//	return the indexation status of a field, assuming that names are curated
//
    private Integer isCuratedFieldIndexed(String objname, String fieldname) {
        Integer result = -1;
		Map<String,Boolean> statusFieldMap = getIndexedStatusFieldMap(objName);
		
        if (statusFieldMap != null)
			if (statusFieldMap.containsKey(fieldName))
				result = (statusFieldMap.get(fieldName) ? 1 : 0);        
        return result;
    }
//
//	test if a field is indexed
//		return -1 : field not found
//		return 0 : field found, not indexed
//		return 1 : field found, indexed
//
    private Integer isFieldIndexed(String theObj, String rawFieldName) {
        Integer result = -1;
        Integer nbDots = rawFieldName.countMatches('.');
        
        if (rawFieldName.startsWith('BucketField_') || excludedFields.contains(rawFieldName))
            result = 0;
        else if (nbDots == 0) {
            if (fieldToObjectAndFieldMap.containsKey(rawFieldName)) {
				result = isCuratedFieldIndexed (fieldToObjectAndFieldMap.get(rawFieldName)[0], fieldToObjectAndFieldMap.get(rawFieldName)[1]);
            } else {
				Map<String,Boolean> indexedStatusFieldMap = getIndexedStatusFieldMap(theObj);
            	if (indexedStatusFieldMap != null) {
                	String fieldName = rawFieldName;
                
                	if (fieldName.startsWith('PC_')) fieldName = 'Person' + vbTools.convertPersonAccountField(fieldName);
                	else if (fieldName.startsWith('CUST_')) fieldName = fieldName.substringAfter('CUST_');
                	else if (fieldName.startsWith('FK_')) fieldName = fieldName.substringAfter('FK_');
                
                	if (!indexedStatusFieldMap.containsKey(fieldName))
                    	fieldName = convertFieldName(fieldName);

                	if (indexedStatusFieldMap.containsKey(fieldName)) {
                    	result = (indexedStatusFieldMap.get(fieldName) ? 1 : 0);
                	}
                	else
                    	result = -1;
            	} else {
                	result = -1;
            	}                
            }
        } else if (nbDots == 1) {
            String objName = rawFieldName.substringBefore('.');
            if (objName.startsWith('FK_') && objName.endsWith('__c')) objName = objName.substringAfter('_');
            objName = objName.toLowerCase().capitalize();
            if (objName == 'Email') objName = 'Emailmessage';

            String fieldName = rawFieldName.substringAfterLast('.');

            if (fieldName.isAllUpperCase())
            	fieldName = convertFieldName(fieldName);

            Map<String,Boolean> statusFieldMap = getIndexedStatusFieldMap(objName);
            if (statusFieldMap != null) {
                if (statusFieldMap.containsKey(fieldName))
                    result = (statusFieldMap.get(fieldName) ? 1 : 0);
                else {
                    fieldName = convertFieldName(fieldName);
                    if (statusFieldMap.containsKey(fieldName))
                       result = (statusFieldMap.get(fieldName) ? 1 : 0); 
                    else
                        result = -1;                    
                }
            } else {
                result = -1;
            }
        } else if (nbDots == 2) {
            String stripped = rawFieldName.substringAfter('.');
            result = isCuratedFieldIndexed(stripped.substringBefore('.'), stripped.substringAfter('.'));
        } else
            result = -1;
        
        if (verbose) {
        	if (result == 0)
            	incrementFieldsMap(fieldsNotIndexed, theObj, rawFieldName);
        	else if (result == -1) {
				incrementFieldsMap(fieldsNotFound, theObj, rawFieldName);
				addIdToMap(theObj, rawFieldName);
        	}            
        }
        
        return result;
    }
//
// compute the number of indexed filters
//
    private Integer computeIndexedFilters(String objName, List<Reports.ReportFilter> theFilters){
        
        if (theFilters == null || theFilters.size() == 0) return 0;
           
		Integer nbindexfound = 0;
            
		for (Reports.ReportFilter rf : theFilters) {
            if (isFieldIndexed(objName, rf.getColumn()) == 1)
                nbindexfound++;
		}
		return nbindexfound;
    }
//
// compute the name of the main object of the report
//
    private String getMainObjectName(Reports.ReportMetadata rmeta){
        Reports.ReportType rt = rmeta.getReportType();
        String reportTypeName = rt.getType();
        String objName = reportTypeName;
                
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
				// to be completed
            } else { // composites
				if (reportTypeName == 'OpportunityLead')
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
// compute info obtained from metadata
//
    private void computeMetadataInfo(ID theId, Boolean isNotRanSinceOneYear){
        
        Reports.ReportDescribeResult describeReport = Reports.ReportManager.describeReport (theId);
        Reports.ReportMetadata rmeta = describeReport.getReportMetadata();
        Reports.ReportType rt = rmeta.getReportType();
        
        currentReportInfo.put(headReportType,rt.getType());
        String objName = getMainObjectName(rmeta);
        currentReportInfo.put(headMainObject,objName);
        
		List<String> columnList = rmeta.getDetailColumns();
        currentReportInfo.put(headNbColumns,columnList.size().format());
        
        List<Reports.ReportFilter> theFilters = rmeta.getReportFilters();
        currentReportInfo.put(headNbFilters,theFilters.size().format());
        
        Integer nbindexedfilters = computeIndexedFilters(objName, theFilters);
        if (nbindexedfilters == -1)
            currentReportInfo.put(headNbIndexedFilters,'unknown');
        else
        	currentReportInfo.put(headNbIndexedFilters,nbindexedfilters.format());
        
        Reports.topRows tr = rmeta.getTopRows();
        if (tr != null)
            currentReportInfo.put(headRowLimit,theFilters.size().format());
        else
            currentReportInfo.put(headRowLimit,'No row limit');
        
        Reports.StandardDateFilter df = rmeta.getStandardDateFilter();
        Boolean dateFilterIndexed = false;
        Boolean timeintervaldefined = false;
        if (df != null) {
            
            Integer indexationResult = isFieldIndexed(objName, df.getcolumn());
            
            if (indexationResult == -1)
                currentReportInfo.put(headIndexedDateFilter,'unknown');
            else if (indexationResult == 0)
                currentReportInfo.put(headIndexedDateFilter,'not indexed');
            else if (indexationResult == 1) {
                currentReportInfo.put(headIndexedDateFilter,'indexed');
                dateFilterIndexed = true;
            }
            
            if (df.getstartdate() == null && df.getenddate() == null)
                currentReportInfo.put(headDateIntervalDefined,'No date interval defined');
            else {
                currentReportInfo.put(headDateIntervalDefined,'Date interval defined');
                timeintervaldefined = true;
            }      
        } else {
			currentReportInfo.put(headIndexedDateFilter,'null value');
        	currentReportInfo.put(headDateIntervalDefined,'null value');
        }
		//
		// compute recommendation
		// 
        if (isNotRanSinceOneYear){
            currentReportInfo.put(headSuggestedAction,'Check if this report is yet useful');
            currentReportInfo.put(headReason,'Not run since more than one year');
        } else if ((theFilters.size() > 0) && (nbindexedfilters <= 0) && !dateFilterIndexed) {
            currentReportInfo.put(headSuggestedAction,'Check if it exists at least one indexed filter');
            currentReportInfo.put(headReason,'It exists at least one filter and no index was found');
        } else if ((columnList.size() >= 20) || (theFilters.size() > 6)) {
			currentReportInfo.put(headSuggestedAction,'Try to simplify this report');
            currentReportInfo.put(headReason,'High number of columns or too complex filter');            
        } else if ((theFilters.size() == 0) && (!timeintervaldefined || !dateFilterIndexed)){
            currentReportInfo.put(headSuggestedAction,'Check that a date interval is defined and indexed');
            currentReportInfo.put(headReason,'No date interval or not sure that date interval is indexed');
        } else {
			currentReportInfo.put(headSuggestedAction,'Report OK');
            currentReportInfo.put(headReason,'Selectivity and number of columns ok');                        
        }	 
    }
//
// test if a report is no more used (since one year)
//
    private Boolean isAged(Report r){
        integer yearsSinceLastRun = 0;
		if (r.lastRunDate != null)
            yearsSinceLastRun = r.lastRunDate.date().daysBetween(currentDate)/365;
        return (yearsSinceLastRun >= 1);
    }
//
// get a user name from an id
//
    private String getUserName (ID theId) {
        String result = null;
        if (userNamesMap.containsKey(theID))
            return userNamesMap.get(theID);
        else {
            User u = [SELECT name FROM User Where ID= :theID LIMIT 1];
            if (u != null) {
                userNamesMap.put(theID, u.name);
                return u.name;
            }
        }
        return result;
    }
//
// central method computing all required information for a given report
//
    private void computeReportInfo(Report r){
        currentReportInfo.put(headId, r.id);
        currentReportInfo.put(headDeveloperName,r.developerName);
        currentReportInfo.put(headFormat,r.format);
        currentReportInfo.put(headFolder,r.folderName);
        currentReportInfo.put(headCreatedBy, getUserName(r.createdById));
        currentReportInfo.put(headLastModifiedBy, getUserName(r.lastModifiedById));
        if (r.LastRunDate != null)
        	currentReportInfo.put(headLastRunDate,r.LastRunDate.date().format());
        if (r.LastModifiedDate != null)
        	currentReportInfo.put(headLastModifiedDate,r.LastModifiedDate.date().format());
        
        Boolean isNotRanSinceOneYear = isAged(r);
        if (r.format == 'Tabular' || r.format == 'Matrix' || r.format == 'Summary') {
            try {
				computeMetadataInfo(r.id, isNotRanSinceOneYear);
            } catch (exception e){
                totalNbOfExceptions++;
                if (exceptionMap.size() < 20) exceptionMap.put(r.id, e);
                if (e.getTypeName() == 'reports.MetadataException'){
                    currentReportInfo.put(headSuggestedAction, 'Check and delete this report');
                    currentReportInfo.put(headReason, 'This report is obsolete - it can no longer be edited or run');
                } else {
                    currentReportInfo.put(headSuggestedAction, e.getTypeName());
                    currentReportInfo.put(headReason, e.getMessage());
                }
            }
        }
        else{
            if (isNotRanSinceOneYear){
                currentReportInfo.put(headSuggestedAction, 'Check if this report is yet useful');
                currentReportInfo.put(headReason, 'Not run since more than one year');
            }
            else {
                currentReportInfo.put(headSuggestedAction, 'report to analyze');
                currentReportInfo.put(headReason, 'Cannot get metadata for this report format');
            }
        } // end format with no metadata
    }
//
// compute a list of reports - called by execute interface
//
    private void computeReportList(List<Report> reportList){
        for (Report r : reportList){
            clearCurrentReportInfo();
            computeReportInfo(r);
            endResult += outputCurrentReportInfo();
        }
    }
//
// statistics generation, only called if verbose mode is on
//
    private String generateStatistics (){
        String result;
        
        result = 'Number of catched exceptions : ' + totalNbOfExceptions + '\n\n';
        for (Id currid : exceptionMap.keyset()){
            exception e = exceptionMap.get(currid);
            result += 'Report : ' + currid + ' Type : ' + e.getTypeName() + '\n';
            result += 'Exception Message : ' + e.getMessage() + '\n';
        }

        result += vbTools.outputStringMap('\n\n########## fieldsAccessSuccessMap ##########\n\n', fieldsAccessSuccessMap);
        result += '\nTotal number of FieldDefinition queries : ' + totalFieldQueries;
        result += '\nTotal number of FieldDefinition queries successes : ' + totalFieldQuerySucesses +'\n';
        result += '\n\n########## Conversion Map statistics ##########\n';
        result += vbTools.outputStringMap('\n <<<<<<< Hit Map >>>>>>>\n', conversionHitMap);
        result += vbTools.outputStringMap('\n <<<<<<< Missed Map >>>>>>>\n', conversionMissedMap);
        result += '\n\n########## Fields not found statistics ##########\n';
        for (String s : fieldsNotFound.keyset())
            result += vbTools.outputStringMap('\n*************** Object : ' + s + '\n', fieldsNotFound.get(s));
        result += '\n\n Fields not found by Report Ids : \n\n';
        for (String s : fieldsNotFoundByReportId.keyset()){
            result += '\n*************** Object ' + s + '\n';
            for (String t : fieldsNotFoundByReportId.get(s).keyset())
                result += 'Column : ' + t + ' report ID : ' + fieldsNotFoundByReportId.get(s).get(t) + '\n';
        }
        result += '\n\n########## Filter not indexed statistics ##########\n';
        for (String s : fieldsNotIndexed.keyset())
            result += vbTools.outputStringMap('\n*************** Object : ' + s + '\n', fieldsNotIndexed.get(s));
        return result;
    }
//
// implementation of start batchable interface method
//
	global Database.QueryLocator start(Database.BatchableContext ctx){
		String theQuery = 'Select Name, DeveloperName, FolderName, Format, LastRunDate, LastModifiedDate, CreatedById, LastModifiedById from Report ';
        if (nbtoquery > 0)
            theQuery += 'Limit ' + nbtoquery;
        return Database.getQueryLocator(theQuery);
    }
//
// implementation of execute batchable interface method
//
	global void execute(Database.BatchableContext ctx, List<SObject> sobjects){
        computeReportList ((List<Report>)sobjects);
    }
//
// implementation of finish batchable interface method
// email construction and sending
// 
    global void finish(Database.BatchableContext ctx){
        List<Organization> orgs = [Select name,isSandbox from Organization Limit 1];
        String subject = 'Report book for organization ' + orgs[0].name;
        if (orgs[0].isSandbox) subject += ' (sandbox)';
        Map<String,String> fileMap = new Map<String,String>{'reportBook.csv' => endResult};
        if (verbose) fileMap.put('stats.txt',generateStatistics());
        String body = 'Please see attached csv file';
        if (verbose) body += 's';
        body += '\n';
        EmailManager.sendMailWithAttachedFiles(UserInfo.getUserEmail(), subject, body, fileMap);
    }
}