@isTest
public class testEmailManager {
    
    @isTest static void test1(){
        EmailManager.sendmail('vbrenet@gmail.com','subject','body');
    }
    @isTest static void test2(){
        Map<String,String> filemap = new Map<String,String>();
        String filename = 'test.csv';
        String filecontent = 'test content\n';
        filemap.put(filename,filecontent);
        EmailManager.sendMailWithAttachedFiles('vbrenet@gmail.com','subject','body',filemap);
    }
    @isTest static void test3(){
        String filename = 'test.csv';
        String filecontent = 'test content\n';
        EmailManager.sendMailWithAttachedFile('vbrenet@gmail.com','subject','body',filename,filecontent);        
    }
}