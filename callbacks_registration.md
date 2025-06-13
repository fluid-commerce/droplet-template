## Callback::Registration

```
curl -i \
  -X POST http://lvh.me:3000/api/callback/registrations \
  -H 'Authorization: Bearer <DROPLET_INSTALLATION_AUTHENTICATION_TOKEN>' \
  -H 'Content-Type: application/json' \
  -d '{
    "callback_registration": {
      "definition_name": "redirect_cart_payment",
      "url": "http://lvh.me:3300/get_redirect_url",
      "timeout_in_seconds": 20,
      "active": true
    }
  }'
```
