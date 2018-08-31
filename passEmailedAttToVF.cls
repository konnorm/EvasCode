public class passEmailedAttToVF implements Messaging.InboundEmailHandler{
    public String encodeStr;     
    public String logData = '';
    public String fileName;
   
    //Get the attachment from the email
    public Messaging.InboundEmailResult handleInboundEmail(Messaging.inboundEmail email, Messaging.inboundEnvelope env){
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        
        system.debug('attachment: ' + email.binaryAttachments);
       
        if(email.binaryAttachments != null){
            logData += email.binaryAttachments.size() + ' attachment(s) from the Email. \n';
            
        	for(Messaging.InboundEmail.binaryAttachment bAtt : email.binaryAttachments){
                fileName = bAtt.fileName;
                
                system.debug('File name: ' + fileName);
                
                logData += 'File name: ' + fileName + '\n';
                Blob xlsFile = bAtt.body;
                encodeStr = EncodingUtil.base64Encode(xlsFile);
                
                passFileToCloudConvert(encodeStr); 
        	}
            
        }
        
        return result;
    }

    public void passFileToCloudConvert(String encodeStr){
        String processID;
        String jobName;
        Integer requiredT;
        DateTime now = DateTime.now();
        Integer today = now.day();
        //Integer hour = now.hour();
        //Integer thisY = now.year();
        //Integer executeT = now.minute()+2;
        ECS__Supplier__c cg;
        //String url;
        
        //api: 6799294ca9bde287111d4e7581a7e9ec
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.convertio.co/convert');
        req.setMethod('POST');
        //application/x-www-form-urlencoded; charset=UTF-8
        req.setHeader('Content-Type', 'multipart/form-data');
        req.setBody('{"apikey":"6799294ca9bde287111d4e7581a7e9ec",'+
					'"input":"base64",'+
                    '"file":"'+ encodeStr + '",'+
					'"filename":"'+ fileName +'",'+
					'"inputformat":"xls",'+
					'"outputformat":"csv",'+
					'"download":"true"}');
     
        Http http = new Http();
        HttpResponse res = http.send(req);
        
            String response = res.getBody();          
			system.debug('response: '+ response); 
        	JSONParser parser = JSON.createParser(response);
        		while(parser.nextToken()!= Null){
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) && (parser.getText() == 'id')){
                        parser.nextToken();
                        processID = parser.getText();
                        //break;
                    }
        		}
            jobName = 'check status'+ now ;
        	List <ECS__Supplier__c> supp = New List<ECS__Supplier__c>();
        	supp = [SELECT 	File_Convert_ID__c, Id FROM ECS__Supplier__c WHERE Name = 'CG' LIMIT 1]; // name needs to be modifidied
        	for(ECS__Supplier__c tempcg : supp){
            	tempcg.File_Convert_ID__c = processID;
                //tempcg.Scheduled_Check_Conversion__c = jobName;
          		cg = tempcg;
        	}
         	//supp.add(cg);
        	system.debug(supp);
        	update supp;
        
            system.debug(processID);
            logData += fileName + 'has been sent to CloudConvert to convert to a CSV file.' + '\n';
            
        	
        	system.debug(logData);

        	System.debug(res.getBody());
        	
        	//************************************************
        	// If query list less than 5, schedules jobs that run every 10 mins during 8:30 ~ 9:10
        	// (checkCSVConvertion updates CG inventory and sent email to inform user updated SKUs,
        	//  if CG inventory has changed)
        	//************************************************ 
        	List<AsyncApexJob> scheduled = [SELECT Id FROM AsyncApexJob WHERE MethodName='checkStatus'];
        	if(scheduled.size()<5){
            	system.schedule(jobName+' 1' , '0 '+ 34 + ' '+ 11 +' * * ?' , New checkCSVConvertion());
                system.schedule(jobName+' 2' , '0 '+ 35 + ' '+ 11 +' * * ?' , New checkCSVConvertion());
                system.schedule(jobName+' 3' , '0 '+ 36 + ' '+ 11 +' * * ?' , New checkCSVConvertion());
                system.schedule(jobName+' 4' , '0 '+ 0 + ' '+ 9 +' * * ?' , New checkCSVConvertion());
                system.schedule(jobName+' 5' , '0 '+ 10 + ' '+ 9 +' * * ?' , New checkCSVConvertion());
        	}
        
       		logData += 'The Jobs below are scheduled: \n '+ jobName +' 1 \n' + jobName +' 2 \n'+ jobName +' 3 \n' + jobName +' 4 \n' + jobName +' 5 \n';

           
       		system.debug(logData);       
       		ECS__Log__c log = New ECS__Log__c();
       		log.ECS__Log_Name__c = 'passEmailedAttToVF';
       		log.ECS__Application__c = 'passEmailedAttToVF';
       		log.ECS__Context__c = 'passEmailedAttToVF';
      	 	log.ECS__Log_Detail__c = logData;
       		Insert log;
               
    }

}