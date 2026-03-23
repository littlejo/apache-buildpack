#!/bin/bash

export APACHE_WORKER_SIZE="${APACHE_WORKER_SIZE:="10"}"
export APACHE_THREADS_PER_CHILD="${APACHE_THREADS_PER_CHILD:="25"}"

# Setting Mellon key, cert and metadata files
if [[ -f "${HOME}/.apache-mods" && $(grep -ic "auth-mellon" "${HOME}/.apache-mods") -eq 1 ]] ; then
  export APACHE_DIR="${APACHE_DIR:-$HOME/vendor/apache2}"
  export MELLON_DIR="${MELLON_DIR:-$APACHE_DIR/mellon}"
  mkdir -p "${MELLON_DIR}"

  if [[ -z "${MELLON_SP_METADATA}" ]]; then
    echo "WARNING: MELLON_SP_METADATA is not set. Mellon may not work!"
  else
    echo "Exporting xml matadata file..."
    echo "${MELLON_SP_METADATA}" | base64 --decode >> "${MELLON_DIR}/mellon.xml"
    chmod 644 "${MELLON_DIR}/mellon.xml"
  fi

  if [[ -z "${MELLON_SP_CERT}" ]]; then
    echo "WARNING: MELLON_SP_CERT is not set. Mellon may not work!"
  else
    echo "Exporting certificate file..."
    echo "${MELLON_SP_CERT}" | base64 --decode >> "${MELLON_DIR}/mellon.cert"
    chmod 644 "${MELLON_DIR}/mellon.cert"
  fi

  if [[ -z "${MELLON_SP_KEY}" ]]; then
    echo "WARNING: MELLON_SP_KEY is not set. Mellon may not work!"
  else
    echo "Exporting key file..."
    echo "${MELLON_SP_KEY}" | base64 --decode >> "${MELLON_DIR}/mellon.key"
    chmod 600 "${MELLON_DIR}/mellon.key"
  fi

  if [[ -z "${MELLON_IDP_METADATA}" ]]; then
    echo "MELLON_IDP_METADATA is not set. Checking for MELLON_IDP_PASSPHRASE... "
    if [[ -z "${MELLON_IDP_PASSPHRASE}" ]]; then
      echo "Neither MELLON_IDP_METADATA nor MELLON_IDP_PASSPHRASE are set. Mellon may not work! "
    else
      echo "Importing IdP xml metadata file..."
      unzip -P $( echo "${MELLON_IDP_PASSPHRASE}" | base64 --decode ) -d "${MELLON_DIR}" "${HOME}/mellon_idp_metadata.zip"
      chmod 644 "${MELLON_DIR}/mellon_idp_metadata.xml"
    fi
  else
    echo "Exporting IdP xml metadata file..."
    echo "${MELLON_IDP_METADATA}" | base64 --decode >> "${MELLON_DIR}/mellon_idp_metadata.xml"
    chmod 644 "${MELLON_DIR}/mellon_idp_metadata.xml"
  fi
fi

# Compiling conf file
echo "compiling conf file..."
erb "${HOME}/vendor/apache2/conf/httpd.conf.erb" > "${HOME}/vendor/apache2/conf/httpd.conf"

# Setting MaxRequestWorkers value according to the container size. Formula: total_mem / apache_process_mem_used (roughly 12mb)
case "${CONTAINER_SIZE}" in
  "S" ) SERVER_LIMIT="$(( 256 / ${APACHE_WORKER_SIZE} ))"
  echo "ServerLimit " "${SERVER_LIMIT}" >> "${HOME}/vendor/apache2/conf/httpd.conf"
  echo "MaxRequestWorkers " $(( ${SERVER_LIMIT} * ${APACHE_THREADS_PER_CHILD} )) >> "${HOME}/vendor/apache2/conf/httpd.conf"
  ;;
  "M" ) SERVER_LIMIT="$(( 512 / ${APACHE_WORKER_SIZE} ))"
  echo "ServerLimit " "${SERVER_LIMIT}" >> "${HOME}/vendor/apache2/conf/httpd.conf"
  echo "MaxRequestWorkers " $(( ${SERVER_LIMIT} * ${APACHE_THREADS_PER_CHILD} )) >> "${HOME}/vendor/apache2/conf/httpd.conf"
  ;;
  "L" ) SERVER_LIMIT="$(( 1024 / ${APACHE_WORKER_SIZE} ))"
  echo "ServerLimit " "${SERVER_LIMIT}" >> "${HOME}/vendor/apache2/conf/httpd.conf"
  echo "MaxRequestWorkers " $(( ${SERVER_LIMIT} * ${APACHE_THREADS_PER_CHILD} )) >> "${HOME}/vendor/apache2/conf/httpd.conf"
  ;;
  "XL" ) SERVER_LIMIT="$(( 2048 / ${APACHE_WORKER_SIZE} ))"
  echo "ServerLimit " "${SERVER_LIMIT}" >> "${HOME}/vendor/apache2/conf/httpd.conf"
  echo "MaxRequestWorkers " $(( ${SERVER_LIMIT} * ${APACHE_THREADS_PER_CHILD} )) >> "${HOME}/vendor/apache2/conf/httpd.conf"
  ;;
  "2XL" ) SERVER_LIMIT="$(( 4096 / ${APACHE_WORKER_SIZE} ))"
  echo "ServerLimit " "${SERVER_LIMIT}" >> "${HOME}/vendor/apache2/conf/httpd.conf"
  echo "MaxRequestWorkers " $(( ${SERVER_LIMIT} * ${APACHE_THREADS_PER_CHILD} )) >> "${HOME}/vendor/apache2/conf/httpd.conf"
  ;;
  "3XL" ) SERVER_LIMIT="$(( 8192 / ${APACHE_WORKER_SIZE} ))"
  echo "ServerLimit " "${SERVER_LIMIT}" >> "${HOME}/vendor/apache2/conf/httpd.conf"
  echo "MaxRequestWorkers " $(( ${SERVER_LIMIT} * ${APACHE_THREADS_PER_CHILD} )) >> "${HOME}/vendor/apache2/conf/httpd.conf"
  ;;
  "4XL" ) SERVER_LIMIT="$(( 16384 / ${APACHE_WORKER_SIZE} ))"
  echo "ServerLimit " "${SERVER_LIMIT}" >> "${HOME}/vendor/apache2/conf/httpd.conf"
  echo "MaxRequestWorkers " $(( ${SERVER_LIMIT} * ${APACHE_THREADS_PER_CHILD} )) >> "${HOME}/vendor/apache2/conf/httpd.conf"
  ;;
esac


if [ -f "${HOME}/apache.conf.erb" ] ; then
  erb "${HOME}/apache.conf.erb" > "${HOME}/vendor/apache2/conf/site.conf"
  
  # Testing if /app or /app/vendor are set in the DocumentRoot (insecure)
  if [[ -n $(grep -i 'DocumentRoot' "${HOME}/vendor/apache2/conf/site.conf" | grep -E '( '"${HOME}"$'| '"${HOME}"'/vendor)') ]]; then
	  echo "ERROR: DocumentRoot should never be set to /app! Exiting..."
    exit 1
  fi

  echo "Include ${HOME}/vendor/apache2/conf/site.conf" >> "${HOME}/vendor/apache2/conf/httpd.conf"
fi

# Starting
echo "Starting Apache..."
exec "${HOME}/.apt/usr/sbin/apache2" -f "${HOME}/vendor/apache2/conf/httpd.conf" -DFOREGROUND
