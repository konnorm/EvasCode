@isTest
global class HttpCalloutMockImp implements HttpCalloutMock {
    Integer code; 
    String body;
    
    global HttpCalloutMockImp(Integer code, String body){
        this.code = code;
        this.body = body;
    }
    
    global HTTPResponse respond(HTTPRequest req){
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody(body);
        res.setStatusCode(code); 
        return res;
    }
}
