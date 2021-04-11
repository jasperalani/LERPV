#
# This is an example VCL file for Varnish.
#
# It does not do anything by default, delegating control to the
# builtin VCL. The builtin VCL is called when there is no explicit
# return statement.
#
# See the VCL chapters in the Users Guide at https://www.varnish-cache.org/docs/
# and https://www.varnish-cache.org/trac/wiki/VCLExamples for more examples.

# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
vcl 4.0;

# Default backend definition. Set this to point to your content server.
backend default {
    .host = "localhost";
    .port = "80";
}

acl purge {
    "localhost";
    "172.0.0.0"/8;
    "10.0.0.0"/8;
}

sub vcl_recv {
    set req.http.X-Original-Proto = req.http.X-Forwarded-Proto;
    # Handle purge requests if IP is within permitted access list
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return(synth(405,"Not allowed."));
        }
        if (req.http.X-Purge-Method) {
            if (req.http.X-Purge-Method ~ "(?i)regex") {
                ban("req.http.host == " + req.http.host +
                    " && req.url == " + req.url);

                # Throw a synthetic page so the request won't go to the backend.
                return(synth(200, "Ban added"));
            }
        }

        return (purge);
    }

    # Don't cache pages if the request header is set to disable varnish caching
    if(req.http.X-No-Cache-Varnish ~ "1") {
        return(pass);
    }

    # Only cache GET or HEAD requests. This makes sure the POST requests are always passed.
    if (req.method != "GET" && req.method != "HEAD") {
        return(pass);
    }

    # We don’t interfere with auth requests
    if (req.http.Authorization) {
        return(pass);
    }

    # If the request is admin-ajax.php and we let the result be cachable, then proceed to vcl_hash
    if (req.url ~ "admin-ajax.php") {
        return(hash);
    }

    # Don't cache the intranet site at all
    if(req.http.host ~ "(intranet.colart.com|workflows.colart.com)") {
        return(pass);
    }

    # WordPress requests we don’t want to cache
    if (req.url ~ "wp-(login|admin|signup|cron|activate|mail|json)" && req.http.Cookie !~ "wp-postpass") {
        return(pass);
    }

    # Dont cache previews of pages while editors are working on them
    if (req.url ~ "preview=true") {
        return(pass);
    }

    # Pass through the WooCommerce dynamic pages
    if (req.url ~ "^/(cart|cesta|carrello|bag|my-account|checkout|wc-api/*|addons|logout|lost-password)") {
        return (pass);
    }

    # Pass through the WooCommerce add to cart
    if (req.url ~ "\?add-to-cart=" ) {
        return (pass);
    }

    # Pass through the WooCommerce API
    if (req.url ~ "\?wc-api=" ) {
        return (pass);
    }

    # Unset Cookies except for WordPress admin and WooCommerce pages
    if (!(req.url ~ "(wp-login|wp-admin|cart|cesta|carrello|my-account|checkout|wc-api*|addons|logout|lost-password)")) {
        unset req.http.cookie;
    }
}

sub vcl_backend_response {
    // By default lets cache everything for 24hrs
    set beresp.ttl = 86500s;

    if(beresp.http.cache-control ~ "no-cache") {
       set beresp.ttl = 0s;
    }

    # Use Varnish to Gzip response, if suitable, before storing it on cache.
    # See https://www.varnish-cache.org/docs/4.0/users-guide/compression.html
    # See https://www.varnish-cache.org/docs/4.0/phk/gzip.html
    if ( ! beresp.http.Content-Encoding
      && ( beresp.http.content-type ~ "(?i)text"
        || beresp.http.content-type ~ "(?i)application/x-javascript"
        || beresp.http.content-type ~ "(?i)application/javascript"
        || beresp.http.content-type ~ "(?i)application/rss+xml"
        || beresp.http.content-type ~ "(?i)application/xml"
        || beresp.http.content-type ~ "(?i)Application/JSON")
    ) {
      set beresp.do_gzip = true;
    }

    return (deliver);
}

sub vcl_hash {
    if (req.http.X-Forwarded-Proto) {
        hash_data(req.http.X-Forwarded-Proto);
    }
}

sub vcl_deliver {
   set resp.http.X-Cache-Node = server.hostname;
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }
}
