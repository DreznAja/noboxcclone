#!/bin/bash

# FCM Test Script
# Usage: ./test_fcm_notification.sh

FCM_TOKEN="fTEXkMFET72uWzGIcmU3YN:APA91bGVq8Ob7cj4xJ2iTPXujlBpfn2eEVveh1h0IA6FoTf4AtdQCbhGRNFWjid0a_VJfHKP5voMyRmsWBtNqWovkJ3fAJq3ugHphACYizGoiAQEIxrgUt8"
SERVER_KEY="YOUR_FIREBASE_SERVER_KEY"  # Get from Firebase Console -> Project Settings -> Cloud Messaging

curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=$SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"to\": \"$FCM_TOKEN\",
    \"notification\": {
      \"title\": \"Test Contact\",
      \"body\": \"Hello from terminal test!\"
    },
    \"data\": {
      \"roomId\": \"728385619223301\",
      \"roomName\": \"Test Contact\",
      \"message\": \"Full message text\"
    },
    \"priority\": \"high\"
  }"

echo ""
echo "Notification sent! Check your device."
