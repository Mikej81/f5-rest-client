when ACCESS_POLICY_AGENT_EVENT {
    switch -glob [ACCESS::policy agent_id] {
      "REST-CLIENT:*" {
        set restClient [ILX::init f5restclient_plugin f5restclient_ext]
        ##  Argument 0: (required) METHOD (GET, POST, PUT, DELETE)
        ##  if not specified defaults to GET
        ##  Argument 1: (required) Query, can be full request in leiu of args 
        ##  (http://remote.site/tm/mgmt/value/location?arg1=${arg1}&arg2=${arg2})
        ##  Argument 2: (optional) Arguments (json: args:{ arg1: 'value', arg2: 'value'})
        set restResponse [ILX::call $restClient rest-client "GET" "http://remote.site/tm/mgmt/value/location?arg1=${arg1}&arg2=${arg2}"]
        if { !([string tolower $restResponse] contains "ERROR") } {
            ACCESS::session data set session.custom.restclient.response
        } else {
            log local0. "Error processing REST Request:  $restResponse"
        }
      }
    }
}
