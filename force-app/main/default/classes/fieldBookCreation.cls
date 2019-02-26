//
// fieldBookCreation
// version April, 10th 2017
// generate an object book with information about each object field
// 
// Instructions for use in an anonymous window :
// 		instance = new fieldBookCreation ('obj'); where obj is an object name e.g. fbe = new fieldBookCreation('Account');
// 		send an email to the current user with a .csv attached file containing the field book
// 

public class fieldBookCreation {
    
    // field attributes to get - be cautious not to get too many attributes, this may cause gacks when accessing objects with hundredth attributes
    private static final List<String> fieldsToGet = new List<String> {
   			'Label'
            ,'DeveloperName'
            ,'QualifiedApiName'
			,'DurableId'
            ,'RelationshipName'
        	,'ControllingFieldDefinitionId'
   			,'DataType'
           	,'ExtraTypeInfo'
           	,'IsCalculated'
           	,'IsCompound'
           	,'IsFieldHistoryTracked'
           	,'IsHighScaleNumber'
           	,'IsHtmlFormatted'
           	,'IsIndexed'
           	,'IsNameField'
           	,'LastModifiedById'
           	,'LastModifiedDate'
          	,'Length'
           	,'Precision'
           	,'PublisherId'
           	,'Scale'
    };

    //
    // SObject book entry description, including public constructor and public output method
    // 
    private class objectBookEntry {
        
        //private List<fieldBookEntry> fieldlist;
        private String objName;
        
		private String outputField (FieldDefinition definition){
            
            String result;
            
            result = definition.Label + ';';
			result += definition.DeveloperName + ';';
			result += definition.QualifiedApiName + ';';
			result += definition.DurableId + ';';
            result += definition.RelationshipName + ';';
        	result += definition.ControllingFieldDefinitionId + ';';
   			result += definition.DataType + ';';
           	result += definition.ExtraTypeInfo + ';';
           	result += definition.IsCalculated + ';';
           	result += definition.IsCompound + ';';
           	result += definition.IsFieldHistoryTracked + ';';
           	result += definition.IsHighScaleNumber + ';';
           	result += definition.IsHtmlFormatted + ';';
           	result += definition.IsIndexed + ';';
           	result += definition.IsNameField + ';';
           	result += definition.LastModifiedById + ';';
           	result += definition.LastModifiedDate + ';';
         	result += definition.Length + ';';
           	result += definition.Precision + ';';
            result += definition.PublisherId + ';';
           	result += definition.Scale + ';';

			result += '\n';
            return result;
        }
        
        //
        // constructor, taking the object name as parameter
        // 
        public objectBookEntry(String objname){           
            this.objname = objname;      
        }
        // 
        // output method : iterate over the fieldList and output each field
        public String output(){
            String result;
            
            // header line
            for (String s : fieldsToGet) { 
                if (result != null) result += s + ';';
                else result = s + ';';
            }
            result += '\n';
            
            // get object fields info from the FieldDefinition table
            String queryfields = 'Select ';
            for (Integer i =0; i < fieldsToGet.size(); i++) {
                queryfields += fieldsToGet[i];
                if ((i+1) < fieldsToGet.size()) queryfields += ',';
            }    
            queryfields += ' From FieldDefinition Where EntityDefinition.QualifiedApiName = \'' + objname + '\'';

            List<FieldDefinition> definitions;
            try{
                definitions = Database.query(queryfields);}
            catch(exception e) {system.debug('oups');}
            
			for (FieldDefinition fd : definitions) result += outputField(fd);
 
            return result;
        }
    }

    public fieldBookCreation (String theObject){
        String body = 'Analyzed object : ' + theObject + '\n';
        objectBookEntry obe = new objectBookEntry(theObject);
        ConnectApi.OrganizationSettings org = ConnectApi.Organization.getsettings();
        String subject = org.name + ' ' + org.orgid + ' ' + theObject + ' book';
        EmailManager.sendMailWithAttachedFile(UserInfo.getUserEmail(),subject,body,theObject+'.csv',obe.output());
    }
}