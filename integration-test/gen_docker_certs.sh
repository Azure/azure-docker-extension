#!/bin/bash
set -eou pipefail

# Script to generate Docker certificates and keys for testing. These are
# temporary certificates, and are good for one day only.
#
# See https://docs.docker.com/engine/security/https/ for deails.

readonly DAYS=1
readonly KEY_SIZE=2048
readonly OUT=./dockercerts
readonly EXT_OUT=./extensionconfig

mkdir -p $OUT

# 1. CA private and public keys
openssl genrsa -out $OUT/ca-key.pem $KEY_SIZE
openssl req -new -x509 -days $DAYS -key $OUT/ca-key.pem -sha256 -out $OUT/ca.pem -subj "/C=US/ST=Washington/L=Redmond/O=azure-docker-extension/CN=test-ca"

# 2. Server
#  a. server key
#  b. certificate signing request
#  c. sign the request with our CA
openssl genrsa -out $OUT/server-key.pem $KEY_SIZE
openssl req -sha256 -new -key $OUT/server-key.pem -out $OUT/server.csr -subj "/CN=test-server"

echo subjectAltName = IP:127.0.0.1 > $OUT/server-extfile.cnf
openssl x509 -req -days $DAYS -sha256 -in $OUT/server.csr -CA $OUT/ca.pem -CAkey $OUT/ca-key.pem -CAcreateserial -out $OUT/server-cert.pem -extfile $OUT/server-extfile.cnf

# 3. Client key, and certificate signing request
#  a. client key
#  b. certificate signing request
#  c. sign the request with our CA
openssl genrsa -out $OUT/key.pem $KEY_SIZE
openssl req -new -key $OUT/key.pem -out $OUT/client.csr -subj "/CN=test-client"

echo extendedKeyUsage = clientAuth > $OUT/client-extfile.cnf
openssl x509 -req -days $DAYS -sha256 -in $OUT/client.csr -CA $OUT/ca.pem -CAkey $OUT/ca-key.pem -CAcreateserial -out $OUT/cert.pem -extfile $OUT/client-extfile.cnf

cat <<EOF > $EXT_OUT/protected.json
{
    "environment": {
        "SECRET_KEY": "SECRET_VALUE"
    },
    "certs": {
        "ca":   "$(base64 -w0 < $OUT/ca.pem)",
        "cert": "$(base64 -w0 < $OUT/server-cert.pem)",
        "key":  "$(base64 -w0 < $OUT/server-key.pem)"
    }
}
EOF

# 4. Cleanup
#  a. .cnf are no longer needed
#  b. server key, request, and configuration are no longer needed
#  c. client request, and configuration are no longer needed

rm \
    $OUT/ca-key.pem \
    $OUT/server-cert.pem \
    $OUT/server-key.pem \
    $OUT/server.csr \
    $OUT/server-extfile.cnf \
    $OUT/client.csr \
    $OUT/client-extfile.cnf \

