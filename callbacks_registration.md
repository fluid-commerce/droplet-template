## Callback::Definition

{
  "name": "get_newulife_redirect",
  "description": "Checks the user with external_id in NewULife system, if not found, creates a new consumer, generates a redirectURL, then processes merchant checkout."
  "example_response": "",
  "request_schema": "",
  "response_schema": ""
}


## Callback::Registration

```
curl -i \
  -X POST https://fluid.app/api/callback/registrations \
  -H 'Authorization: Bearer <DROPLET_INSTALLATION_AUTHENTICATION_TOKEN>' \
  -H 'Content-Type: application/json' \
  -d '{
    "callback_registration": {
      "definition_name": "get_newulife_redirect",
      "url": "http://lvh.me:3300/get_redirect_url",
      "timeout_in_seconds": 60,
      "active": true
    }
  }'
```


## Callback Definition YAML for Fluid
```
name: get_newulife_redirect
description: Get the redirect_url for a Payment Droplet. The Cart object is sent in the payload and the redirect_url is returned in the response.
request_schema:
  type: object
  required:
    - cart
    - external_id
  properties:
    cart:
      type: object
      description: Cart object
    external_id:
      type: string
      description: External ID associated with the NewULife
response_schema:
  type: object
  required:
    - redirect_url
  properties:
    redirect_url:
      type: string
      description: The redirect URL to visit for finish the payment processing at NewULife
example_response:
  redirect_url: https://some-new-ulife-redirect.app/redirect
```  

