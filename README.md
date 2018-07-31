# f5-rest-client

To Use, modify restResponse arguments TCL:

  **  Argument 0: (required) METHOD (GET, POST, PUT, DELETE)
    if not specified defaults to GET
  
  **  Argument 1: (required) Query, can be full request in leiu of args 
    (http://remote.site/tm/mgmt/value/location?arg1=${arg1}&arg2=${arg2})
  
  **  Argument 2: (optional) Arguments (json: args:{ arg1: 'value', arg2: 'value'})
  
  **  set restResponse [ILX::call $restClient rest-client "GET" "http://remote.site/tm/mgmt/value/location?arg1=${arg1}&arg2=${arg2}"]
  
  ## Notes
  **  args not fully implemented yet... push everything via Querystring
