//
// reportFilterInfoBatch April 14th, 2017
// Batch to get statistics about filters in Reports : which reports have no indexed filters
// Instructions of use on the anonymous execution window
// 	1/ instanciate the class, e.g. : reportFilterInfoBatch rfi = new reportFilterInfoBatch (0, 'case');
// 	2/ run the batch, e.g. : Id theId = Database.ExecuteBatch(100, rfi); Use 100 instead 200 to avoid APEX CPU limits
//
global class reportFilterInfoBatch implements Database.Batchable<SObject>, Database.stateful {
        
	global integer totalAnalyzedReport;
    global integer totalQueriedReports;
    global integer nbtoquery;
    global String endResult;
    global String reportTypeToAnalyze;
    global integer nbindexedfields;
    global integer nbconversionhits;
    Map<String, Integer> reportTypeMap;
    Map<String, Integer> columnMap;
    Map<String, Integer> formatMap;
    Map<Integer, Integer> nbColumnsMap;
    Map<Integer, Integer> nbFiltersMap;
    global integer exceptionCounter;
    global integer nbReportTypeFound;
    global Map<String, Boolean> indexedStatusFieldMap;
    Map<String, integer> fieldsNotFound;
    
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
    };

    //
    // constructor : initialize globals
    // input : nb of reports to query, report type (object name)
    //
    public reportFilterInfoBatch (integer querylimit, String reportType){
        nbtoquery = querylimit;
        totalAnalyzedReport = 0;
        totalQueriedReports = 0;
        nbReportTypeFound = 0;
        nbconversionhits = 0;
        endResult = '\n';
        reportTypeToAnalyze = reportType;
        reportTypeMap = new Map<String, Integer>();
        columnMap = new Map<String, Integer>();
        formatMap = new Map<String, Integer>();
        nbColumnsMap = new Map<Integer, Integer>();
        nbFiltersMap = new Map<Integer, Integer>();
        fieldsNotFound = new Map<String, Integer>();
        exceptionCounter = 0;
        initializeIndexedFieldMap();
    } 
    //
    // intialize the list of indexed field for the object requested
    //
    private void initializeIndexedFieldMap (){
        
        indexedStatusFieldMap = new Map<String, Boolean>();
        String queryfields = 'Select QualifiedApiName, IsIndexed From FieldDefinition Where EntityDefinition.QualifiedApiName = \'' + reportTypeToAnalyze + '\'';
		List<FieldDefinition> definitions = Database.query(queryfields);
        nbindexedfields = 0;
        for (FieldDefinition fd : definitions) {
            indexedStatusFieldMap.put(fd.QualifiedApiName, fd.isIndexed);
            if (fd.isIndexed) nbindexedfields++;
        }
    }
    // generic method : does +1 in a <String / Integer> map if the key is found, else creates an entry in the map with 1 as the value
    //
    private void incrementStringMap(Map<String, integer> theMap, String s) {
        if (theMap.containsKey(s)) 
            theMap.put(s, theMap.get(s)+1);
        else
            theMap.put(s, 1);
    }
    //
    // generic method : output a **sorted** <String / Integer> map as a String, with an optional title
    //
    private String outputStringMap (String title, Map<String, integer> theMap) {
        String outputedMap = title;
        if (outputedMap == null) outputedMap = '\n';
        List<String> sortedKeys = new List<String>();
        for (String key : theMap.keyset())
            sortedKeys.add(key);
        sortedKeys.sort();
		for (String k : sortedKeys)
            outputedMap += k + ' : ' + theMap.get(k) + '\n';
        return outputedMap;
    }
	//
	// generic method : does +1 in an <Integer / Integer> map if the key is found, else creates an entry in the map with 1 as the value
	//
    private void incrementIntegerMap(Map<integer, integer> theMap, integer theValue){
        if (theMap.containsKey(theValue))
            theMap.put(theValue, theMap.get(theValue)+1);
        else
            theMap.put(theValue, 1);
    }
    //
    // generic method : output a **sorted** <Integer / Integer> map as a String, with an optional title
    //
    private String outputIntegerMap(String title, Map<integer, integer> theMap){
        String res = title;
        if (res == null) res = '\n';
        List<integer> sortedKeys = new List<integer>();
        for (integer key : theMap.keyset())
            sortedKeys.add(key);
        sortedKeys.sort();
        for (Integer key : sortedKeys)
            res += 'Nb with ' + key + ' : ' + theMap.get(key) + '\n';
        return res;
    }
    
    /********************************************************************************************************
     * 
     * computeReportInfo
     * 
     * compute all interesting info about a given report
     * Parameter : the report id
     * Output : a String containing info ready to concatenate in a CSV file
     * 
     *********************************************************************************************************/
    private String computeReportInfo(Id reportId) {
        String theResult = '\n';
        Reports.ReportDescribeResult res = Reports.ReportManager.describeReport(reportId);
        Reports.ReportMetadata rmeta = res.getReportMetadata();
        
        /*
        theResult += rmeta.getName();
        theResult += ' Type : ' + rmeta.getReportType().getType();
        incrementStringMap(reportTypeMap, rmeta.getReportType().getType());
        */
        // skip report types not analyzed
        String reportTypeName = reportTypeToAnalyze + 'List';
        if (reportTypeToAnalyze == 'Opportunity' || reportTypeToAnalyze == 'User') reportTypeName = reportTypeToAnalyze; // special case : opportunity and user report types are not suffixed by 'List'
        if (rmeta.getReportType().getType() != reportTypeName)
            return theResult;
        else 
            nbReportTypeFound++;
        
        List<Reports.ReportFilter> theFilters = rmeta.getReportFilters();
        if (theFilters != null) {
            theResult += '\nNumber of filters : ' + theFilters.size() + '\n';
            if (theFilters.size()>= 10)
            	endresult += '\nReport with ' + theFilters.size() + ' filters : ' + reportID + ' Name : [' + rmeta.getName() + ']';
            incrementIntegerMap(nbFiltersMap, theFilters.size());
            
            Integer nbindexfound = 0;
            List<String> indexedfilters = new List<String>();
            List<String> notindexedfilters = new List<String>();
            for (Reports.ReportFilter rf : theFilters) {
                String theCol = rf.getColumn();
                String stripped = theCol.substringAfter('.');
                if (String.isEmpty(stripped)) stripped = theCol;
                
                if (!indexedStatusFieldMap.containsKey(stripped))
                    if (fieldNameConversionMap.containsKey(stripped)){
                        stripped = fieldNameConversionMap.get(stripped);
                        nbconversionhits++;
                    }
                    	
                if (indexedStatusFieldMap.containsKey(stripped)) {
                    if (indexedStatusFieldMap.get(stripped)) {
                    	nbindexfound++;
                    	indexedfilters.add(stripped);
                    }
					else {notindexedfilters.add(theCol);}          
                }
                else incrementStringMap(fieldsNotFound, stripped);
            }
            if (nbindexfound == 0) {
                endresult += '\nReport with no indexed filters : ' + reportID + ' Name : [' + rmeta.getName() + ']\n';
                for (String s : notindexedfilters) {endresult += s + ' ';}
            }
            else {
                endresult += '\nReport with ' + nbindexfound + ' indexed filters : ' + reportID + ' Name : [' + rmeta.getName() + ']\n';
                for (String s : indexedfilters) {endresult += s + ' ';}
            }
        }
        else {
        	//theResult += '\nNumber of filters : 0';
            incrementIntegerMap(nbFiltersMap, 0);
        }
            
        return theResult;
    }
	//
	// compute a list of reports and return a String including all info gathered
	//
    private String computeReportList (List<Report> reportList) {
        String theResult ='\n';
        for (Report r : reportList) {
            totalQueriedReports++;
            incrementStringMap(formatMap, r.format);
            if (r.format == 'Tabular' || r.format == 'Matrix' || r.format == 'Summary') {
                totalAnalyzedReport++;
                try{
                theResult += computeReportInfo(r.id) + '\n';
                } catch (exception e) {exceptionCounter++;}
            }
        }
        return theResult;
    }

    //
    // start batch 
    //
    global Database.QueryLocator start(Database.BatchableContext ctx){
        String theQuery = 'Select id, format from Report ';
        if (nbtoquery > 0)
            theQuery += 'Limit ' + nbtoquery;
        return Database.getQueryLocator(theQuery);
    }
    
    //
    // execute batch
    //
    global void execute(Database.BatchableContext ctx, List<SObject> sobjects){
        //endResult+= computeReportList ((List<Report>)sobjects);
        String s = computeReportList ((List<Report>)sobjects);
	}
    
    //
    // terminate batch
    //
	global void finish(Database.BatchableContext ctx){
       	String theResult = 'Total number of queried reports : ' + totalQueriedReports;
       	theResult += outputStringMap('\nFormats :\n', formatMap);
       	theResult += '\nTotal analyzed reports : ' + totalAnalyzedReport + '\n';
       	theResult += '\nNumber of report types found for ' + reportTypeToAnalyze + ' : ' + nbReportTypeFound;
		theResult += '\nNumber of catched exceptions : ' + exceptionCounter;
        
       	theResult += '\nNumber of indexed fields in ' + reportTypeToAnalyze + ' : ' + nbindexedfields + '\n';
      //for (String s : indexedFields)
      //	theResult += s + '\n';
      // theResult += outputStringMap('\nReport Types Stats :\n', reportTypeMap);
      // theResult += outputStringMap('\nColumns Stats :\n', columnMap);
      // theResult += outputIntegerMap('\nNb columns\n', nbColumnsMap);
		theResult += outputStringMap('\nFields not found :\n', fieldsNotFound);
        theResult += 'Nb conversion hits : ' + nbconversionhits + '\n';
       	theResult += outputIntegerMap('\nNb filters\n', nbFiltersMap);
       	theResult += endResult + '\n';
       	EmailManager.sendMailWithAttachedFile(UserInfo.getUserEmail(), 'Report Info', 'Please see attached csv file\n', 'report.csv', theResult);
	}
}