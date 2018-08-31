public class checkCSVConvertion implements Schedulable {
    private String[] recipients = new String[]{'yama762682@gmail.com'};
        
    public void execute(SchedulableContext SC){
        checkStatus();
    }
    
    @future(callout = true)
    public static void checkStatus(){
        String step, logData = '', url;
        Integer step_percent;
        Integer staCode;
        
        ECS__Supplier__c CG = [SELECT File_Convert_ID__c, Id FROM ECS__Supplier__c WHERE Name = 'CG' LIMIT 1];
        String processId = CG.File_Convert_ID__c;
        //String jobName = CG.Scheduled_Check_Conversion__c;
        String content;
        Blob csv;
       
        //request for status 
        HttpRequest req = New HttpRequest();
        req.setEndpoint('https://api.convertio.co/convert/'+ processId + '/status');
        req.setMethod('GET');
        req.setHeader('Authorization', '6799294ca9bde287111d4e7581a7e9ec'); // Authorization Key should be in a custom settings field
        Http http = new Http();
        HttpResponse res = http.send(req);
        staCode = res.getStatusCode();
        System.debug(res.getBody());
        
        if(staCode != 200){
            System.debug('Something went wrong during file conversion. Please go to https://convertio.co/api/docs/. Conversion ID: ' + processId);
            logData += 'Something went wrong during file conversion. Please go to https://convertio.co/api/docs/. Conversion ID: ' + processId;
        } else {
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> data = (Map<String, Object>) m.get('data');
            Map<String, Object> output = (Map<String, Object>) data.get('output');
            stepPercent = Integer.valueOf(data.get('step_percent')); // Don't change from Camel Case to Underscore, one is not better than the other but you should remain consistent
            if(stepPercent == 100){
                HttpRequest req2 = New HttpRequest();
        	    req2.setEndpoint('https://api.convertio.co/convert/'+ processId +'/dl/base64');
        	    req2.setMethod('GET');
        
        	    Http http2 = New Http();
       		    HttpResponse res2 = http2.send(req2);
       		    System.debug(res2.getBody());
                
                Map<String, Object> cd = (Map<String, Object>) JSON.deserializeUntyped(res2.getBody());
                Map<String, Object> conData = (Map<String, Object>)cd.get('data');
                
                content = String.valueOf(conData.get('content'));
                csv = EncodingUtil.base64Decode(content);
                //System.debug(csv.toString());
                logData += 'The file is sucessfully converted to csv.'+'\n';
                    
         
                 //************************************************
                 //   * Compare the returned csv file with existing CG 
                 //		1. update the QTY difference
                 //		2. report new SKUs and its QTY
                 //		3. report the updated SKUs 
                 //************************************************
                 Map<String, ECS__Supplier_Product__c> existingCGMap = new Map<String, ECS__Supplier_Product__c>();
                 String lastSKU = '';
                 Integer lastCount = 10000;
                
                //***********query CG**************
                while(lastCount == 10000 && Limits.getAggregateQueries() <= Limits.getLimitAggregateQueries()) {
                    List<ECS__Supplier_Product__c> existingCG = [SELECT Id, Name, ECS__Supplier_SKU__c, ECS__Available_Units__c FROM ECS__Supplier_Product__c 
                                                               WHERE ECS__Supplier__r.Name = 'CG' AND ECS__Supplier_SKU__c > :lastSKU
                                                               ORDER BY ECS__Supplier_SKU__c LIMIT 10000];
                    lastCount = existingCG.size();
                    for(ECS__Supplier_Product__c SP : existingCG){
                        existingCGMap.put(SP.ECS__Supplier_SKU__c, SP);
                        lastSKU = SP.ECS__Supplier_SKU__c;
                    }
                    System.debug('existingCG: '+ existingCG); 
                }

                //***********read returned csv**************
                Map<String, Integer> csvMap = new Map<String, Integer>();
                Integer countNewSKU = 0;
                String[] fileLines = new String[]{};
                String file = csv.toString();
                fileLines = file.split('\n');
                List<ECS__Supplier_Product__c> updateList = new List<ECS__Supplier_Product__c>();
                List<List<String>> newSKUs = new List<List<String>>();
                
        		 for(Integer i = 1; i < fileLines.size(); i++){
            	 	String[] eachLine = new String[]{}; 
            	 	eachLine = fileLines[i].split(',');
                     
                    //***********compare returned csv with existing CG and update SF*************
                    String csvSKU = eachLine[0].remove('"');
                    Integer csvQTY = Integer.valueOf(eachLine[1].remove('"'));
                    if(csvQTY >= 3){//for inbantory alert
                    	csvQTY -= 3;  
                    }
                    
                    if(csvQTY >= 5){ //shows 5 if the quantity >= 5
                         csvQTY = 5;
                     }
                    
                    
                    ECS__Supplier_Product__c existingProd = existingCGMap.get(csvSKU);
                    System.debug('existingCGMap: '+ existingCGMap); 
                    System.debug('csvSKU:'+ csvSKU);
                    System.debug(existingProd);
                     
                    if(existingProd != null && existingProd.ECS__Available_Units__c != csvQTY){
                        existingProd.ECS__Available_Units__c = csvQTY;
                     	updateList.add(existingProd);
                    }
                     
                    csvMap.put(eachLine[0], csvQTY);
                    System.debug('csvMap: '+ csvMap );
                    
                    System.debug('updateList: '+ updateList );
                    System.debug(updateList.size());
                 }
                
                if(updateList.size() != 0){
                    update updateList;
                    sentCGUpdateRept(updateList);
                    logData += 'The CG update report has been sent to: ' + recipients + '\n';
                    logData += 'The following CG SKUs quantity have been updated: \n';
                    for(ECS__Supplier_Product__c item : updateList) logData += item.ECS__Supplier_SKU__c;                    
                } else {
                    logData += 'CG quantity is same as the last update.';
                }
            }
        }
        ECS__Log__c log = New ECS__Log__c();
        log.ECS__Log_Name__c = 'checkCSVConvertion';
        log.ECS__Application__c = 'checkCSVConvertion';
        log.ECS__Context__c = 'checkCSVConvertion';
        log.ECS__Log_Detail__c = logData;
        insert log;        
    }
 
    //************************************************
    //  Report User
    //************************************************
    public static void sentCGUpdateRept(List<ECS__Supplier_Product__c> updateL){
        String updated = '', newSKU = '';
        Integer count;
        for(Integer j=0; j < updateL.size(); j++){
            count = j+1 ;
            updated += count + '.)' +updateL[j].ECS__Supplier_SKU__c + '\n';
            
        }
        String textBody = 'The quantity of these items have been updated: \n' + updated; 
        
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.toaddresses = recipients;
        message.optoutpolicy = 'FILTER';
        message.subject = 'CG Inventory Update Report'; 
        message.plainTextBody = textBody;
        Messaging.SingleEmailMessage[] messages = new Messaging.SingleEmailMessage[]{message};
        Messaging.SendEmailResult[] results = Messaging.SendEmail(messages);
        
        if(results[0].success) System.debug('The report has been sent to users');
        else System.debug('The email failed to send: ' + results[0].errors[0].message);
    }
    
    
    //************************************************
    //  *Delete scheduled job
    //   1.abort job that has 'checkStatus' as MethodName
    //   2.purge all aborted job from today
    //   3.abort same job scheduled for tomorrow
    //************************************************  
    /*          
    public static void deleteScheduledCheckStatus(){
        DateTime now = DateTime.now();
        DateTime nextFire = now.addDays(1);
        Integer countPurged = system.purgeOldAsyncJobs(Date.today());
        system.debug(nextFire);
        system.debug('countPurged:' + countPurged);
        List<CronTrigger> NextFireJob = [SELECT Id, State , NextFireTime FROM CronTrigger WHERE NextFireTime = :nextFire];
        for(Integer nfj=0; nfj<NextFireJob.size(); nfj++){
            system.abortJob(NextFireJob[nfj].Id);
        }
    }*/     
}
