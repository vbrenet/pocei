//
// getReportMetadata : get detailled metadata about a Report or a list of reports
// Version : April 13th, 2017
// Instructions for use in the anonymous execution window :
// 		getReportMetadata instance = new getReportMetadata (<report id>); or
// 		getReportMetadata instance = new getReportMetadata (number of reports to query);
// 		instance.run();
//
// The result is sent as an email with an attached file
//
public class getReportMetadata {

    private id theReportId;
    private integer nbtoquery;

//
// constructor with report id as a parameter
// 
    public getReportMetadata(Id theId) {
        nbtoquery = 1;
        theReportId = theId;
    }
//
// constructor with nb reports to query as a parameter
// 
    public getReportMetadata (integer nbtoquery){
    	this.nbtoquery = nbtoquery;
    }
//
// helper method to output cross filters info
//
    private String outputCrossFilters(Reports.ReportMetadata rmeta){
        String result;
        List<Reports.CrossFilter> crossfilters = rmeta.getCrossFilters();
        
        if (crossfilters == null || crossfilters.size() == 0)
            result = 'No cross filters\n';
        else {
            result = 'Cross filters number : ' + crossfilters.size() + '\n';
            for (Reports.CrossFilter cross : crossfilters){
                result += 'Cross filter primary entity field : ' + cross.getPrimaryEntityField() + '\n';
                result += 'Cross filter related entity : ' + cross.getRelatedEntity() + '\n';
                result += 'Cross filter related entity join field : ' + cross.getRelatedEntityJoinField() + '\n';
            }
        }
        return result;
    }
//
// helper method to output report filters info
// 
    private String outputReportFilters(Reports.ReportMetadata rmeta){
        String result;
        List<Reports.ReportFilter> theFilters = rmeta.getReportFilters();
        if (theFilters != null && theFilters.size() > 0){
            result = 'Number of report filters : ' + theFilters.size() + '\n';
            for (Reports.ReportFilter rf : theFilters)
                result += 'Filter column : ' + rf.getcolumn() + '\n';
        }
        else
            result = 'No report filters\n';

        return result;
    }
//
// helper method to output standard date filter info
// 
    private String outputStandardDateFilter(Reports.ReportMetadata rmeta){
        String result;
        Reports.StandardDateFilter df = rmeta.getStandardDateFilter();
        if (df != null){
            result = 'Standard Date Filter information : \n';
            result += 'Column : ' + df.getcolumn() + '\n';
            result += 'Start date : ' + df.getstartdate() + '\n';
            result += 'End date : ' + df.getenddate() + '\n';
            result += 'Duration : ' + df.getdurationValue() + '\n';
        }
        else
            result = 'No standard date filter\n';
        return result;
    }
//
// helper method to output standard filters information
// 
    private String outputStandardFilters(Reports.ReportMetadata rmeta){
        String result;
        List<Reports.StandardFilter> sflist = rmeta.getStandardFilters();
        
        if (sflist != null && sflist.size() > 0){
            result = 'Number of standard filters : ' + sflist.size() + '\n';
            for (Reports.StandardFilter sf : sflist){
                result += 'Name : ' + sf.getname() + '\n';
                result += 'Value : ' + sf.getvalue() + '\n';
            }
        }
        else
            result = 'No standard filters\n';
        
        return result;
    }
//
// helper method to output row limit information
// 
    private String outputReportRowLimit(Reports.ReportMetadata rmeta){
        String result;
        Reports.topRows tr = rmeta.getTopRows();
        if (tr != null)
            result = 'Row limit : ' + tr.getrowlimit() + '\n';
        else
            result = 'No top rows information\n';
        return result;
    }
//
// central method to manage metadata info output for a given report identified with its ID
// 
    private String outputMetadataForId (Id theId){

        Reports.ReportDescribeResult describeReport = Reports.ReportManager.describeReport (theId);
        Reports.ReportMetadata rmeta = describeReport.getReportMetadata();
 		
        String result = 'Scope : ' + rmeta.getScope() + '\n\n';
        
        Reports.ReportType rt = rmeta.getReportType();
        result += 'Report Type : ' + rt.getLabel() + '\n';
        result += 'Report Type type : ' + rt.getType() + '\n\n';
        
        result += outputCrossFilters(rmeta) + '\n';
        
        result += outputStandardFilters(rmeta) + '\n';
        
        result += outputStandardDateFilter(rmeta) + '\n';
        
        result += outputReportFilters(rmeta) + '\n';
        
        result += outputReportRowLimit(rmeta) + '\n';
        
        List<String> columnList = rmeta.getDetailColumns();
        result += 'Number of columns : ' + columnList.size() + '\n';
        for (String s : columnList) result += s + '\n';
        
        return result;
    }
//
// check that metadata is available for a given report and if so call outputMetadataForId central method
// 
    private String outputMetadata(Report r){
        String result;
        if (r.format == 'Tabular' || r.format == 'Matrix' || r.format == 'Summary') {
            result = outputMetadataForId (r.id);
        }
        else 
            result = 'no metadata for this format : ' + r.format + '\n';
        return result;
    }
//
// run output info for the class instance
// 
    public void run(){
        
        String theResult;
        String theQuery = 'Select Name, CreatedDate, DeveloperName, FolderName, Format, LastRunDate, LastViewedDate, LastModifiedDate, LastReferencedDate from report ';
        if (theReportId != null){
            theQuery += 'where id = \'' + theReportId + '\'';
        } else if (nbtoquery > 0)
            theQuery += 'Limit ' + nbtoquery;
        else
            return;
        
        List<Report> reportList = Database.query(theQuery);
        if (reportList == null || reportList.size() == 0)
            theResult = 'Report not found\n';
        else {
            theResult = 'Nb reports analyzed : ' + reportList.size() + '\n\n';
            for (Report r : reportList) {
                theResult += '********************************************************\n';
            	theResult +='Report Name : [' + r.name + ']\n';
                theResult += 'Report ID : ' + r.id + '\n';
            	theResult += 'Developer Name : [' + r.developerName + ']\n';
           		theResult += 'Folder Name : [' + r.folderName + ']\n';
            	theResult += 'Report Format : ' + r.format + '\n\n';
            	theResult += 'Created : ' + r.createdDate + '\n';
            	theResult += 'Last run : ' + r.LastRunDate + '\n';
            	theResult += 'Last viewed : ' + r.LastViewedDate + '\n';
            	theResult += 'Last modified : ' + r.LastModifiedDate + '\n';
	            theResult += 'Last referenced : ' + r.LastReferencedDate + '\n\n';
				theResult += outputMetadata(r) + '\n';
            }
        }
                   
        if (theReportId != null)
			EmailManager.sendMailWithAttachedFile(UserInfo.getUserEmail(),'Report ' + theReportId + ' info', 'please see attached file\n', 'Report-'+theReportid+'.csv',theResult);
        else
			EmailManager.sendMailWithAttachedFile(UserInfo.getUserEmail(),'Report info', 'please see attached file\n', 'Reports.csv', theResult); 
    }
}