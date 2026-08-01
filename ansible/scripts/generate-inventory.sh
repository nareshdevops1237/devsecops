#!/bin/bash

APP_IP=$(terraform output -raw app_private_ip)
DB_IP=$(terraform output -raw db_private_ip)

cat > ansible/inventory.ini <<EOF
[app]
$APP_IP ansible_user=azureuser

[db]
$DB_IP ansible_user=azureuser
EOF