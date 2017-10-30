#
# This is an example VCL file for Varnish.
#
# It does not do anything by default, delegating control to the
# builtin VCL. The builtin VCL is called when there is no explicit
# return statement.
#
# See the VCL chapters in the Users Guide at https://www.varnish-cache.org/docs/
# and http://varnish-cache.org/trac/wiki/VCLExamples for more examples.

# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
vcl 4.0;
import std;
import directors;

# Default backend definition. Set this to point to your content server.
backend server1 {
    .host = "127.0.0.1";
    .port = "81";
    .probe = {
      .url = "/";
      .interval = 30s;
      .timeout = 10s;
      .window = 10;
      .threshold = 10;
      }
}

backend server2 {
    .host = "127.0.0.1";
    .port = "82";
    .probe = {
      .url = "/";
      .interval = 30s;
      .timeout = 10s;
      .window = 10;
      .threshold = 10;
      }
}

backend server3 {
    .host = "127.0.0.1";
    .port = "83";
    .probe = {
      .url = "/";
      .interval = 30s;
      .timeout = 10s;
      .window = 10;
      .threshold = 10;
      }
}


backend server4 {
    .host = "127.0.0.1";
    .port = "84";
    .probe = {
      .url = "/";
      .interval = 30s;
      .timeout = 10s;
      .window = 10;
      .threshold = 10;
      }
}


sub vcl_init {
    new vdir = directors.round_robin();
    vdir.add_backend(server1);
    vdir.add_backend(server2);
    vdir.add_backend(server3);
    vdir.add_backend(server4);
}

sub vcl_hash {
    hash_data(req.url);
}

sub vcl_pipe {
     if (req.http.upgrade) {
         set bereq.http.upgrade = req.http.upgrade;
     }
}

sub vcl_hit {
    if (std.healthy(req.backend_hint)) {
        # Backend is healthy. Limit age to 30s.
        if (obj.ttl + 30s > 0s) {
            #set req.http.grace = "normal(limited)";
            return (deliver);
        } else {
            # No candidate for grace. Fetch a fresh object.
            return(fetch);
        }
    } else {
        # backend is sick - use full grace
        if (obj.ttl + obj.grace > 0s) {
            #set req.http.grace = "full";
            return (deliver);
	} else {
	    # no graced object.
	    return (fetch);
	}
    }
    return (fetch);
}

# handles redirecting from http to https
sub vcl_synth {
  if (resp.status == 750) {
    set resp.status = 301;
    set resp.http.Location = req.http.x-redir;
    return(deliver);
  }
}

sub vcl_recv {
    # Happens before we check if we have this in cache already.
    #
    # Typically you clean up the request here, removing cookies you don't need,
    # rewriting the request, etc.
    set req.backend_hint = vdir.backend();
    if (req.url ~ "\.(png|gif|jpg|ico|swf|css|js)$") {
        return(hash);
    }
    unset req.http.X-Forwarded-For;
    set    req.http.X-Forwarded-For = client.ip;
    if (req.http.Upgrade ~ "(?i)websocket") {
         return (pipe);
     }
    # Where ever there is <hostname>, It has to be changed to system's host name ($hostname). eg., tribler.blr.dreamworks.net
    # Where ever there is <host>, It has to be changed to system's host name ($host). eg., tribler
    # Where ever there is <aliasesname>, It has to be changed to system's aliases name. eg., performdev.gld.dreamworks.net is an aliase for tribler.gld.dreamworks.com
    # Where ever there is <alias>, It has to be changed to system's alias. eg., perform
    if ( (req.http.host ~ "^(?i)<hostname>$" || req.http.host ~ "^(?i)<host>$" || req.http.host ~ "^(?i)<aliasesname>$" || req.http.host ~ "^(?i)<alias>$") && req.http.X-Forwarded-Proto !~ "(?i)https") {
         set req.http.x-redir = "https://" + "performdev.gld.dreamworks.net" + req.url;
         return (synth(750, ""));
    }
    if ( (req.http.X-Forwarded-Proto ~ "(?i)https") && req.http.host ~ "^(?i)<alias>$")
    {
         set req.http.x-redir = "https://" + "performdev.gld.dreamworks.net" + req.url;
         return (synth(750, ""));
    }
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    #
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.
    set beresp.grace = 1h;

    if (bereq.url ~ "\.(jpg|jpeg|gif|ico|png)$") {
        set beresp.ttl = 1w;
    }

    # strip the cookie before the image is inserted into cache.
    # https://www.varnish-cache.org/trac/wiki/VCLExampleCacheCookies
     if (bereq.url ~ "\.(png|gif|jpg|swf|ico|css|js)$") {
       unset beresp.http.set-cookie;
     }

    if (beresp.ttl <= 0s || beresp.http.Set-Cookie) {
    return (deliver);
    }

    return (deliver);
}

sub vcl_deliver {
    # Happens when we have all the pieces we need, and are about to send the
    # response to the client.
    #
    # You can do accounting or modifying the final object here.
    if (obj.hits > 0) {
        set resp.http.X-Cache-Varnish = "HIT";
        set resp.http.X-Cache-Hits = obj.hits;
        }
    else {
        set resp.http.X-Cache = "MISS";
    }

    return (deliver);
}
