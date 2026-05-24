const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

exports.changePasswordByEmail = onCall(async (request) => {
  const email = request.data.email;
  const newPassword = request.data.newPassword;

  if (!email || !newPassword) {
    throw new HttpsError(
      "invalid-argument",
      "Email and password are required."
    );
  }

  const userRecord = await admin.auth().getUserByEmail(email);

  await admin.auth().updateUser(userRecord.uid, {
    password: newPassword,
  });

  return {
    success: true,
  };
});