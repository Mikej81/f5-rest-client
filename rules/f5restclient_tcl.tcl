################################################################################
##  F5 ILX APM Generic REST Client
##
##  Auth type can be Username or OAuth
##  if OAuth is specified, a token will either be generated based on the
##  logged in user,of the static Username specified in restclient_username.
##
##  If authtype Username is specified, the credentials will be generated
##  based on the logged in User, or the credentials specified in
##  resclient_username/password.
##
##  Will add additional logic to check if Bearer Token already exists, and
##  use that for the REST Client.
##
##  Argument 0: (required) METHOD (GET, POST, PUT, DELETE)
##  if not specified defaults to GET
##  Argument 1: (required) Query, can be full request in leiu of args
##  (http://remote.site/tm/mgmt/value/location?arg1=${arg1}&arg2=${arg2})
##  Argument 2: (optional) Arguments (json: args:{ arg1: 'value', arg2: 'value'})
##  Argument 3: (optional) OAuth Bearer Token
##
##  Install:
##   -Create JWT Key to be referenced below (-key /Common/rest-client)
##
## Lab rest-client PSK BDD773012F7B
################################################################################
when RULE_INIT {
    set static::claim_list_string { {sub} {name} }
    set static::claim_list_boolean_int { {admin} }
    set static::jws_cache {oauth-sign-test-jws_cache}
    set static::jwt_issuer {https://f5lab.com}
    set static::jwt_sess_var_name {session.oauth.scope.last.jwt}
    set static::jwt_expires_in 10
    set static::jwt_leeway 0
    set static::jwt_sdb_timeout_adjustment 3

    set static::restclient_enablepassthrough "false"
    set static::restclient_authtype "oauth"
    set static::restclient_authtoken "Authorization"
    set static::restclient_username "testuser"
}

proc gettimeofday {} {
    return [ clock seconds ]
}

proc generate_payload { claim_list_string claim_list_boolean_int } {
    set payload "\{"
    append payload {"issuer":"} $static::jwt_issuer {"}
    set iat [ call gettimeofday ]
    append payload {,"iat":} $iat
    append payload {,"exp":} [ expr { $iat + $static::jwt_expires_in } ]
    append payload {,"nbf":} [ expr { $iat - $static::jwt_leeway } ]
    foreach claim $claim_list_string {
        set value [ ACCESS::session data get "$static::jwt_sess_var_name.$claim" ]
        if { [ string length value ] == 0 } {
            continue
        }
        append payload {,"} $claim {":"} $value {"}
    }
    #foreach claim $claim_list_boolean_int {
    #    set value [ ACCESS::session data get "$static::jwt_sess_var_name.$claim" ]
    #    if { [ string length value ] == 0 } {
    #        continue
    #    }
    #    append payload {,"} $claim {":} $value
    #}
    append payload "\}"
    return $payload
}

proc generate_jws {} {
    set payload [ call generate_payload $static::claim_list_string $static::claim_list_boolean_int ]
    return [ ACCESS::oauth sign -payload $payload -alg RS512 -key /Common/rest-client -ignore-cert-expiry ]
}

proc get_user_key {} {
    set data [ ACCESS::session sid ]
    binary scan [ md5 $data ] H* data
    return $data
}

proc get_user_key_from_sdb {} {
    return [ ACCESS::session data get {session.jwt.cache.user_key} ]
}

proc set_user_key_to_sdb {} {
    ACCESS::session data set {session.jwt.cache.user_key} [ call get_user_key ]
}

proc calc_sdb_timeout {} {
    return [ expr { $static::jwt_expires_in - $static::jwt_sdb_timeout_adjustment } ]
}

proc get_jws_from_cache {} {
    set user_key [ call get_user_key ]
    set jws [ table lookup -notouch -subtable $static::jws_cache $user_key ]
    if { [ string length $jws ] != 0 } {
        return $jws
    }
    return [ table set -notouch -subtable $static::jws_cache -excl $user_key [ call generate_jws ] [ call calc_sdb_timeout ]  [ call calc_sdb_timeout ] ]
}

proc get_jws { from_cache } {
    if { $from_cache == "yes" } {
        return [ call get_jws_from_cache ]
    } else {
        return [ call generate_jws ]
    }
}

proc delete_jws_cache {} {
    set user_key [ call get_user_key_from_sdb ]
    ACCESS::log "Delete cache for $user_key"
    table delete -subtable $static::jws_cache $user_key
}

proc is_bearer_token { header } {
    if { [string tolower [HTTP::header Authorization]] contains "bearer" } {
      return true
    } else {
      return false
    }
}

when ACCESS_SESSION_STARTED {
    call set_user_key_to_sdb
}

when ACCESS_ACL_ALLOWED {
    set jws [call get_jws "yes" ]
    HTTP::header replace Authorization "Bearer $jws"
}

when ACCESS_SESSION_CLOSED {
    call delete_jws_cache
}

when ACCESS_POLICY_AGENT_EVENT {
    switch -glob [ACCESS::policy agent_id] {
      "REST-CLIENT:*" {
        set restClient [ILX::init f5restclient_plugin f5restclient_ext]
        ##  Check if Passthrough Auth enabled, and Bearer Token exists
        if { $static::restclient_enablepassthrough && [call is_bearer_token [HTTP::header Authorization]] } {
            set restResponse [ILX::call $restClient rest-client "GET" "https:://remote.site/tm/mgmt/value/location?arg1=Argument" [HTTP::header Authorization] ]
        } else {
            set restResponse [ILX::call $restClient rest-client "GET" "http://remote.site/tm/mgmt/value/location?arg1=${arg1}&arg2=${arg2}" [call generate_jws]]
        }
        
        if { !([string tolower $restResponse] contains "ERROR") } {
            ACCESS::session data set session.custom.restclient.response
        } else {
            log local0. "Error processing REST Request:  $restResponse"
        }
      }
    }
}

