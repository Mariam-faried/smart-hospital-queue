# Cloud Function: Server-Side Paymob Confirmation

This folder adds confirmPaymobPayment, an HTTPS Cloud Function that verifies payment status with Paymob before writing paymentStatus=paid to Firestore.

## Required Secret
Set your Paymob API key as an environment variable before deploy:
firebase functions:secrets:set PAYMOB_API_KEY

## Deploy
cd functions
npm install
cd ..
firebase deploy --only functions:confirmPaymobPayment

## Client Call
Flutter calls PaymentService.confirmPaymentServerSide(...).
The function requires Authorization: Bearer <Firebase ID token>.
