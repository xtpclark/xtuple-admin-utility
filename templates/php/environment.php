<?php

$configuration        = [
  'environment'       => '{ENVIRONMENT}',
  'xtuple_rest_api'   => [
    'application'     => '{ERP_APPLICATION}',
    'host'            => '{ERP_HOST}',
    'database'        => '{ERP_DATABASE_NAME}',
    'iss'             => '{ERP_ISS}',
    'key'             => '{ERP_KEY_FILE_PATH}',
    'debug'           => {ERP_DEBUG},
  ],
  'authorize_net'     => [
    'login'           => '{COMMERCE_AUTHNET_AIM_LOGIN}',
    'tran_key'        => '{COMMERCE_AUTHNET_AIM_TRANSACTION_KEY}',
  ],
  'ups'               => [
    'accountId'       => '{UPS_ACCOUNT_ID}',
    'accessKey'       => '{UPS_ACCESS_KEY}',
    'userId'          => '{UPS_USER_ID}',
    'password'        => '{UPS_PASSWORD}',
    'pickupSchedule'  => '{UPS_PICKUP_SCHEDULE}',
  ],
  'fedex'             => [
    'beta'            => {FEDEX_BETA},
    'key'             => '{FEDEX_KEY}',
    'password'        => '{FEDEX_PASSWORD}',
    'accountNumber'   => '{FEDEX_ACCOUNT_NUMBER}',
    'meterNumber'     => '{FEDEX_METER_NUMBER}',
  ],
  'xdruple_shipping'  => [],
];
