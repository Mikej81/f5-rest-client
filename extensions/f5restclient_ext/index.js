var Client = require('node-rest-client').Client;

var client = new Client();
var f5 = require('f5-nodejs');

var ilx = new f5.ILXServer();

 ilx.addMethod('rest-client', function(req, res) {
   // Function parameters can be found in req.params().

   var method = req.params()[0] || 'GET';
   var query = req.params()[1] || '';
   var args = req.params()[2] || '';
   var rest_get;
   var rest_post; // POST, PUT, DELETE, etc...

   
   if (method === "GET") {
       rest_get = client.get("http://remote.site/rest/xml/method", function (data, response) {
           // parsed response body as js object
           return data;
           // raw response
           // tmpResraw = response;
       });
       rest_get.on('error', function (err) {
           console.log('request error', err);
           rest_get = err;
       });
   } else {
       // POST, PUT, PATCH, DELETE
       // arguments are needed for POST method / content-type
       var reqArgs = {
           data: {}, // (optional) data passed to REST method (only useful in POST, PUT or PATCH methods)
           path: {}, // (optional) path substitution var
           parameters: {}, // (optional) this is serialized as URL parameters
           headers: { "Content-Type": "application/json" }, // (required) request headers
           requestConfig: {
               timeout: 1000, //request timeout in milliseconds
               noDelay: true, //Enable/disable the Nagle algorithm
               keepAlive: true, //Enable/disable keep-alive functionalityidle socket.
               keepAliveDelay: 1000 //and optionally set the initial delay before the first keepalive probe is sent
               },
           responseConfig: {
               timeout: 1000 //response timeout
               }
       };
       
       rest_post = client.post("http://remote.site/rest/xml/method", args, function (data, response) {
           // parsed response body as js object
           return data;
           // raw response
           // tmpResraw = response;
       });
       rest_post.on('requestTimeout', function (req) {
           console.log('request has expired');
           rest_post.abort();
           rest_post = "REQUEST TIMEOUT";
       });
       rest_post.on('responseTimeout', function (res) {
           console.log('response has expired');
           rest_post = "RESPONSE TIMEOUT";
       });
    //End if   
   }

  var rest_response = rest_get || rest_post;     

   res.reply([rest_response, '<NOT IMPLEMENTED>']);
 });

ilx.listen();
