public class myCaseExtension {

private final Case c;

public myCaseExtension (apexPages.standardController controller) {
this.c = (Case)controller.getRecord();
}

public pageReference carryOn() {
String theId = ApexPages.CurrentPage().getParameters().get('id');
if (theId == null) return null;
PageReference thePage = new PageReference ('/' + theId);
    thePage.setRedirect(true);
    return thePage;
}

public pageReference myAction() {
String theId = ApexPages.CurrentPage().getParameters().get('id');
if (theId == null) return null;

if (convertDocument())
    {
    PageReference thePage = new PageReference ('/' + theId);
    thePage.setRedirect(true);
    return thePage;
    }
else
    {
    ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, 'No document available');
    ApexPages.addMessage(myMsg);
    return null;
    }
}

private boolean convertDocument () {
List<Document> doclist = [SELECT Id, Body, ContentType, Name, SystemModstamp FROM Document where createdById =: UserInfo.getUserId() AND folderId =: UserInfo.getUserId() and isdeleted = false ];

if (!doclist.isEmpty()) {
    integer i = 0, j;
    Datetime current;
    
    if (doclist.size() > 1)
        for (j=0; j<doclist.size(); j++)
            if (j==0) current = doclist[0].SystemModstamp;
            else if (doclist[j].SystemModstamp > current) {current=doclist[j].SystemModstamp; i=j;}
   
    Attachment a = new Attachment
    (ParentId = c.id,
    Name = doclist[i].name,
    ContentType = doclist[i].ContentType,
    isPrivate = false,
    Body = doclist[i].body);

    insert a;
    return true;
    }
    
return false;
}

}