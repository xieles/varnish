import std; 
# This is a basic VCL configuration file for varnish.  See the vcl(7) 
# man page for details on VCL syntax and semantics. 
# 
# Default backend definition.  Set this to point to your content 
# server. 
# 
# 
acl purgers {                                                           
    "localhost"; 
    "127.0.0.1"; 
} 


backend default { 
  .host = "127.0.0.1"; 
  .port = "8080"; 

 .connect_timeout = 5s; 
 .first_byte_timeout = 60s; 
 .max_connections = 1500; 
} 


 backend web1 { 
     .host = "backend-01-IP"; 
     .port = "80"; 
 	.connect_timeout = 30s; 
 	.first_byte_timeout = 30s; 
 	.between_bytes_timeout = 30s; 
} 

backend web2 { 
  	.host = "Backend-02-IP"; 
 	.port = "80"; 
	.connect_timeout = 30s; 
 	.first_byte_timeout = 30s; 
 	.between_bytes_timeout = 30s; 
} 

director balancer round-robin { 
        { 
                .backend = web1; 
        } 
        { 
                .backend = web2; 
        } 
} 

sub vcl_recv { 
    
#SSL enforced 

if ( (req.http.host ~ "^(?i)" || req.http.host ~ "^(?i)www.yourwebsite.com") && req.http.X-Forwarded-Proto !~ "(?i)https" && (req.url ~ "" || req.url ~ "/"  )) { 
        set req.http.x-Redir-Url = "https://www.yourwebsite.com" + req.url; 

                   } 

if (req.http.host == "webshop.yourwebsite.com") { 
               set req.http.host = "webshop.yourwebsite.com"; 
               set req.backend = balancer; 
                if (req.request == "POST") 
                        { 
                                return (pass); 
                        } 
               return (lookup); 
                } 



if (req.http.host == "store.yourwebsite.com") { 
               set req.http.host = "store.yourwebsite.com"; 
               set req.backend = balancer; 
		if (req.request == "POST") 
			{ 
				return (pass); 
			} 
               return (lookup); 
		}	 

if (req.http.host == "www.yourwebsite.com") { 
               set req.http.host = "www.yourwebsite.com"; 
               set req.backend = balancer; 
                if (req.request == "POST") 
                        { 
                                return (pass); 
                        } 
		 
if (req.url ~ "^/(cart|product|shoppingbag|my-account|checkout|addons|sitemap|order|contact|phpmyadmin|phpMyAdmin)") { 
    return (pipe); 
  } 

 return (lookup); 
                } 


# Use anonymous, cached pages if all backends are down. 
  if (!req.backend.healthy) 
  { 
    unset req.http.Cookie; 
  } 

# Allow the backend to serve up stale content if it is responding slowly. 
if (req.request == "PURGE") { 
        if (!client.ip ~ purgers) { 
            error 405 "You are not allowed to purge"; 
        } 
            return(lookup); 
    } 
 
 set req.grace = 6h; 
			 
} 

sub vcl_deliver { 
        if (obj.hits > 0) { 
                set resp.http.X-Cache = "HIT"; 
        } else { 
                set resp.http.X-Cache = "MISS"; 
        } 
} 

sub vcl_fetch { 

set beresp.ttl = 1d; 

# Allow items to be stale if needed. 
set beresp.grace = 6h; 

} 

sub vcl_hit { 
    if (req.request == "PURGE"){ 
        set obj.ttl = 0s; 
        error 200 "Varnish cache has been purged for this object."; 
    } 
} 


# In the event of an error, show friendlier messages. 
sub vcl_error { 

#SSL enforcing 
if (obj.status == 750) { 
        set obj.http.Location = obj.response; 
        set obj.status = 301; 
        return (deliver); 
    } 

if (obj.status == 401) { 
  set obj.http.Content-Type = "text/html; charset=utf-8"; 
  set obj.http.WWW-Authenticate = "Basic realm=Secured"; 
  synthetic {" 

 <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" 
 "http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd"> 

 <HTML> 
 <HEAD> 
 <TITLE>Error</TITLE> 
 <META HTTP-EQUIV='Content-Type' CONTENT='text/html;'> 
 </HEAD> 
 <BODY><H1>401 Unauthorized (varnish)</H1></BODY> 
 </HTML> 
 "}; 
  return (deliver); 
} 

# Otherwise redirect to the homepage, which will likely be in the cache. 
  set obj.http.Content-Type = "text/html; charset=utf-8"; 
  synthetic {" 
<html> 
<head> 
  <title>Page Unavailable</title> 
  <style> 
    body { background: #303030; text-align: center; color: white; } 
    #page { border: 1px solid #CCC; width: 500px; margin: 100px auto 0; padding: 30px; background: #323232; } 
    a, a:link, a:visited { color: #CCC; } 
    .error { color: #222; } 
  </style> 
</head> 
<body onload="setTimeout(function() { window.location = '/' }, 5000)"> 
  <div id="page"> 
    <h1 class="title">Page Unavailable</h1> 
    <p>The page you requested is temporarily unavailable.</p> 
    <p>We're redirecting you to the <a href="/">homepage</a> in 5 seconds.</p> 
    <div class="error">(Error "} + obj.status + " " + obj.response + {")</div> 
  </div> 
</body> 
</html> 
"}; 
  return (deliver); 
}
