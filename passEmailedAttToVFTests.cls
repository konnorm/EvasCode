@isTest
public class passEmailedAttToVFTests {
    //For query processID
    @testSetup static void setup(){
        ECS__Supplier__c setprocessID = new ECS__Supplier__c();
		setprocessID.File_Convert_ID__c = 'testId';
        setprocessID.ECS__External_Id__c = 'eID';
        setprocessID.Name = 'CG';
        insert setprocessID;
        
        ECS__Product__c setB2C = new ECS__Product__c();
        setB2C.Name = 'testB2C';
        insert setB2C;
        
        List<ECS__Supplier__c> cgIDList = [SELECT Id FROM ECS__Supplier__c WHERE Name = 'CG' LIMIT 1];
        String cgID = String.valueOf(cgIDList);
        cgID = cgID.mid(22, 18);
        
        List<ECS__Product__c> b2cList = [SELECT Id FROM ECS__Product__c WHERE Name = 'testB2C' LIMIT 1];
        String b2cID = String.valueOf(b2cList);
        b2cID = b2cID.mid(21, 18);
        
        ECS__Supplier_Product__c setExistingCG = new ECS__Supplier_Product__c();
        setExistingCG.Name = 'testName';
        //setExistingCG.ECS__B2C_Product__c = 'test';
        setExistingCG.ECS__Supplier__c = cgID;
        setExistingCG.ECS__Supplier_SKU__c = '02-AZ-AA306-PBC';
        setExistingCG.ECS__Available_Units__c = 9.0;
        setExistingCG.ECS__B2C_Product__c = b2cID; 
        setExistingCG.ECS__External_Id__c= 'testEId';
        insert setExistingCG;
    }
        
    testMethod static void testConversionSucceed(){
        String step = '"step":"finish"';
        String step_percent = '"step_percent":100';
        String body = '{"example":"test", "Id":"testId", "minutes": 63, "data":{' + step + ',' + step_percent+', "output":{"url":"test@test"}, "content": "aGVhZGVyL24KMDItQVotQUEzMDYtUEJDLDQwCjAyLUFaLUFBNDA3LVBCQyw0MA=="}}';
        Test.startTest();
		// I don't think all of the below has to be in the Test.startTest - stopTest area. Can you move some of it out? 
		// The only stuff that should be in this area are things that directly use your classes of interest
		Messaging.InboundEmail email = new Messaging.InboundEmail();
		Messaging.InboundEnvelope envolope = new Messaging.InboundEnvelope();

		email.subject = 'testFileAttached';
		email.fromAddress = 'test@gmail.com';
		email.plainTextBody = 'Testing';

		Messaging.InboundEmail.BinaryAttachment bAtt = new Messaging.InboundEmail.BinaryAttachment();
		bAtt.fileName = 'testbAtt';
		bAtt.body =  blob.valueOf('my attachment text');
		bAtt.mimeTypeSubType = 'text/plain';
		email.binaryAttachments = new Messaging.InboundEmail.binaryAttachment[]{bAtt};

		Test.setMock(HttpCalloutMock.class, new HttpCalloutMockImp(200, body));
		passEmailedAttToVF testEmail = new passEmailedAttToVF();
		testEmail.handleInboundEmail(email, envolope);

		String hr = String.valueOf(Datetime.now().hour());
		String min = String.valueOf(Datetime.now().minute());
		String sec = String.valueOf(Datetime.now().second()+1);
		String nextFireDay = String.valueOf(Datetime.now().day()+1);
		System.schedule('test', sec +' '+ min + ' '+ hr +' '+ nextFireDay + ' * ?', new checkCSVConvertion());
            
        Test.stopTest();
    }
    
    testMethod static void testConversionFaild(){
        String step = '"step":" "';
        String step_percent = '"step_percent":0';
        String body = '{"example":"test", "Id":"testId", "minutes": 63, "data":{' + step + ',' + step_percent+', "output":{"url":"test@test"}, "content": "aGVhZGVyL24KMDItQVotQUEzMDYtUEJDLDQwCjAyLUFaLUFBNDA3LVBCQyw0MA=="}}';
        Test.startTest();
		Messaging.InboundEmail email = new Messaging.InboundEmail();
		Messaging.InboundEnvelope envolope = new Messaging.InboundEnvelope();

		email.subject = 'testFileAttached';
		email.fromAddress = 'test@gmail.com';
		email.plainTextBody = 'Testing';

		Messaging.InboundEmail.BinaryAttachment bAtt = new Messaging.InboundEmail.BinaryAttachment();
		bAtt.fileName = 'testbAtt';
		bAtt.body =  blob.valueOf('my attachment text');
		bAtt.mimeTypeSubType = 'text/plain';
		email.binaryAttachments = new Messaging.InboundEmail.binaryAttachment[]{bAtt};
		Test.setMock(HttpCalloutMock.class, new HttpCalloutMockImp(401,body));
		passEmailedAttToVF testEmail = new passEmailedAttToVF();
		testEmail.handleInboundEmail(email, envolope);      	
        Test.stopTest();
    }

	
}
