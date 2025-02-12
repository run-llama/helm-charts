#! /bin/bash

# Keycloak Docs: https://www.keycloak.org/docs/latest/server_admin/index.html#_configuring-realms

echo "Setting up Keycloak..."

if ! grep -qF '127.0.0.1 keycloak' /etc/hosts; then
    echo '127.0.0.1 keycloak' | sudo tee -a /etc/hosts > /dev/null
    echo "Adding keycloak to /etc/hosts"
else
    echo "Keycloak host entry already exists in /etc/hosts"
fi

if ! grep -qF '127.0.0.1 backend' /etc/hosts; then
    echo '127.0.0.1 backend' | sudo tee -a /etc/hosts > /dev/null
    echo "Adding backend to /etc/hosts"
else
    echo "Backend host entry already exists in /etc/hosts"
fi

KEYCLOAK_URL="http://localhost:8093"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="admin_password"
REALM_NAME="llamacloud"
CLIENT_ID="llamacloud"
CLIENT_SECRET="llamacloud_secret"
TEST_USER_EMAIL="local@llamacloud.com"
TEST_USER_USERNAME="local"
TEST_USER_FIRST_NAME="Local"
TEST_USER_LAST_NAME="User"
TEST_USER_PASSWORD="local_password"

get_admin_token() {
    curl -sS -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${ADMIN_USERNAME}" \
        -d "password=${ADMIN_PASSWORD}" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" | jq -r '.access_token'
}

ADMIN_TOKEN=$(get_admin_token)

echo "Creating realm..."
realm_response=$(curl -sS -X POST "${KEYCLOAK_URL}/admin/realms" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "realm": "'"${REALM_NAME}"'",
        "enabled": true,
        "accessTokenLifespan": 3600,
        "ssoSessionIdleTimeout": 7200,
        "sslRequired": "external"
    }')

if echo "${realm_response}" | jq -e 'has("errorMessage")' > /dev/null; then
    echo "Realm already exists, continuing..."
else
    echo "Created new realm"
fi


echo "Creating OIDC client..."
client_response=$(curl -sS -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "'"${CLIENT_ID}"'",
        "clientId": "'"${CLIENT_ID}"'",
        "secret": "'"${CLIENT_SECRET}"'",
        "protocol": "openid-connect",
        "publicClient": false,
        "redirectUris": ["http://localhost:3000/*"],
        "webOrigins": ["http://localhost:3000"],
        "standardFlowEnabled": true,
        "implicitFlowEnabled": false,
        "directAccessGrantsEnabled": true,
        "serviceAccountsEnabled": true
    }')

if echo "${client_response}" | jq -e 'has("errorMessage")' > /dev/null; then
    echo "Client already exists, continuing..."
else
    echo "Created new client"
fi

echo "Creating test user..."
user_response=$(curl -sS -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "username": "'"${TEST_USER_USERNAME}"'",
        "email": "'"${TEST_USER_EMAIL}"'",
        "firstName": "'"${TEST_USER_FIRST_NAME}"'",
        "lastName": "'"${TEST_USER_LAST_NAME}"'",
        "enabled": true,
        "credentials": [{
            "type": "password",
            "value": "'"${TEST_USER_PASSWORD}"'",
            "temporary": false
        }]
    }')

if echo "${user_response}" | jq -e 'has("errorMessage")' > /dev/null; then
    echo "User already exists, continuing..."
else
    echo "Created new user"
fi

echo "Successfully setup local Keycloak instance."
echo "To visit the Keycloak admin console, visit ${KEYCLOAK_URL} and use the credentials noted in the docker-compose.yaml file."
