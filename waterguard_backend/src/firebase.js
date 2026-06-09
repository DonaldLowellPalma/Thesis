const admin = require("firebase-admin");

function getFirebaseConfig() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY
    ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n")
    : undefined;

  const missing = [];
  if (!projectId) missing.push("FIREBASE_PROJECT_ID");
  if (!clientEmail) missing.push("FIREBASE_CLIENT_EMAIL");
  if (!privateKey) missing.push("FIREBASE_PRIVATE_KEY");

  if (missing.length) {
    throw new Error(
      `Missing Firebase environment variables: ${missing.join(", ")}. ` +
        "Add them to your .env file before starting the backend.",
    );
  }

  return {
    credential: admin.credential.cert({
      projectId,
      clientEmail,
      privateKey,
    }),
    projectId,
  };
}

function getFirebaseApp() {
  if (!admin.apps.length) {
    admin.initializeApp(getFirebaseConfig());
  }

  return admin.app();
}

function getFirestore() {
  return getFirebaseApp().firestore();
}

module.exports = {
  getFirestore,
};
