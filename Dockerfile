FROM alpine:latest

MAINTAINER Natan <natan@mokyun.net>

# Install dependencies and build
RUN \
    apk update \
    && apk add --no-cache --virtual .build-deps \
        cargo \
        git \
    && apk add --no-cache \
	gcc \
    && git clone --single-branch --branch master https://github.com/katattakd/KatWebX --recursive \
    && cd KatWebX \
    && cargo build --release

# Set KatWebX dir
WORKDIR KatWebX

# Set config ARGS. You can define here or use docker-compose to do that (recomended!!).
ARG STREAM_TIMEOUT
ARG LOG_FORMAT
ARG ROOT_FOLDER
ARG ENABLE_PROTECT
ARG CACHING_TIMEOUT
ARG COMPRESS_FILES
ARG ENABLE_HSTS
ARG APPLICATION

# Mount config
RUN echo $' \n\
          # default.toml - KatWebXs Default Configuration. \n\
          # Note that regex can be enabled for some fields by adding r# to the beginning of the string. \n\
          # This configuration file covers all possible configuration options. For the server and content sections, default values are commented out. \n\
 \n\
          [server] \n\ 
          # Server related settings. \n\
          # http_addr and tls_addr specify the address and port KatWebX should bind to. \n\
          # When using socket listening, these values are ignored. \n\
          http_addr = "[::]:80" \n\
          tls_addr = "[::]:443" \n\
 \n\
          # stream_timeout controls the maximum amount of time the connection can stay open (in seconds). \n\
          # The default value should be good enough for transfering small files. If you are serving large files, increasing this is recommended. \n\
          stream_timeout = '$STREAM_TIMEOUT$' \n\
 \n\
          # copy_chunk_size adjusts the maximum file size (in bytes) which can be directly copied into the response. \n\
          # Files larger than this value are copied into the response in chunks of this size, which increases latency. \n\
          # When the file is smaller than this value, it is copied directly into the response. This can heavily increase RAM usage on busy servers. \n\
          # The default value should be good enough for 99% of use cases, dont adjust this unless you know what you are doing. \n\
          #copy_chunk_size = 65536 \n\
 \n\
          # prefer_chacha_poly makes the server prefer using the CHACHA20_POLY1305_SHA256 ciphersuite, instead of using the ciphersuites that the client prefers (usually AES). \n\
          # On CPUs which dont support AES-NI (some very old x86 and most non-x86 CPUs), this can give a ~7x speedup. This should be left disabled on CPUs supporting AES-NI, as it can cut peformance in half. \n\
          #prefer_chacha_poly = false \n\
 \n\
          # log_format controls the format used for logging requests. \n\
          # Supported values are combinedvhost, combined, commonvhost, common, simpleplus, simple, minimal, and none. \n\
          # Note that logging can have a peformance impact on heavily loaded servers. If your server is under extreme load (100+ requests/second), setting the logging format to "minimal" or "none" can significantly increase peformance. \n\
          log_format = '$LOG_FORMAT$' \n\
 \n\
          # cert_folder controls the folder used for storing TLS certificates, encryption keys, and OCSP data. \n\
          #cert_folder = "ssl" \n\
 \n\
          # root_folder controls the web server root. The default folder (html) and per-domain folders will be stored in here. \n\
          root_folder = '$ROOT_FOLDER$' \n\
 \n\
 \n\
          [content] # Content related settings. \n\
          # protect allows prevention of some common security issues through the use of HTTP security headers. \n\
          # Note that this can break some badly designed sites, and should be tested before use in production. \n\
          protect = '$ENABLE_PROTECT$' \n\
 \n\
          # caching_timeout controls how long the content is cached by the client (in hours). \n\
          caching_timeout = '$CACHING_TIMEOUT$' \n\
 \n\
          # compress_files allows the server to save brotli compressed versions of files to the disk. \n\
          # When this is disabled, all data will be compressed on-the-fly, severely reducing peformance. \n\
          # Note that this only prevents the creation of new brotli files, existing brotli files will still be served. \n\
          compress_files = '$COMPRESS_FILES$' \n\
 \n\
          # hsts forces all clients to use HTTPS, through the use of HTTP headers and redirects. \n\
          # Note that this will also enable HSTS preloading. Once you are on the HSTS preload list, its very difficult to get off of it. \n\
          # You can learn more about HSTS preloading and get your site added to the preload list here: https://hstspreload.org/ \n\
          hsts = '$ENABLE_HSTS$' \n\
 \n\
          # hide specifies a list of folders which cant be used to serve content. This field supports regex. \n\
          # Note that the certificate folder is automatically included in this, and folders starting with "." are always ignored. \n\
          hide = ["src", "target"] \n\
 \n\
          # smaller_default tells the server to generate smaller error pages, and prevents the server from generating file listings of folders that do not contain an index file. \n\
          # This can make your server slightly more secure, but it is not necessary for the vast majority of deployments. \n\
          #smaller_default = false \n\
 \n\
 \n\
          [[proxy]] # HTTP reverse proxy \n\
          # The host to be proxied. When using regex in this field, a URL without the protocol is provided as input instead. \n\
          location = "127.0.0.1" \n\
 \n\
          # The destination for proxied requests. When using HTTPS, a valid TLS certificate is required. \n\
          dest = '$APPLICATION$' \n\
 \n\
 \n\
          #[[proxy]] \n\
          #location = "r#localhost/proxy[0-9]" \n\
          #dest = "http://localhost:8081" \n\
 \n\
 \n\
          #[[redir]] # HTTP redirects \n\
          # The url (without the protocol) that this redirect affects. This field supports regex. \n\
          #location = "localhost/redir" \n\
 \n\
          # The destination that the client is redirected to. \n\
          #dest = "https://kittyhacker101.tk" \n\
 \n\
 \n\
          #[[redir]] \n\
          #location = "r#localhost/redir2.*" \n\
          #dest = "https://google.com" \n\
 \n\
 \n\
          #[[auth]] # HTTP basic authentication \n\
          # The url (without the protocol) that this affects. This field must be regex. \n\
          #location = "r#localhost/demopass.*" \n\
 \n\
          # The username and password required to get access to the resource, split by a ":" character. \n\
          # Note that brute forcing logins isnt very difficult to do, so make sure you use a complex username and password. \n\
          #login = "admin:passwd" \n\
          ' >conf.toml

# Cleanup
RUN apk del .build-deps

EXPOSE 80 443
CMD ./target/release/katwebx
