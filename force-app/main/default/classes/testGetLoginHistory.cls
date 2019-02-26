//
//    added header in scratch org
//
@isTest
public class testGetLoginHistory {
    
    @isTest static void test1(){
        getLoginHistory runner = new getLoginHistory(100);
        Id theId = Database.ExecuteBatch(runner,2000);
    }
    
    @isTest static void test2() {
        getLoginHistory runner = new getLoginHistory(0);
        String theName = runner.getUserName(UserInfo.getUserId());
    }
    
    
     @isTest static void test3() {
        getLoginHistory runner = new getLoginHistory(0);
        runner.resetBookEntry();
        runner.outputBookEntry();
    }
    
    
     @isTest static void test4() {
        getLoginHistory runner = new getLoginHistory(0);
        LoginHistory lh = [Select Browser, CountryISO, LoginTime, UserId, Status, TlsProtocol from LoginHistory LIMIT 1];
        runner.compute(lh);
    }
}