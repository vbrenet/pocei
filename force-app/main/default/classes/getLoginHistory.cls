//
//	Class getLoginHistory : get a login history book (30 last days) by batch - useful when the history size is big
//	Version : April 26, 2017 : add query limit control + log filter on last month
//	October 15, 2017 : added TLS field and filter on TLS 1.0
//	
//	Author : Vincent Brenet, vbrenet@salesforce.com
//	
//	Instructions for use in the Anonymous Execution Console :
//	getLoginHistory instance = new getLoginHistory(<query limit>);
//	ID theId = Database.ExecuteBatch(instance);
//	where <query limit> is the maximum number of records to query - if <query limit> = 0, then no limits are set
//
global class getLoginHistory implements Database.Batchable<SObject>, Database.stateful {

    String Result;
    Map<String,String> loginBookEntry;	// single line entry of the book
    Map<Id,String> usersMap;	// map of usernames by IDs, to avoid repeated queries for the same user
    Integer nbProcessedRecords;
    Integer nbHits;
    Integer theLimit;
    Integer queryLimitExceededNumber;
    
    //	names of the book columns
    Static final String headUserId = 'UserId';
    Static final String headUserName = 'UserName';
    Static final String headLoginTime = 'LoginTime';
    Static final String headTlsVersion = 'TLS';
    Static final String headBrowser = 'Browser';
    Static final String headStatus = 'Status';
    Static final String headISOCountry = 'Country';
//
//	constructor
//
    public getLoginHistory (Integer theLimit){
        nbProcessedRecords = 0;
        this.theLimit = theLimit;
        nbHits = 0;
        queryLimitExceededNumber = 0;
        // initialize maps
        loginBookEntry = new Map<String,String>();
        usersMap = new Map<Id,String>();
        // initialize keys of the book entry map
        loginBookEntry.put(headUserId,null);
        loginBookEntry.put(headUserName,null);
        loginBookEntry.put(headLoginTime,null);
        loginBookEntry.put(headTlsVersion,null);
        loginBookEntry.put(headBrowser,null);
        loginBookEntry.put(headStatus,null);
        loginBookEntry.put(headISOCountry,null);
        // write down the semi colon separated book header
        outputBookHeader();
    }
//
//	output the keys of the book entry map
//
    private void outputBookHeader(){
		for (String s : loginBookEntry.keyset())
            if (Result == null) Result = s + ';';
        	else Result += s + ';';
        result += '\n';
    }
//
//	clear the values (not keys) of the book entry map
//
@TestVisible private void resetBookEntry(){
        for (String s : loginBookEntry.keyset())
            loginBookEntry.put(s,null);
    }
//
// output the current values of the book entry map
//
@TestVisible private void outputBookEntry(){
        for (String s : loginBookEntry.keyset())
            result += loginBookEntry.get(s) + ';';
        result += '\n';
    }
//
//	return username from user id
//
@TestVisible private String getUserName(Id userid) {
        // if username already in the users map, pick it
        if (usersMap.containsKey(userId)) {
            nbHits++;
			return usersMap.get(userId);
        }
        else{
            // else query the username
            Integer remaining = Limits.getLimitQueryRows() - Limits.getQueryRows();
            if (remaining > 0) {
        		List<User> users = [Select username from user where id = :userid];
				if (users != null && users.size() >= 0){
                	// and put it in the map for the next attempt
                	if (usersMap.size() <= 20000)
                    	usersMap.put(userid,users[0].username);
                	return users[0].username; 
                } else return null;
            } else {
                queryLimitExceededNumber++;
                return null;                
            }
        }
    }
//
//	handle a login record
//
@TestVisible private void compute(LoginHistory loginRecord){
        // clear book entry value
        resetBookEntry();
    
    	Boolean wasExisting = usersMap.containsKey(loginRecord.userId);
            
        // put record info in the book entry
		loginBookEntry.put(headUserId, loginRecord.userid);
		loginBookEntry.put(headUserName, getUserName(loginRecord.userid));
        loginBookEntry.put(headLoginTime, loginRecord.logintime.format());
        loginBookEntry.put(headTlsVersion, loginRecord.TlsProtocol);
		loginBookEntry.put(headBrowser, loginRecord.browser);
		loginBookEntry.put(headStatus, loginRecord.status);
		loginBookEntry.put(headISOCountry, loginRecord.countryiso);
    
        // output book entry info
        if (!wasExisting)
        	outputBookEntry();
    
        nbProcessedRecords++;
    }
//
//	implementation of the start Batchable interface : get query locator on LoginHistory table
//
    global Database.QueryLocator start(Database.BatchableContext ctx){
        DateTime twoWeeksAgo = Datetime.now().addDays(-15);
        String theQuery = 'Select Browser, CountryISO, LoginTime, UserId, Status, TlsProtocol from LoginHistory Where LoginTime >= :twoWeeksAgo and TlsProtocol = \'TLS 1.0\'';
        if (theLimit > 0)
            theQuery += ' Limit ' + theLimit;
        return Database.getQueryLocator(theQuery);
    }
//
//	implementation of the execute Batchable interface : call compute() for each login record 
//
    global void execute(Database.BatchableContext ctx, List<SObject> sobjects){
        List<LoginHistory> loginRecords = (List<LoginHistory>)sobjects;
        for (LoginHistory loginRecord : loginRecords)
			compute(loginRecord);
    }
//
//	implementation of the finish Batchable interface : send email including the book as a .csv file
//
	global void finish(Database.BatchableContext ctx){
        String subject = 'Login history for organization ';
        if ((Limits.getLimitQueryRows() - Limits.getQueryRows()) >0) {
        	List<Organization> orgs = [Select name,isSandbox from Organization Limit 1];
            subject += orgs[0].name;
        	if (orgs[0].isSandbox) subject += ' (sandbox)';            
        }
        Map<String,String> fileMap = new Map<String,String>();
        fileMap.put('LoginBook.csv', result);
        String body = 'Please see attached csv file\n\n';
        body += 'Total processed records : ' + nbProcessedRecords + '\n\n';
        body += '[ Map username size : ' + usersMap.size() + ' ]\n';
        body += '[ Map username hits : ' + nbHits + ' ]\n';
        body += '[ Number of exceeded query limits : ' + queryLimitExceededNumber +  ' ]\n';
        EmailManager.sendMailWithAttachedFiles(UserInfo.getUserEmail(), subject, body, fileMap);
	}
}