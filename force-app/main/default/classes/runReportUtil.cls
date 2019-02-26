//
//	Class runReportUtil - run report by Apex
//	Author : Vincent Brenet / vbrenet@salesforce.com
//	
//	Version : April 24, 2017 - synchronous run
//
public class runReportUtil {
    
    private Id reportID;
    private String result;

//
//	constructor, report id as parameter
//
    public runReportUtil (Id reportID) {
        this.reportID = reportID;
    }
//
//	method running a report in synchronous mode
//
    private void runReport (Id reportID) {
        System.Debug('Before Run');
        Reports.ReportResults rr = Reports.ReportManager.RunReport(reportID, true);
        System.Debug('After Run');
        result = 'getalldata : ' + rr.getalldata() + '\n';
        result += 'has detail rows ? ' + rr.gethasdetailrows() + '\n';
        Map<String,Reports.ReportFactWithDetails> facts = (Map<String,Reports.ReportFactWithDetails>)rr.getFactMap();
        result += 'Fact map size : ' + facts.size() + '\n';
        for (String s : facts.keyset()){
            result += '\nFact key : ' + s + '\n';
            Reports.ReportFactWithDetails fact = facts.get(s);
            
            List<Reports.SummaryValue> summaries = fact.getAggregates();
            result += 'Number of summaries : ' + summaries.size() + '\n';
            for (Reports.SummaryValue summary : summaries) {
                result += 'Summary label : ' + summary.getLabel() + '\n';
            }

			List<Reports.ReportDetailRow> rows = fact.getrows();
			result += 'Number of rows : ' + rows.size() + '\n';
            Integer nbrows = 0;
			for (Reports.ReportDetailRow row : rows){
				List<Reports.ReportDataCell> cells = row.getDataCells();
                for (Reports.ReportDataCell cell : cells)
                    result += 'Cell label : ' + cell.getLabel() + ' Cell value : ' + cell.getValue() + '\n';
                if (++nbrows >= 20) break;
			}
        }
    }
//
// check report id
//
    private Boolean checkId(){
        String theQuery = 'Select ID from report where id = \'' + reportId + '\'';
        List<Report> reportList = Database.query(theQuery);
        return (reportList != null && reportList.size() == 1);
    }
//
// check the report, run it and push results in an email
//
    public void run(){
        if (checkId()){
            runReport(reportID);            
        } else {
		result  = 'Invalid ID\n';
        } 
        
        EmailManager.sendMail(UserInfo.getUserEmail(), 'run report summary', result);
    }
}