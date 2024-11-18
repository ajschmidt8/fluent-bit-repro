#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
GENERATED_DIR="${SCRIPT_DIR}/generated"
CA_CERT_NAME=ca.crt.pem

init() {
  echo "Initializing..."
  echo "\`sudo\` is required to remove the existing certificate files and to change the ownership of the generated certificate files for the Docker volumes."
  sudo rm -rf "${GENERATED_DIR}"
  mkdir "${GENERATED_DIR}"
  touch "${GENERATED_DIR}/index.txt"
  echo "1000" > "${GENERATED_DIR}/serial"
}

generate-ca-certs() {
  # Generate a CA certificate
  echo "Generating CA certificate..."
  openssl req -config "${SCRIPT_DIR}/openssl.cnf" \
   -new \
   -newkey rsa:4096 \
   -keyout "${GENERATED_DIR}/ca.key.pem" \
   -noenc \
   -x509 \
   -days 365 \
   -sha256 \
   -subj "/C=US/ST=CA/L=San Francisco/O=Test Org/OU=Test Unit/CN=test-org.com" \
   -extensions v3_ca \
   -out "${GENERATED_DIR}/${CA_CERT_NAME}"
}

generate-entity-cert() {
  local ENTITY_NAME=$1
  local OWNER_ID=$2
  local ENTITY_DIR="${GENERATED_DIR}/${ENTITY_NAME}"
  mkdir "${ENTITY_DIR}"

  # Generate a private key and signing request
  echo "Generating ${ENTITY_NAME} private key and certificate signing request..."
  openssl req -config "${SCRIPT_DIR}/openssl.cnf" \
    -newkey rsa:4096 \
    -keyout "${ENTITY_DIR}/key.pem" \
    -noenc \
    -new -sha256 \
    -addext "subjectAltName = DNS:${ENTITY_NAME}, DNS:localhost" \
    -subj "/C=US/ST=CA/L=San Francisco/O=Test Org/OU=Test Unit/CN=test-org.com" \
    -out "${ENTITY_DIR}/csr.pem"

  # Generate a certificate
  echo "Generating ${ENTITY_NAME} certificate..."
  openssl ca -config "${SCRIPT_DIR}/openssl.cnf" \
    -outdir "${ENTITY_DIR}/" \
    -cert "${GENERATED_DIR}/ca.crt.pem" \
    -keyfile "${GENERATED_DIR}/ca.key.pem" \
    -extensions mtls_cert -days 365 -notext -md sha256 \
    -batch \
    -in "${ENTITY_DIR}/csr.pem" \
    -out "${ENTITY_DIR}/cert.pem"

  # Copy the CA certificates to the entity directory
  cp "${GENERATED_DIR}/${CA_CERT_NAME}" "${GENERATED_DIR}/${ENTITY_NAME}/ca.pem"

  # Update the ownership
  sudo chown -R "${OWNER_ID}":"${OWNER_ID}" "${ENTITY_DIR}"
}

main() {
  cd "${SCRIPT_DIR}"
  init
  generate-ca-certs
  generate-entity-cert tempo 10001
  generate-entity-cert fb 0
}

main
